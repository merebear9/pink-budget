import Foundation
import SwiftData

@Model
final class Transaction {
    var id: UUID
    var plaidTransactionId: String?
    var date: Date
    var amount: Double                  // Positive = expense, Negative = income
    var merchantName: String?
    var name: String
    var categoryName: String
    var plaidCategory: String?
    var isPending: Bool
    var isContribution: Bool            // Flagged as retirement/investment contribution
    var isExcludedFromBudget: Bool      // Transfers, contributions, income -- anything NOT spending
    var classificationRaw: String       // "spending", "transfer", "contribution", "income", "excluded"
    var notes: String?
    var isManuallyClassified: Bool      // User overrode auto-classification
    
    @Relationship var account: Account?
    
    init(
        plaidTransactionId: String? = nil,
        date: Date,
        amount: Double,
        merchantName: String? = nil,
        name: String,
        categoryName: String = "Uncategorized",
        plaidCategory: String? = nil,
        isPending: Bool = false,
        isContribution: Bool = false,
        isExcludedFromBudget: Bool = false,
        classificationRaw: String = "spending",
        notes: String? = nil
    ) {
        self.id = UUID()
        self.plaidTransactionId = plaidTransactionId
        self.date = date
        self.amount = amount
        self.merchantName = merchantName
        self.name = name
        self.categoryName = categoryName
        self.plaidCategory = plaidCategory
        self.isPending = isPending
        self.isContribution = isContribution
        self.isExcludedFromBudget = isExcludedFromBudget
        self.classificationRaw = classificationRaw
        self.notes = notes
        self.isManuallyClassified = false
    }
}

// MARK: - Classification

extension Transaction {
    /// What this transaction counts as for budget/tracking purposes
    enum Classification: String {
        case spending       // Counts toward budget categories
        case transfer       // CC payments, internal moves -- EXCLUDED
        case contribution   // Retirement/investment -- tracked separately
        case income         // Paychecks, deposits
        case excluded       // Fees, interest, other
        
        var displayName: String {
            switch self {
            case .spending: return "Spending"
            case .transfer: return "Transfer"
            case .contribution: return "Investment"
            case .income: return "Income"
            case .excluded: return "Other"
            }
        }
        
        var icon: String {
            switch self {
            case .spending: return "cart.fill"
            case .transfer: return "arrow.left.arrow.right"
            case .contribution: return "arrow.up.circle.fill"
            case .income: return "arrow.down.circle.fill"
            case .excluded: return "minus.circle"
            }
        }
        
        var countsTowardBudget: Bool {
            self == .spending
        }
    }
    
    var classification: Classification {
        Classification(rawValue: classificationRaw) ?? .spending
    }
    
    /// Reclassify this transaction manually
    func reclassify(as newClass: Classification) {
        classificationRaw = newClass.rawValue
        isManuallyClassified = true
        isContribution = (newClass == .contribution)
        isExcludedFromBudget = !newClass.countsTowardBudget
        
        // Update category name to match
        switch newClass {
        case .transfer: categoryName = "Transfer"
        case .contribution: categoryName = "Investment"
        case .income: categoryName = "Income"
        case .excluded: categoryName = "Other"
        case .spending: break  // Keep existing category
        }
    }
}

// MARK: - Computed Properties

extension Transaction {
    var isExpense: Bool { amount > 0 && classification == .spending }
    var isIncome: Bool { classification == .income }
    var isTransfer: Bool { classification == .transfer }
    var displayAmount: Double { abs(amount) }
    
    var month: Int { Calendar.current.component(.month, from: date) }
    var year: Int { Calendar.current.component(.year, from: date) }
    
    /// Visual label for the transaction list
    var classificationBadge: String {
        switch classification {
        case .spending: return ""  // No badge needed, it's the default
        case .transfer: return "Transfer"
        case .contribution: return "Investing"
        case .income: return "Income"
        case .excluded: return "Excluded"
        }
    }
    
    /// Check if this transaction looks like a retirement contribution
    static func looksLikeContribution(_ name: String) -> Bool {
        let keywords = [
            "contribution", "allotment", "tsp", "401k", "401(k)",
            "roth", "ira", "retirement", "payroll deduction",
            "vanguard", "fidelity", "schwab"
        ]
        let lower = name.lowercased()
        return keywords.contains { lower.contains($0) }
    }
}
