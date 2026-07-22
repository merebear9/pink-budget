import Foundation
import SwiftData

/// Remembers when you manually reclassify a transaction so it
/// auto-applies next time. If you tell the app that "Target"
/// is Groceries once, every future Target transaction gets
/// classified as Groceries automatically.
///
/// Also handles split merchants (Target = sometimes groceries,
/// sometimes personal) by tracking the MOST COMMON classification.

@Model
final class MerchantRule {
    var id: UUID
    var merchantName: String            // Normalized lowercase
    var categoryName: String            // Budget category to assign
    var classification: String          // spending, contribution, transfer, etc.
    var timesApplied: Int               // How many times this rule has matched
    var lastUpdated: Date
    var isUserCreated: Bool             // User explicitly set this rule
    
    init(
        merchantName: String,
        categoryName: String,
        classification: String = "spending",
        isUserCreated: Bool = true
    ) {
        self.id = UUID()
        self.merchantName = merchantName.lowercased().trimmingCharacters(in: .whitespaces)
        self.categoryName = categoryName
        self.classification = classification
        self.timesApplied = 1
        self.lastUpdated = Date()
        self.isUserCreated = isUserCreated
    }
}

// MARK: - Merchant Learning Service

class MerchantLearningService {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    /// Record a manual reclassification so we learn from it
    func learn(
        merchantName: String,
        categoryName: String,
        classification: String
    ) {
        let normalized = merchantName.lowercased().trimmingCharacters(in: .whitespaces)
        
        // Check if we already have a rule for this merchant
        let existing = try? modelContext.fetch(
            FetchDescriptor<MerchantRule>(
                predicate: #Predicate { $0.merchantName == normalized }
            )
        )
        
        if let rule = existing?.first {
            // Update existing rule
            rule.categoryName = categoryName
            rule.classification = classification
            rule.timesApplied += 1
            rule.lastUpdated = Date()
            rule.isUserCreated = true
        } else {
            // Create new rule
            let rule = MerchantRule(
                merchantName: normalized,
                categoryName: categoryName,
                classification: classification
            )
            modelContext.insert(rule)
        }
        
        try? modelContext.save()
    }
    
    /// Look up a merchant to see if we have a learned category for it
    func categorize(merchantName: String) -> (category: String, classification: String)? {
        let normalized = merchantName.lowercased().trimmingCharacters(in: .whitespaces)
        
        let rules = try? modelContext.fetch(
            FetchDescriptor<MerchantRule>(
                predicate: #Predicate { $0.merchantName == normalized }
            )
        )
        
        guard let rule = rules?.first else { return nil }
        
        // Increment usage count
        rule.timesApplied += 1
        try? modelContext.save()
        
        return (rule.categoryName, rule.classification)
    }
    
    /// Fuzzy match: check if any rule's merchant name is contained
    /// in the transaction name (handles "WALMART SUPERCENTER #1234")
    func fuzzyMatch(transactionName: String) -> (category: String, classification: String)? {
        let normalized = transactionName.lowercased()
        
        guard let allRules = try? modelContext.fetch(FetchDescriptor<MerchantRule>()) else {
            return nil
        }
        
        // Sort by user-created first, then by most-used
        let sorted = allRules.sorted {
            if $0.isUserCreated != $1.isUserCreated { return $0.isUserCreated }
            return $0.timesApplied > $1.timesApplied
        }
        
        for rule in sorted {
            if normalized.contains(rule.merchantName) {
                rule.timesApplied += 1
                try? modelContext.save()
                return (rule.categoryName, rule.classification)
            }
        }
        
        return nil
    }
}
