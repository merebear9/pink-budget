import Foundation
import SwiftData

/// Handles syncing Plaid transactions into SwiftData,
/// auto-categorizing, detecting contributions, and
/// preventing double-counting across credit cards and transfers.
///
/// CLASSIFICATION RULES:
/// ─────────────────────
/// 1. SPENDING: Individual purchases on credit/debit cards.
///    These are the ONLY transactions that count toward your budget.
///
/// 2. TRANSFER: CC payments, account-to-account moves.
///    EXCLUDED from budget to prevent double-counting.
///    Example: You pay $500 from checking to Chase CC.
///    The $500 is NOT spending -- the individual CC charges are.
///
/// 3. CONTRIBUTION: Money going to investment/retirement accounts.
///    Tracked in the Contributions tab, NOT as spending.
///    Example: $583/mo to Vanguard Roth IRA.
///
/// 4. INCOME: Paychecks, deposits.
///    Tracked for cash flow, not counted as spending.
///
/// HOW DOUBLE-COUNTING IS PREVENTED:
/// ──────────────────────────────────
/// - CC payments from checking → classified as TRANSFER → excluded
/// - The actual CC purchases (Target $50, Chipotle $12) → SPENDING → budgeted
/// - Vanguard/TSP/401k transfers → CONTRIBUTION → tracked separately
/// - Internal transfers (savings ↔ checking) → TRANSFER → excluded

class TransactionService {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Transaction Classification
    
    enum TransactionClass {
        case spending       // Counts toward budget
        case transfer       // Excluded (CC payments, internal moves)
        case contribution   // Retirement/investment deposits
        case income         // Paychecks, refunds
        case excluded       // Fees, interest, other non-budget items
    }
    
    /// Classify a Plaid transaction to prevent double-counting
    func classify(_ plaidTx: PlaidTransaction, account: Account) -> TransactionClass {
        let name = (plaidTx.merchantName ?? plaidTx.name).lowercased()
        let plaidPrimary = plaidTx.personalFinanceCategory?.primary ?? ""
        let plaidDetailed = plaidTx.personalFinanceCategory?.detailed ?? ""
        
        // ── INCOME ──
        // Negative amounts on depository accounts = money coming in
        if plaidTx.amount < 0 && account.accountType == .depository {
            // But not if it's a transfer from another account
            if isInternalTransfer(plaidPrimary, plaidDetailed, name) {
                return .transfer
            }
            // Check if it's a refund on a debit card
            if isRefund(plaidPrimary, name) {
                return .income  // or .excluded, depending on preference
            }
            return .income
        }
        
        // ── CREDIT CARD PAYMENTS ──
        // Payment FROM checking/savings TO a credit card = transfer
        if isCreditCardPayment(plaidPrimary, plaidDetailed, name) {
            return .transfer
        }
        
        // ── INTERNAL TRANSFERS ──
        // Moving money between your own accounts
        if isInternalTransfer(plaidPrimary, plaidDetailed, name) {
            // Special case: transfers TO investment/retirement accounts = contributions
            if isInvestmentTransfer(name, account) {
                return .contribution
            }
            return .transfer
        }
        
        // ── CONTRIBUTIONS ──
        // Money going to retirement/investment accounts
        if account.isRetirementAccount {
            if plaidTx.amount > 0 {
                // Debit from checking TO retirement = contribution
                return .contribution
            } else {
                // Credit on the retirement account side
                return .contribution
            }
        }
        if isInvestmentTransfer(name, account) {
            return .contribution
        }
        
        // ── CREDIT CARD: PAYMENT RECEIVED ──
        // On the CC side, a payment shows as negative (credit)
        if account.accountType == .credit && plaidTx.amount < 0 {
            if isPaymentReceived(name) {
                return .transfer  // Don't count CC payment as income
            }
        }
        
        // ── SPENDING ──
        // Everything else that's a positive amount (debit) = real spending
        if plaidTx.amount > 0 {
            return .spending
        }
        
        return .excluded
    }
    
    // MARK: - Detection Helpers
    
    private func isCreditCardPayment(_ primary: String, _ detailed: String, _ name: String) -> Bool {
        let ccPaymentKeywords = [
            "payment", "autopay", "bill pay", "credit card payment",
            "chase", "amex", "discover", "citi", "capital one",
            "barclays", "wells fargo card", "bank of america card"
        ]
        
        // Plaid explicitly categorizes these
        if primary == "LOAN_PAYMENTS" || detailed.contains("CREDIT_CARD") {
            return true
        }
        
        // Keyword fallback
        let isPayment = name.contains("payment") || name.contains("autopay") || name.contains("bill pay")
        let isToCC = ccPaymentKeywords.contains { name.contains($0) }
        
        return isPayment && isToCC
    }
    
    private func isInternalTransfer(_ primary: String, _ detailed: String, _ name: String) -> Bool {
        // Plaid categories for transfers
        let transferCategories = ["TRANSFER_IN", "TRANSFER_OUT"]
        if transferCategories.contains(primary) {
            return true
        }
        
        let transferKeywords = [
            "transfer", "xfer", "ach", "wire",
            "zelle", "venmo", "paypal",  // These may or may not be transfers
            "online banking transfer", "mobile transfer",
            "savings transfer", "checking transfer"
        ]
        
        // Only flag as transfer if it looks like an internal move
        // (not a Venmo payment for dinner, which IS spending)
        return transferKeywords.contains { name.contains($0) } &&
               (name.contains("transfer") || name.contains("xfer") || primary.contains("TRANSFER"))
    }
    
    private func isInvestmentTransfer(_ name: String, _ account: Account) -> Bool {
        let investmentKeywords = [
            "vanguard", "fidelity", "schwab", "tsp", "thrift savings",
            "401k", "401(k)", "roth", "ira", "brokerage",
            "etrade", "e*trade", "robinhood", "wealthfront", "betterment",
            "contribution", "retirement", "investment"
        ]
        
        // If the account is explicitly a retirement/investment account
        if account.accountType == .retirement || account.accountType == .investment {
            return true
        }
        
        return investmentKeywords.contains { name.contains($0) }
    }
    
    private func isRefund(_ primary: String, _ name: String) -> Bool {
        return primary == "REFUND" || name.contains("refund") || name.contains("return")
    }
    
    private func isPaymentReceived(_ name: String) -> Bool {
        let paymentKeywords = [
            "payment", "thank you", "autopay",
            "online payment", "mobile payment", "ach payment"
        ]
        return paymentKeywords.contains { name.contains($0) }
    }
    
    // MARK: - Sync Transactions
    
    func syncTransactions(for account: Account) async throws {
        let plaid = PlaidService.shared
        var cursor: String? = nil
        var hasMore = true
        
        while hasMore {
            let response = try await plaid.fetchTransactions(
                accessToken: account.plaidAccessToken,
                cursor: cursor
            )
            
            for plaidTx in response.added {
                // Skip duplicates
                let existing = try modelContext.fetch(
                    FetchDescriptor<Transaction>(
                        predicate: #Predicate { $0.plaidTransactionId == plaidTx.transactionId }
                    )
                )
                guard existing.isEmpty else { continue }
                
                // Classify the transaction
                let classification = classify(plaidTx, account: account)
                
                let transaction = Transaction(
                    plaidTransactionId: plaidTx.transactionId,
                    date: parseDate(plaidTx.date),
                    amount: plaidTx.amount,
                    merchantName: plaidTx.merchantName,
                    name: plaidTx.name,
                    categoryName: mapCategory(plaidTx, classification: classification),
                    plaidCategory: plaidTx.personalFinanceCategory?.detailed,
                    isPending: plaidTx.pending,
                    isContribution: classification == .contribution,
                    isExcludedFromBudget: classification != .spending
                )
                transaction.account = account
                modelContext.insert(transaction)
                
                // Auto-create Contribution record
                if classification == .contribution {
                    let contribution = Contribution(
                        date: transaction.date,
                        amount: abs(transaction.amount),
                        label: account.contributionLabel,
                        source: .plaid
                    )
                    contribution.linkedTransaction = transaction
                    modelContext.insert(contribution)
                }
            }
            
            // Handle removed transactions
            for removed in response.removed {
                let existing = try modelContext.fetch(
                    FetchDescriptor<Transaction>(
                        predicate: #Predicate { $0.plaidTransactionId == removed.transactionId }
                    )
                )
                for tx in existing {
                    modelContext.delete(tx)
                }
            }
            
            cursor = response.nextCursor
            hasMore = response.hasMore
        }
        
        account.lastSynced = Date()
        try modelContext.save()
    }
    
    // MARK: - Category Mapping
    
    private func mapCategory(_ plaidTx: PlaidTransaction, classification: TransactionClass) -> String {
        // Non-spending gets a special category label
        switch classification {
        case .transfer:
            return "Transfer"
        case .contribution:
            return "Investment"
        case .income:
            return "Income"
        case .excluded:
            return "Excluded"
        case .spending:
            break  // Fall through to normal categorization
        }
        
        // Try Plaid category mapping
        if let plaidCat = plaidTx.personalFinanceCategory?.detailed {
            if let categories = try? modelContext.fetch(FetchDescriptor<BudgetCategory>()) {
                for cat in categories {
                    if cat.plaidCategories.contains(plaidCat) {
                        return cat.name
                    }
                }
            }
        }
        
        // Keyword matching
        let searchText = (plaidTx.merchantName ?? plaidTx.name).lowercased()
        if let categories = try? modelContext.fetch(FetchDescriptor<BudgetCategory>()) {
            for cat in categories {
                for keyword in cat.matchKeywords {
                    if searchText.contains(keyword.lowercased()) {
                        return cat.name
                    }
                }
            }
        }
        
        return "Misc"
    }
    
    private func parseDate(_ dateString: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString) ?? Date()
    }
}
