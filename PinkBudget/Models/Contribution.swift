import Foundation
import SwiftData

/// Represents a single contribution to a retirement account.
/// Auto-created from Plaid transactions flagged as contributions,
/// or manually entered.
@Model
final class Contribution {
    var id: UUID
    var date: Date
    var amount: Double
    var label: ContributionLabel        // TSP, 401(k), Roth IRA, Other
    var source: ContributionSource
    var notes: String?
    
    @Relationship var linkedTransaction: Transaction?
    
    init(
        date: Date,
        amount: Double,
        label: ContributionLabel,
        source: ContributionSource = .manual,
        notes: String? = nil
    ) {
        self.id = UUID()
        self.date = date
        self.amount = amount
        self.label = label
        self.source = source
        self.notes = notes
    }
}

enum ContributionSource: String, Codable {
    case plaid      // Auto-detected from Plaid transactions
    case manual     // Manually entered
}

// MARK: - Monthly Summary Helper

struct MonthlyContributionSummary: Identifiable {
    let id = UUID()
    let month: Int          // 1-12
    let year: Int
    let tsp: Double
    let k401: Double
    let roth: Double
    let other: Double
    
    var total: Double { tsp + k401 + roth + other }
    
    var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        var components = DateComponents()
        components.month = month
        components.year = year
        return formatter.string(from: Calendar.current.date(from: components) ?? Date())
    }
    
    var shortMonthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        var components = DateComponents()
        components.month = month
        components.year = year
        return formatter.string(from: Calendar.current.date(from: components) ?? Date())
    }
    
    func vsTarget(_ target: Double) -> Double {
        total - target
    }
}

// MARK: - Annual Summary

struct AnnualContributionSummary {
    let year: Int
    let months: [MonthlyContributionSummary]
    let monthlyTarget: Double
    
    var totalContributed: Double {
        months.reduce(0) { $0 + $1.total }
    }
    
    var annualTarget: Double {
        monthlyTarget * 12
    }
    
    var percentOfTarget: Double {
        guard annualTarget > 0 else { return 0 }
        return totalContributed / annualTarget
    }
    
    var monthsWithData: Int {
        months.filter { $0.total > 0 }.count
    }
    
    var averageMonthly: Double {
        guard monthsWithData > 0 else { return 0 }
        return totalContributed / Double(monthsWithData)
    }
    
    var remainingToTarget: Double {
        annualTarget - totalContributed
    }
    
    // Per-account YTD totals
    var tspTotal: Double { months.reduce(0) { $0 + $1.tsp } }
    var k401Total: Double { months.reduce(0) { $0 + $1.k401 } }
    var rothTotal: Double { months.reduce(0) { $0 + $1.roth } }
    var otherTotal: Double { months.reduce(0) { $0 + $1.other } }
}
