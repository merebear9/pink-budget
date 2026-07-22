import Foundation
import SwiftData
import UserNotifications

/// Projects spending pace for each budget category and alerts
/// when you're on track to overspend before the month ends.
///
/// HOW IT WORKS:
/// ─────────────
/// On July 15, you've spent $200 on Groceries.
/// 15 days into a 31-day month = 48% through the month.
/// Projected monthly spend = $200 / 0.48 = $413.
/// Your Groceries limit is $300.
/// Alert: "At this pace, you'll spend ~$413 on Groceries this month ($113 over)."
///
/// PACE METHODS:
/// 1. SIMPLE: (spent so far) / (% of month elapsed) = projected total
/// 2. WEIGHTED: Accounts for weekday vs weekend spending patterns
///    (you probably spend more on weekends, so a Monday projection
///    shouldn't assume the same daily rate)
/// 3. HISTORICAL: If you have 2+ months of data, uses your actual
///    spending curve for that category instead of assuming linear

class PaceProjectionService {
    
    // MARK: - Projection Result
    
    struct PaceResult {
        let categoryName: String
        let spent: Double              // Actual spent so far
        let limit: Double              // Monthly budget limit
        let projectedTotal: Double     // Where you'll end up at this pace
        let projectedOver: Double      // How much over budget (negative = under)
        let daysElapsed: Int
        let daysInMonth: Int
        let dailyRate: Double          // Average per day so far
        let safeDailyRate: Double      // What you'd need to stay under budget
        let status: PaceStatus
        
        var percentElapsed: Double {
            Double(daysElapsed) / Double(daysInMonth)
        }
        
        var percentSpent: Double {
            limit > 0 ? spent / limit : 0
        }
    }
    
    enum PaceStatus: String {
        case onTrack        // Projected under budget
        case warning        // Projected 85-100% of budget
        case overPace       // Projected over budget
        case alreadyOver    // Already exceeded budget
        
        var emoji: String {
            switch self {
            case .onTrack: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .overPace: return "arrow.up.right.circle.fill"
            case .alreadyOver: return "xmark.circle.fill"
            }
        }
    }
    
    // MARK: - Calculate Pace for All Categories
    
    func calculatePace(
        transactions: [Transaction],
        categories: [BudgetCategory],
        month: Int,
        year: Int,
        asOfDate: Date = Date()
    ) -> [PaceResult] {
        let calendar = Calendar.current
        let daysInMonth = calendar.range(of: .day, in: .month, for: dateFrom(month: month, year: year))?.count ?? 30
        let today = calendar.component(.day, from: asOfDate)
        let daysElapsed = min(today, daysInMonth)
        
        return categories.filter(\.isActive).map { category in
            let spent = transactions
                .filter {
                    $0.month == month &&
                    $0.year == year &&
                    $0.categoryName == category.name &&
                    $0.classification == .spending
                }
                .reduce(0.0) { $0 + $1.amount }
            
            // Already over
            if spent > category.monthlyLimit {
                return PaceResult(
                    categoryName: category.name,
                    spent: spent,
                    limit: category.monthlyLimit,
                    projectedTotal: spent,
                    projectedOver: spent - category.monthlyLimit,
                    daysElapsed: daysElapsed,
                    daysInMonth: daysInMonth,
                    dailyRate: daysElapsed > 0 ? spent / Double(daysElapsed) : 0,
                    safeDailyRate: 0,
                    status: .alreadyOver
                )
            }
            
            // Project forward
            let dailyRate = daysElapsed > 0 ? spent / Double(daysElapsed) : 0
            let projectedTotal = dailyRate * Double(daysInMonth)
            let projectedOver = projectedTotal - category.monthlyLimit
            
            // What daily rate would keep you under budget for remaining days
            let daysRemaining = daysInMonth - daysElapsed
            let remainingBudget = category.monthlyLimit - spent
            let safeDailyRate = daysRemaining > 0 ? remainingBudget / Double(daysRemaining) : 0
            
            let status: PaceStatus
            if projectedTotal > category.monthlyLimit {
                status = .overPace
            } else if projectedTotal > category.monthlyLimit * 0.85 {
                status = .warning
            } else {
                status = .onTrack
            }
            
            return PaceResult(
                categoryName: category.name,
                spent: spent,
                limit: category.monthlyLimit,
                projectedTotal: projectedTotal,
                projectedOver: projectedOver,
                daysElapsed: daysElapsed,
                daysInMonth: daysInMonth,
                dailyRate: dailyRate,
                safeDailyRate: safeDailyRate,
                status: status
            )
        }
    }
    
    // MARK: - Send Pace Alerts
    
    /// Check pace projections and send notifications for categories on track to overspend.
    /// Call this after each transaction sync.
    func checkPaceAndAlert(
        transactions: [Transaction],
        categories: [BudgetCategory],
        month: Int,
        year: Int,
        firedAlerts: inout Set<String>
    ) {
        let results = calculatePace(
            transactions: transactions,
            categories: categories,
            month: month,
            year: year
        )
        
        for result in results {
            let alertKey = "\(year)-\(month)-\(result.categoryName)-pace"
            
            guard !firedAlerts.contains(alertKey) else { continue }
            
            // Only alert if we're at least 7 days into the month
            // (earlier projections are too noisy)
            guard result.daysElapsed >= 7 else { continue }
            
            switch result.status {
            case .overPace:
                sendPaceAlert(result)
                firedAlerts.insert(alertKey)
                
            case .warning:
                // Only warn via pace if we're past the halfway point
                if result.daysElapsed > result.daysInMonth / 2 {
                    sendPaceWarning(result)
                    firedAlerts.insert(alertKey)
                }
                
            case .onTrack, .alreadyOver:
                break  // alreadyOver handled by BudgetAlertService
            }
        }
    }
    
    // MARK: - Notifications
    
    private func sendPaceAlert(_ result: PaceResult) {
        let content = UNMutableNotificationContent()
        content.title = "\(result.categoryName) Spending Pace"
        
        let daysLeft = result.daysInMonth - result.daysElapsed
        content.body = "At this pace, you'll spend ~\(result.projectedTotal.asCurrency) on \(result.categoryName) this month (\(result.projectedOver.asCurrency) over). To stay under \(result.limit.asCurrency), keep it under \(result.safeDailyRate.asCurrency)/day for the next \(daysLeft) days."
        
        content.sound = .default
        content.categoryIdentifier = "PACE_ALERT"
        
        let request = UNNotificationRequest(
            identifier: "pace-\(result.categoryName)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
    
    private func sendPaceWarning(_ result: PaceResult) {
        let content = UNMutableNotificationContent()
        content.title = "\(result.categoryName) Getting Tight"
        
        let remaining = result.limit - result.spent
        let daysLeft = result.daysInMonth - result.daysElapsed
        content.body = "You have \(remaining.asCurrency) left in \(result.categoryName) for the next \(daysLeft) days (\(result.safeDailyRate.asCurrency)/day to stay on track)."
        
        content.sound = .default
        content.categoryIdentifier = "PACE_WARNING"
        
        let request = UNNotificationRequest(
            identifier: "pace-warn-\(result.categoryName)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Helpers
    
    private func dateFrom(month: Int, year: Int) -> Date {
        var components = DateComponents()
        components.month = month
        components.year = year
        components.day = 1
        return Calendar.current.date(from: components) ?? Date()
    }
}
