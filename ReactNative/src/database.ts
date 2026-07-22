import * as SQLite from 'expo-sqlite';
import {
  Account,
  AccountType,
  BudgetCategory,
  Contribution,
  ContributionLabel,
  DEFAULT_CATEGORIES,
  RecurringContribution,
  Transaction,
  TransactionClassification,
} from './models/types';

let dbPromise: Promise<SQLite.SQLiteDatabase> | null = null;

export function generateId(): string {
  return `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 10)}`;
}

function getDb(): Promise<SQLite.SQLiteDatabase> {
  if (!dbPromise) {
    dbPromise = openAndMigrate();
  }
  return dbPromise;
}

async function openAndMigrate(): Promise<SQLite.SQLiteDatabase> {
  const db = await SQLite.openDatabaseAsync('pinkbudget.db');

  await db.execAsync(`
    PRAGMA journal_mode = WAL;

    CREATE TABLE IF NOT EXISTS accounts (
      id TEXT PRIMARY KEY NOT NULL,
      plaidAccountId TEXT NOT NULL,
      plaidAccessToken TEXT NOT NULL,
      institutionName TEXT NOT NULL,
      accountName TEXT NOT NULL,
      accountType TEXT NOT NULL,
      currentBalance REAL NOT NULL,
      lastSynced TEXT,
      isActive INTEGER NOT NULL,
      isRetirementAccount INTEGER NOT NULL,
      contributionLabel TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS transactions (
      id TEXT PRIMARY KEY NOT NULL,
      plaidTransactionId TEXT,
      date TEXT NOT NULL,
      amount REAL NOT NULL,
      merchantName TEXT,
      name TEXT NOT NULL,
      categoryName TEXT NOT NULL,
      plaidCategory TEXT,
      isPending INTEGER NOT NULL,
      classification TEXT NOT NULL,
      isManuallyClassified INTEGER NOT NULL,
      notes TEXT,
      accountId TEXT
    );
    CREATE UNIQUE INDEX IF NOT EXISTS idx_transactions_plaid_id
      ON transactions (plaidTransactionId) WHERE plaidTransactionId IS NOT NULL;

    CREATE TABLE IF NOT EXISTS budget_categories (
      id TEXT PRIMARY KEY NOT NULL,
      name TEXT NOT NULL,
      icon TEXT NOT NULL,
      monthlyLimit REAL NOT NULL,
      colorHex TEXT NOT NULL,
      sortOrder INTEGER NOT NULL,
      isActive INTEGER NOT NULL,
      matchKeywords TEXT NOT NULL,
      plaidCategories TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS contributions (
      id TEXT PRIMARY KEY NOT NULL,
      date TEXT NOT NULL,
      amount REAL NOT NULL,
      label TEXT NOT NULL,
      source TEXT NOT NULL,
      notes TEXT,
      linkedTransactionId TEXT,
      recurringContributionId TEXT
    );

    CREATE TABLE IF NOT EXISTS recurring_contributions (
      id TEXT PRIMARY KEY NOT NULL,
      label TEXT NOT NULL,
      amount REAL NOT NULL,
      note TEXT,
      isActive INTEGER NOT NULL
    );

    CREATE TABLE IF NOT EXISTS settings (
      key TEXT PRIMARY KEY NOT NULL,
      value TEXT NOT NULL
    );
  `);

  const categoryCount = await db.getFirstAsync<{ count: number }>(
    'SELECT COUNT(*) as count FROM budget_categories'
  );
  if (!categoryCount || categoryCount.count === 0) {
    await seedDefaultCategories(db);
  }

  return db;
}

async function seedDefaultCategories(db: SQLite.SQLiteDatabase): Promise<void> {
  await db.withTransactionAsync(async () => {
    for (const cat of DEFAULT_CATEGORIES) {
      await db.runAsync(
        `INSERT INTO budget_categories
          (id, name, icon, monthlyLimit, colorHex, sortOrder, isActive, matchKeywords, plaidCategories)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          generateId(),
          cat.name,
          cat.icon,
          cat.monthlyLimit,
          cat.colorHex,
          cat.sortOrder,
          cat.isActive ? 1 : 0,
          JSON.stringify(cat.matchKeywords),
          JSON.stringify(cat.plaidCategories),
        ]
      );
    }
  });
}

// ── Row <-> Model mapping ──

interface AccountRow {
  id: string;
  plaidAccountId: string;
  plaidAccessToken: string;
  institutionName: string;
  accountName: string;
  accountType: AccountType;
  currentBalance: number;
  lastSynced: string | null;
  isActive: number;
  isRetirementAccount: number;
  contributionLabel: ContributionLabel;
}

function accountFromRow(row: AccountRow): Account {
  return {
    ...row,
    isActive: row.isActive === 1,
    isRetirementAccount: row.isRetirementAccount === 1,
  };
}

interface TransactionRow {
  id: string;
  plaidTransactionId: string | null;
  date: string;
  amount: number;
  merchantName: string | null;
  name: string;
  categoryName: string;
  plaidCategory: string | null;
  isPending: number;
  classification: TransactionClassification;
  isManuallyClassified: number;
  notes: string | null;
  accountId: string | null;
}

function transactionFromRow(row: TransactionRow): Transaction {
  return {
    ...row,
    isPending: row.isPending === 1,
    isManuallyClassified: row.isManuallyClassified === 1,
  };
}

interface BudgetCategoryRow {
  id: string;
  name: string;
  icon: string;
  monthlyLimit: number;
  colorHex: string;
  sortOrder: number;
  isActive: number;
  matchKeywords: string;
  plaidCategories: string;
}

function categoryFromRow(row: BudgetCategoryRow): BudgetCategory {
  return {
    ...row,
    isActive: row.isActive === 1,
    matchKeywords: JSON.parse(row.matchKeywords),
    plaidCategories: JSON.parse(row.plaidCategories),
  };
}

// ── Accounts ──

export async function insertAccount(account: Omit<Account, 'id'>): Promise<Account> {
  const db = await getDb();
  const id = generateId();
  await db.runAsync(
    `INSERT INTO accounts
      (id, plaidAccountId, plaidAccessToken, institutionName, accountName, accountType,
       currentBalance, lastSynced, isActive, isRetirementAccount, contributionLabel)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      id,
      account.plaidAccountId,
      account.plaidAccessToken,
      account.institutionName,
      account.accountName,
      account.accountType,
      account.currentBalance,
      account.lastSynced,
      account.isActive ? 1 : 0,
      account.isRetirementAccount ? 1 : 0,
      account.contributionLabel,
    ]
  );
  return { ...account, id };
}

export async function getAccounts(): Promise<Account[]> {
  const db = await getDb();
  const rows = await db.getAllAsync<AccountRow>('SELECT * FROM accounts ORDER BY institutionName');
  return rows.map(accountFromRow);
}

export async function markAccountSynced(accountId: string): Promise<void> {
  const db = await getDb();
  await db.runAsync('UPDATE accounts SET lastSynced = ? WHERE id = ?', [
    new Date().toISOString(),
    accountId,
  ]);
}

export async function setAccountRetirementInfo(
  accountId: string,
  isRetirementAccount: boolean,
  contributionLabel: ContributionLabel
): Promise<void> {
  const db = await getDb();
  await db.runAsync(
    'UPDATE accounts SET isRetirementAccount = ?, contributionLabel = ? WHERE id = ?',
    [isRetirementAccount ? 1 : 0, contributionLabel, accountId]
  );
}

// ── Transactions ──

export async function upsertTransactions(transactions: Transaction[]): Promise<void> {
  if (transactions.length === 0) return;
  const db = await getDb();
  await db.withTransactionAsync(async () => {
    for (const tx of transactions) {
      const existing = tx.plaidTransactionId
        ? await db.getFirstAsync<{ id: string }>(
            'SELECT id FROM transactions WHERE plaidTransactionId = ?',
            [tx.plaidTransactionId]
          )
        : null;

      if (existing) continue; // never overwrite a manual reclassification

      await db.runAsync(
        `INSERT INTO transactions
          (id, plaidTransactionId, date, amount, merchantName, name, categoryName,
           plaidCategory, isPending, classification, isManuallyClassified, notes, accountId)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          tx.id,
          tx.plaidTransactionId,
          tx.date,
          tx.amount,
          tx.merchantName,
          tx.name,
          tx.categoryName,
          tx.plaidCategory,
          tx.isPending ? 1 : 0,
          tx.classification,
          tx.isManuallyClassified ? 1 : 0,
          tx.notes,
          tx.accountId,
        ]
      );
    }
  });
}

export async function removeTransactionsByPlaidId(plaidTransactionIds: string[]): Promise<void> {
  if (plaidTransactionIds.length === 0) return;
  const db = await getDb();
  await db.withTransactionAsync(async () => {
    for (const id of plaidTransactionIds) {
      await db.runAsync('DELETE FROM transactions WHERE plaidTransactionId = ?', [id]);
    }
  });
}

export async function getTransactions(): Promise<Transaction[]> {
  const db = await getDb();
  const rows = await db.getAllAsync<TransactionRow>(
    'SELECT * FROM transactions ORDER BY date DESC'
  );
  return rows.map(transactionFromRow);
}

export async function reclassifyTransaction(
  transactionId: string,
  classification: TransactionClassification,
  categoryName: string
): Promise<void> {
  const db = await getDb();
  await db.runAsync(
    'UPDATE transactions SET classification = ?, categoryName = ?, isManuallyClassified = 1 WHERE id = ?',
    [classification, categoryName, transactionId]
  );
}

// ── Budget Categories ──

export async function getBudgetCategories(): Promise<BudgetCategory[]> {
  const db = await getDb();
  const rows = await db.getAllAsync<BudgetCategoryRow>(
    'SELECT * FROM budget_categories ORDER BY sortOrder'
  );
  return rows.map(categoryFromRow);
}

// ── Contributions ──

export async function insertContribution(
  contribution: Omit<Contribution, 'id'>
): Promise<Contribution> {
  const db = await getDb();
  const id = generateId();
  await db.runAsync(
    `INSERT INTO contributions
      (id, date, amount, label, source, notes, linkedTransactionId, recurringContributionId)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      id,
      contribution.date,
      contribution.amount,
      contribution.label,
      contribution.source,
      contribution.notes,
      contribution.linkedTransactionId,
      contribution.recurringContributionId,
    ]
  );
  return { ...contribution, id };
}

export async function getContributions(): Promise<Contribution[]> {
  const db = await getDb();
  const rows = await db.getAllAsync<Contribution>('SELECT * FROM contributions ORDER BY date DESC');
  return rows;
}

// ── Recurring Contributions ──

interface RecurringContributionRow {
  id: string;
  label: ContributionLabel;
  amount: number;
  note: string | null;
  isActive: number;
}

function recurringFromRow(row: RecurringContributionRow): RecurringContribution {
  return { ...row, isActive: row.isActive === 1 };
}

export async function insertRecurringContribution(
  recurring: Omit<RecurringContribution, 'id'>
): Promise<RecurringContribution> {
  const db = await getDb();
  const id = generateId();
  await db.runAsync(
    'INSERT INTO recurring_contributions (id, label, amount, note, isActive) VALUES (?, ?, ?, ?, ?)',
    [id, recurring.label, recurring.amount, recurring.note, recurring.isActive ? 1 : 0]
  );
  return { ...recurring, id };
}

export async function getRecurringContributions(): Promise<RecurringContribution[]> {
  const db = await getDb();
  const rows = await db.getAllAsync<RecurringContributionRow>(
    'SELECT * FROM recurring_contributions ORDER BY label'
  );
  return rows.map(recurringFromRow);
}

export async function setRecurringContributionActive(id: string, isActive: boolean): Promise<void> {
  const db = await getDb();
  await db.runAsync('UPDATE recurring_contributions SET isActive = ? WHERE id = ?', [
    isActive ? 1 : 0,
    id,
  ]);
}

export async function deleteRecurringContribution(id: string): Promise<void> {
  const db = await getDb();
  await db.runAsync('DELETE FROM recurring_contributions WHERE id = ?', [id]);
}

export async function hasContributionForRecurringInMonth(
  recurringContributionId: string,
  year: number,
  month: number // 1-12
): Promise<boolean> {
  const db = await getDb();
  const monthStr = String(month).padStart(2, '0');
  const row = await db.getFirstAsync<{ id: string }>(
    `SELECT id FROM contributions
     WHERE recurringContributionId = ?
       AND strftime('%Y-%m', date) = ?`,
    [recurringContributionId, `${year}-${monthStr}`]
  );
  return row !== null;
}

// ── Settings (simple key/value store) ──

export async function getSetting(key: string): Promise<string | null> {
  const db = await getDb();
  const row = await db.getFirstAsync<{ value: string }>(
    'SELECT value FROM settings WHERE key = ?',
    [key]
  );
  return row?.value ?? null;
}

export async function setSetting(key: string, value: string): Promise<void> {
  const db = await getDb();
  await db.runAsync(
    'INSERT INTO settings (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value',
    [key, value]
  );
}
