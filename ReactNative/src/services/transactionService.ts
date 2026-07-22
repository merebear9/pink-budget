import { Account, Transaction, TransactionClassification, BudgetCategory } from '../models/types';
import { PlaidTransaction, fetchTransactions } from './plaidService';
import { markAccountSynced, removeTransactionsByPlaidId, upsertTransactions } from '../database';

/**
 * ANTI-DOUBLE-COUNT CLASSIFICATION
 * 
 * The #1 problem with tracking spending across multiple credit cards:
 * 
 *   You buy $50 at Target on Chase card     → SPENDING (counts toward budget)
 *   You pay Chase $500 from checking        → TRANSFER (excluded from budget)
 *   You transfer $583 to Vanguard Roth IRA  → CONTRIBUTION (tracked separately)
 *   Your paycheck hits checking             → INCOME (cash flow only)
 * 
 * Without this, the $50 Target purchase gets counted TWICE:
 * once as the CC charge, once as part of the $500 CC payment.
 */
export function classifyTransaction(
  plaidTx: PlaidTransaction,
  account: Account
): TransactionClassification {
  const name = (plaidTx.merchant_name ?? plaidTx.name).toLowerCase();
  const primary = plaidTx.personal_finance_category?.primary ?? '';
  const detailed = plaidTx.personal_finance_category?.detailed ?? '';

  // ── INCOME ──
  if (plaidTx.amount < 0 && account.accountType === 'depository') {
    if (isInternalTransfer(primary, detailed, name)) return 'transfer';
    return 'income';
  }

  // ── CREDIT CARD PAYMENTS ──
  if (isCreditCardPayment(primary, detailed, name)) return 'transfer';

  // ── INTERNAL TRANSFERS ──
  if (isInternalTransfer(primary, detailed, name)) {
    if (isInvestmentTransfer(name, account)) return 'contribution';
    return 'transfer';
  }

  // ── RETIREMENT/INVESTMENT ACCOUNTS ──
  if (account.isRetirementAccount) return 'contribution';
  if (isInvestmentTransfer(name, account)) return 'contribution';

  // ── CC PAYMENT RECEIVED (on the CC side) ──
  if (account.accountType === 'credit' && plaidTx.amount < 0) {
    if (isPaymentReceived(name)) return 'transfer';
  }

  // ── SPENDING ──
  if (plaidTx.amount > 0) return 'spending';

  return 'excluded';
}

// ── Detection Helpers ──

const CC_PAYMENT_KEYWORDS = [
  'payment', 'autopay', 'bill pay', 'credit card payment',
  'chase', 'amex', 'discover', 'citi', 'capital one',
  'barclays', 'wells fargo card', 'bank of america card',
];

function isCreditCardPayment(primary: string, detailed: string, name: string): boolean {
  if (primary === 'LOAN_PAYMENTS' || detailed.includes('CREDIT_CARD')) return true;
  const isPayment = name.includes('payment') || name.includes('autopay') || name.includes('bill pay');
  const isToCC = CC_PAYMENT_KEYWORDS.some(kw => name.includes(kw));
  return isPayment && isToCC;
}

function isInternalTransfer(primary: string, detailed: string, name: string): boolean {
  if (['TRANSFER_IN', 'TRANSFER_OUT'].includes(primary)) return true;
  const hasTransferWord = name.includes('transfer') || name.includes('xfer');
  return hasTransferWord && (primary.includes('TRANSFER') || name.includes('transfer'));
}

const INVESTMENT_KEYWORDS = [
  'vanguard', 'fidelity', 'schwab', 'tsp', 'thrift savings',
  '401k', '401(k)', 'roth', 'ira', 'brokerage',
  'etrade', 'e*trade', 'robinhood', 'wealthfront', 'betterment',
  'contribution', 'retirement', 'investment',
];

function isInvestmentTransfer(name: string, account: Account): boolean {
  if (account.accountType === 'retirement' || account.accountType === 'investment') return true;
  return INVESTMENT_KEYWORDS.some(kw => name.includes(kw));
}

function isPaymentReceived(name: string): boolean {
  const keywords = ['payment', 'thank you', 'autopay', 'online payment', 'mobile payment'];
  return keywords.some(kw => name.includes(kw));
}

// ── Category Mapping ──

export function mapToCategory(
  plaidTx: PlaidTransaction,
  classification: TransactionClassification,
  categories: BudgetCategory[]
): string {
  // Non-spending gets a fixed label
  if (classification === 'transfer') return 'Transfer';
  if (classification === 'contribution') return 'Investment';
  if (classification === 'income') return 'Income';
  if (classification === 'excluded') return 'Other';

  // Try Plaid category
  const plaidDetailed = plaidTx.personal_finance_category?.detailed;
  if (plaidDetailed) {
    const match = categories.find(c => c.plaidCategories.includes(plaidDetailed));
    if (match) return match.name;
  }

  // Keyword matching
  const searchText = (plaidTx.merchant_name ?? plaidTx.name).toLowerCase();
  for (const cat of categories) {
    if (cat.matchKeywords.some(kw => searchText.includes(kw.toLowerCase()))) {
      return cat.name;
    }
  }

  return 'Misc';
}

// ── Build Transaction Object ──

export function buildTransaction(
  plaidTx: PlaidTransaction,
  account: Account,
  categories: BudgetCategory[]
): Transaction {
  const classification = classifyTransaction(plaidTx, account);
  const categoryName = mapToCategory(plaidTx, classification, categories);

  return {
    id: plaidTx.transaction_id,
    plaidTransactionId: plaidTx.transaction_id,
    date: plaidTx.date,
    amount: plaidTx.amount,
    merchantName: plaidTx.merchant_name,
    name: plaidTx.name,
    categoryName,
    plaidCategory: plaidTx.personal_finance_category?.detailed ?? null,
    isPending: plaidTx.pending,
    classification,
    isManuallyClassified: false,
    notes: null,
    accountId: account.id,
  };
}

// ── Sync (fetch from Plaid, classify, persist) ──
//
// Mirrors the anti-double-count sync loop in the iOS TransactionService.

export async function syncAccountTransactions(
  account: Account,
  categories: BudgetCategory[]
): Promise<void> {
  let cursor: string | undefined;
  let hasMore = true;

  while (hasMore) {
    const response = await fetchTransactions(account.plaidAccessToken, cursor);

    const newTransactions = response.added.map(plaidTx =>
      buildTransaction(plaidTx, account, categories)
    );
    await upsertTransactions(newTransactions);

    if (response.removed.length > 0) {
      await removeTransactionsByPlaidId(response.removed.map(r => r.transaction_id));
    }

    cursor = response.next_cursor;
    hasMore = response.has_more;
  }

  await markAccountSynced(account.id);
}
