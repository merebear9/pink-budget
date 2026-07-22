import Foundation
import SwiftData

// MARK: - Account (Plaid-linked)

@Model
final class Account {
    var id: UUID
    var plaidAccountId: String          // Plaid's account ID
    var plaidAccessToken: String        // Encrypted access token
    var institutionName: String         // "Thrift Savings Plan", "Fidelity", etc.
    var accountName: String             // "Roth IRA", "401(k)", etc.
    var accountType: AccountType
    var currentBalance: Double
    var lastSynced: Date?
    var isActive: Bool
    
    // For contribution tracking
    var isRetirementAccount: Bool
    var contributionLabel: ContributionLabel  // TSP, 401k, Roth, Other
    
    @Relationship(deleteRule: .cascade) var transactions: [Transaction]
    
    init(
        plaidAccountId: String = "",
        plaidAccessToken: String = "",
        institutionName: String,
        accountName: String,
        accountType: AccountType = .depository,
        currentBalance: Double = 0,
        isRetirementAccount: Bool = false,
        contributionLabel: ContributionLabel = .other
    ) {
        self.id = UUID()
        self.plaidAccountId = plaidAccountId
        self.plaidAccessToken = plaidAccessToken
        self.institutionName = institutionName
        self.accountName = accountName
        self.accountType = accountType
        self.currentBalance = currentBalance
        self.lastSynced = nil
        self.isActive = true
        self.isRetirementAccount = isRetirementAccount
        self.contributionLabel = contributionLabel
        self.transactions = []
    }
}

enum AccountType: String, Codable, CaseIterable {
    case depository     // Checking, savings
    case credit         // Credit cards
    case investment     // Brokerage
    case retirement     // 401k, IRA, TSP
    case loan           // Student loans, auto
    case other
    
    var icon: String {
        switch self {
        case .depository: return "banknote"
        case .credit: return "creditcard"
        case .investment: return "chart.line.uptrend.xyaxis"
        case .retirement: return "building.columns"
        case .loan: return "doc.text"
        case .other: return "ellipsis.circle"
        }
    }
}

enum ContributionLabel: String, Codable, CaseIterable {
    case tsp = "TSP"
    case k401 = "401(k)"
    case roth = "Roth IRA"
    case other = "Other"
    
    var color: String {
        switch self {
        case .tsp: return "E91E8C"
        case .k401: return "8B5CF6"
        case .roth: return "06B6D4"
        case .other: return "F59E0B"
        }
    }
}
