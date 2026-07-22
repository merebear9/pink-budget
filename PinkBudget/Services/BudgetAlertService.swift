import Foundation
import UserNotifications
import SwiftData

/// Monitors spending against budget limits and sends push notifications
/// when a category goes over budget or is close to the limit.
///
/// ALERTS:
///   - "Warning" at 85% of category limit
///   - "Over Budget" when spending exceeds category limit
///   - Optional daily summary at a configurable time

class BudgetAlertService {
    static let shared = BudgetAlertService()
    
    // Track which alerts have already fired this month so we don't spam
    private var firedAlerts: Set<String> = []
    
    // MARK: - Request Notification Permission
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { granted, error in
            if granted {
                print("Notification permission granted")
            }
        }
    }
    
    // MARK: - Check All Categories
    
    /// Call this after every transaction sync to check for budget overages
    func checkBudgets(
        transactions: [Transaction],
        categories: [BudgetCategory],
        month: Int,
        year: Int
    ) {
        for category in categories where category.isActive {
            let spent = transactions
                .filter {
                    $0.month == month &&
                    $0.year == year &&
                    $0.categoryName == category.name &&
                    $0.classification == .spending
                }
                .reduce(0.0) { $0 + $1.amount }
            
            let ratio = category.monthlyLimit > 0 ? spent / category.monthlyLimit : 0
            let alertKey = "\(year)-\(month)-\(category.name)"
            
            // Over budget alert
            if ratio >= 1.0 {
                let overKey = "\(alertKey)-over"
                if !firedAlerts.contains(overKey) {
                    sendOverBudgetAlert(
                        category: category.name,
                        spent: spent,
                        limit: category.monthlyLimit
                    )
                    firedAlerts.insert(overKey)
                }
            }
            // Warning at 85%
            else if ratio >= 0.85 {
                let warnKey = "\(alertKey)-warn"
                if !firedAlerts.contains(warnKey) {
                    sendWarningAlert(
                        category: category.name,
                        spent: spent,
                        limit: category.monthlyLimit,
                        remaining: category.monthlyLimit - spent
                    )
                    firedAlerts.insert(warnKey)
                }
            }
        }
    }
    
    // MARK: - Check Contribution Progress
    
    /// Call after syncing to check if monthly contribution target is met
    func checkContributions(
        contributions: [Contribution],
        target: Double,
        month: Int,
        year: Int
    ) {
        let total = contributions
            .filter {
                Calendar.current.component(.month, from: $0.date) == month &&
                Calendar.current.component(.year, from: $0.date) == year
            }
            .reduce(0.0) { $0 + $1.amount }
        
        let alertKey = "\(year)-\(month)-contribution-hit"
        
        if total >= target && !firedAlerts.contains(alertKey) {
            sendContributionTargetHit(total: total, target: target)
            firedAlerts.insert(alertKey)
        }
    }
    
    // MARK: - Send Notifications
    
    private func sendOverBudgetAlert(category: String, spent: Double, limit: Double) {
        let content = UNMutableNotificationContent()
        content.title = "\(category) Over Budget"
        content.body = "You've spent \(spent.asCurrency) on \(category) this month, which is \((spent - limit).asCurrency) over your \(limit.asCurrency) limit."
        content.sound = .default
        content.categoryIdentifier = "BUDGET_OVER"
        
        let request = UNNotificationRequest(
            identifier: "budget-over-\(category)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil  // Fire immediately
        )
        UNUserNotificationCenter.current().add(request)
    }
    
    private func sendWarningAlert(category: String, spent: Double, limit: Double, remaining: Double) {
        let content = UNMutableNotificationContent()
        content.title = "\(category) Almost at Limit"
        content.body = "You've used \(Int((spent / limit) * 100))% of your \(category) budget. \(remaining.asCurrency) left."
        content.sound = .default
        content.categoryIdentifier = "BUDGET_WARNING"
        
        let request = UNNotificationRequest(
            identifier: "budget-warn-\(category)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
    
    private func sendContributionTargetHit(total: Double, target: Double) {
        let content = UNMutableNotificationContent()
        content.title = "Retirement Target Hit!"
        content.body = "You've contributed \(total.asCurrency) this month, hitting your \(target.asCurrency) target."
        content.sound = UNNotificationSound(named: UNNotificationSoundName("celebration"))
        content.categoryIdentifier = "CONTRIBUTION_HIT"
        
        let request = UNNotificationRequest(
            identifier: "contribution-hit-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Daily Summary (optional)
    
    /// Schedule a daily notification summarizing budget status
    /// Fires at the specified hour (e.g., 20 = 8 PM)
    func scheduleDailySummary(at hour: Int = 20) {
        // Remove any existing daily summary
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["daily-budget-summary"]
        )
        
        let content = UNMutableNotificationContent()
        content.title = "Daily Budget Check"
        content.body = "Tap to see today's spending and contribution progress."
        content.sound = .default
        content.categoryIdentifier = "DAILY_SUMMARY"
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )
        
        let request = UNNotificationRequest(
            identifier: "daily-budget-summary",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Reset Monthly Alerts
    
    /// Call at the start of each month to clear fired alert tracking
    func resetForNewMonth() {
        firedAlerts.removeAll()
    }
}

// MARK: - Widget Data Update
// Call this after every transaction sync to refresh widgets

import WidgetKit

extension BudgetAlertService {
    /// Update the shared widget data and reload all widgets
    func updateWidgetData(
        transactions: [Transaction],
        contributions: [Contribution],
        categories: [BudgetCategory],
        contributionTarget: Double,
        month: Int,
        year: Int
    ) {
        let categorySpends = categories.map { cat in
            let spent = transactions
                .filter {
                    $0.month == month &&
                    $0.year == year &&
                    $0.categoryName == cat.name &&
                    $0.classification == .spending
                }
                .reduce(0.0) { $0 + $1.amount }
            
            return BudgetWidgetData.CategorySpend(
                id: cat.id.uuidString,
                name: cat.name,
                icon: cat.icon,
                spent: spent,
                limit: cat.monthlyLimit,
                colorHex: cat.colorHex
            )
        }
        
        let monthContribs = contributions.filter {
            Calendar.current.component(.month, from: $0.date) == month &&
            Calendar.current.component(.year, from: $0.date) == year
        }
        
        let widgetData = BudgetWidgetData(
            categories: categorySpends,
            contributionTotal: monthContribs.reduce(0) { $0 + $1.amount },
            contributionTarget: contributionTarget,
            tsp: monthContribs.filter { $0.label == .tsp }.reduce(0) { $0 + $1.amount },
            k401: monthContribs.filter { $0.label == .k401 }.reduce(0) { $0 + $1.amount },
            roth: monthContribs.filter { $0.label == .roth }.reduce(0) { $0 + $1.amount },
            other: monthContribs.filter { $0.label == .other }.reduce(0) { $0 + $1.amount },
            lastUpdated: Date()
        )
        
        SharedDataStore.save(widgetData)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
