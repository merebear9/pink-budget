import Foundation
import SwiftData
import UserNotifications
import WidgetKit

/// Manages the full notification and email schedule:
///
/// WEEKLY (every Sunday at 7 PM):
///   - Push notification summary
///   - Email with full category breakdown + retirement progress
///
/// REAL-TIME (after each Plaid sync):
///   - Category 85% warning (push + email)
///   - Category over budget (push + email)
///   - Pace projection alert (push + email)
///   - Retirement target hit (push + email)
///
/// MONTHLY (1st of each month):
///   - Full month report email with spending, contributions, top merchants
///
/// DAILY (optional, 8 PM):
///   - Quick push notification with remaining budget

class NotificationScheduleService {
    static let shared = NotificationScheduleService()
    
    private let emailService = EmailService.shared
    private let budgetAlerts = BudgetAlertService.shared
    private let paceService = PaceProjectionService()
    
    // Track what we've already sent this month
    private var firedAlerts: Set<String> = []
    
    // MARK: - Setup (call once on app launch)
    
    func setup() {
        budgetAlerts.requestPermission()
        scheduleWeeklySummary()
        scheduleDailyCheck()
        checkForMonthlyReport()
    }
    
    // MARK: - After Every Plaid Sync
    
    /// Call this every time transactions sync from Plaid.
    /// Checks all alert conditions and sends notifications + emails.
    func onTransactionSync(
        transactions: [Transaction],
        contributions: [Contribution],
        categories: [BudgetCategory],
        contributionTarget: Double = 2000
    ) {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: Date())
        let year = calendar.component(.year, from: Date())
        
        // Reset alerts on new month
        let monthKey = "\(year)-\(month)"
        let lastMonth = UserDefaults.standard.string(forKey: "lastAlertMonth") ?? ""
        if lastMonth != monthKey {
            firedAlerts.removeAll()
            UserDefaults.standard.set(monthKey, forKey: "lastAlertMonth")
        }
        
        // ── Check budget limits ──
        budgetAlerts.checkBudgets(
            transactions: transactions,
            categories: categories,
            month: month,
            year: year
        )
        
        // ── Check pace projections ──
        paceService.checkPaceAndAlert(
            transactions: transactions,
            categories: categories,
            month: month,
            year: year,
            firedAlerts: &firedAlerts
        )
        
        // ── Check contribution target ──
        budgetAlerts.checkContributions(
            contributions: contributions,
            target: contributionTarget,
            month: month,
            year: year
        )
        
        // ── Send email for any triggered alerts ──
        sendEmailAlerts(
            transactions: transactions,
            contributions: contributions,
            categories: categories,
            contributionTarget: contributionTarget,
            month: month,
            year: year
        )
        
        // ── Update widgets ──
        budgetAlerts.updateWidgetData(
            transactions: transactions,
            contributions: contributions,
            categories: categories,
            contributionTarget: contributionTarget,
            month: month,
            year: year
        )
    }
    
    // MARK: - Daily Check-In (every day at 8 PM)
    
    private func scheduleWeeklySummary() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["daily-checkin"]
        )
        
        let content = UNMutableNotificationContent()
        content.title = "Daily Budget Check-In"
        content.body = "Tap to see today's spending and how you're tracking."
        content.sound = .default
        content.categoryIdentifier = "DAILY_CHECKIN"
        
        var dateComponents = DateComponents()
        dateComponents.hour = 20    // 8 PM
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )
        
        let request = UNNotificationRequest(
            identifier: "daily-checkin",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }
    
    /// Build and send the daily email report.
    /// Fires every evening with spending status, category alerts,
    /// and retirement progress.
    func sendWeeklyReport(
        transactions: [Transaction],
        contributions: [Contribution],
        categories: [BudgetCategory],
        contributionTarget: Double = 2000
    ) {
        let calendar = Calendar.current
        let now = Date()
        let month = calendar.component(.month, from: now)
        let year = calendar.component(.year, from: now)
        let day = calendar.component(.day, from: now)
        let daysInMonth = calendar.range(of: .day, in: .month, for: now)?.count ?? 31
        let daysLeft = daysInMonth - day
        let weekNumber = (day - 1) / 7 + 1
        
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM"
        let monthName = monthFormatter.string(from: now)
        
        // Calculate week's spending (last 7 days)
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        
        // Build category data
        let categoryData: [[String: Any]] = categories.filter(\.isActive).map { cat in
            let spent = transactions
                .filter {
                    $0.month == month && $0.year == year &&
                    $0.categoryName == cat.name &&
                    $0.classification == .spending
                }
                .reduce(0.0) { $0 + $1.amount }
            
            let weekSpent = transactions
                .filter {
                    $0.date >= weekAgo &&
                    $0.categoryName == cat.name &&
                    $0.classification == .spending
                }
                .reduce(0.0) { $0 + $1.amount }
            
            let dailyRate = day > 0 ? spent / Double(day) : 0
            let projected = dailyRate * Double(daysInMonth)
            let remaining = cat.monthlyLimit - spent
            let safeDailyRate = daysLeft > 0 ? remaining / Double(daysLeft) : 0
            
            return [
                "name": cat.name,
                "spent": spent,
                "limit": cat.monthlyLimit,
                "week_spent": weekSpent,
                "projected": projected,
                "safe_daily": max(safeDailyRate, 0),
            ] as [String: Any]
        }
        
        let totalSpent = categoryData.reduce(0.0) { $0 + ($1["spent"] as? Double ?? 0) }
        let totalBudget = categories.filter(\.isActive).reduce(0.0) { $0 + $1.monthlyLimit }
        
        // Contributions
        let monthContribs = contributions.filter {
            calendar.component(.month, from: $0.date) == month &&
            calendar.component(.year, from: $0.date) == year
        }
        
        let contribData: [String: Any] = [
            "total": monthContribs.reduce(0.0) { $0 + $1.amount },
            "target": contributionTarget,
            "tsp": 0,  // Pre-paycheck, tracked separately
            "k401": 0, // Pre-paycheck, tracked separately
            "roth": monthContribs.filter { $0.label == .roth }.reduce(0.0) { $0 + $1.amount },
            "other": monthContribs.filter { $0.label == .other }.reduce(0.0) { $0 + $1.amount },
            "note": "TSP and 401(k) are pre-paycheck",
        ]
        
        let body: [String: Any] = [
            "week_number": weekNumber,
            "month": monthName,
            "year": year,
            "days_left": daysLeft,
            "categories": categoryData,
            "total_spent": totalSpent,
            "total_budget": totalBudget,
            "contributions": contribData,
        ]
        
        // Send to backend for email
        emailService.postToBackend(endpoint: "/api/send_weekly_report", body: body)
        
        // Also send a push notification with the highlights
        sendWeeklyPush(
            totalSpent: totalSpent,
            totalBudget: totalBudget,
            daysLeft: daysLeft,
            daysElapsed: day,
            daysInMonth: daysInMonth,
            overCount: categoryData.filter {
                ($0["spent"] as? Double ?? 0) > ($0["limit"] as? Double ?? 0)
            }.count,
            contribTotal: monthContribs.reduce(0.0) { $0 + $1.amount },
            contribTarget: contributionTarget
        )
    }
    
    private func sendWeeklyPush(
        totalSpent: Double,
        totalBudget: Double,
        daysLeft: Int,
        daysElapsed: Int,
        daysInMonth: Int,
        overCount: Int,
        contribTotal: Double,
        contribTarget: Double
    ) {
        let content = UNMutableNotificationContent()
        content.title = "Daily Budget Check-In"
        
        let remaining = totalBudget - totalSpent
        let dailySafe = daysLeft > 0 ? remaining / Double(daysLeft) : 0
        
        var lines: [String] = []
        lines.append("\(totalSpent.asCurrency) of \(totalBudget.asCurrency) spent")
        
        if remaining > 0 {
            lines.append("\(remaining.asCurrency) left (\(dailySafe.asCurrency)/day for \(daysLeft) days)")
        } else {
            lines.append("\(abs(remaining).asCurrency) over budget")
        }
        
        if overCount > 0 {
            lines.append("\(overCount) \(overCount == 1 ? "category" : "categories") over limit")
        }
        
        // Retirement pace check
        let contribPct = contribTarget > 0 ? contribTotal / contribTarget : 0
        let monthPct = daysInMonth > 0 ? Double(daysElapsed) / Double(daysInMonth) : 0
        let contribOnPace = contribPct >= monthPct
        
        if contribTotal >= contribTarget {
            lines.append("Retirement: \(contribTotal.asCurrency) -- target hit!")
        } else if contribOnPace {
            lines.append("Retirement: \(contribTotal.asCurrency)/\(contribTarget.asCurrency) -- on pace")
        } else {
            let needed = contribTarget - contribTotal
            lines.append("Retirement: \(contribTotal.asCurrency)/\(contribTarget.asCurrency) -- \(needed.asCurrency) behind")
        
        content.body = lines.joined(separator: " | ")
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "weekly-push-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
    
    // Daily check is now the main schedule (above), no separate toggle needed
    private func scheduleDailyCheck() {
        // Included in the daily check-in schedule
    }
    
    // MARK: - Monthly Report (1st of each month)
    
    func checkForMonthlyReport() {
        guard let reportMonth = emailService.shouldSendMonthlyReport() else { return }
        // The actual send needs transaction data, which happens in onTransactionSync
        UserDefaults.standard.set(true, forKey: "pendingMonthlyReport")
        UserDefaults.standard.set(reportMonth.month, forKey: "pendingReportMonth")
        UserDefaults.standard.set(reportMonth.year, forKey: "pendingReportYear")
    }
    
    /// Check if a monthly report is pending and send it.
    /// Call from onTransactionSync when data is available.
    func sendPendingMonthlyReport(
        transactions: [Transaction],
        contributions: [Contribution],
        categories: [BudgetCategory],
        contributionTarget: Double = 2000
    ) {
        guard UserDefaults.standard.bool(forKey: "pendingMonthlyReport") else { return }
        
        let month = UserDefaults.standard.integer(forKey: "pendingReportMonth")
        let year = UserDefaults.standard.integer(forKey: "pendingReportYear")
        
        guard month > 0 && year > 0 else { return }
        
        emailService.sendMonthlyReport(
            transactions: transactions,
            contributions: contributions,
            categories: categories,
            contributionTarget: contributionTarget,
            month: month,
            year: year
        )
        
        UserDefaults.standard.set(false, forKey: "pendingMonthlyReport")
        
        // Also send a push
        let content = UNMutableNotificationContent()
        content.title = "Monthly Report Sent"
        content.body = "Your end-of-month financial report is in your inbox."
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "monthly-report-sent",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Email Alerts (mirrors push notifications)
    
    private func sendEmailAlerts(
        transactions: [Transaction],
        contributions: [Contribution],
        categories: [BudgetCategory],
        contributionTarget: Double,
        month: Int,
        year: Int
    ) {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: Date())
        let daysInMonth = calendar.range(of: .day, in: .month, for: Date())?.count ?? 31
        let daysLeft = daysInMonth - day
        
        for cat in categories where cat.isActive {
            let spent = transactions
                .filter {
                    $0.month == month && $0.year == year &&
                    $0.categoryName == cat.name &&
                    $0.classification == .spending
                }
                .reduce(0.0) { $0 + $1.amount }
            
            let ratio = cat.monthlyLimit > 0 ? spent / cat.monthlyLimit : 0
            let dailyRate = day > 0 ? spent / Double(day) : 0
            let projected = dailyRate * Double(daysInMonth)
            let remaining = cat.monthlyLimit - spent
            let safeDailyRate = daysLeft > 0 ? remaining / Double(daysLeft) : 0
            
            let alertKey = "\(year)-\(month)-\(cat.name)"
            
            if spent > cat.monthlyLimit && !firedAlerts.contains("\(alertKey)-email-over") {
                emailService.sendAlert(
                    type: .overBudget,
                    category: cat.name,
                    spent: spent,
                    limit: cat.monthlyLimit
                )
                firedAlerts.insert("\(alertKey)-email-over")
            } else if ratio >= 0.85 && ratio < 1.0 && !firedAlerts.contains("\(alertKey)-email-warn") {
                emailService.sendAlert(
                    type: .budgetWarning,
                    category: cat.name,
                    spent: spent,
                    limit: cat.monthlyLimit
                )
                firedAlerts.insert("\(alertKey)-email-warn")
            }
            
            if day >= 7 && projected > cat.monthlyLimit && spent <= cat.monthlyLimit {
                if !firedAlerts.contains("\(alertKey)-email-pace") {
                    emailService.sendAlert(
                        type: .paceAlert,
                        category: cat.name,
                        spent: spent,
                        limit: cat.monthlyLimit,
                        projected: projected,
                        safeDailyRate: safeDailyRate,
                        daysRemaining: daysLeft
                    )
                    firedAlerts.insert("\(alertKey)-email-pace")
                }
            }
        }
        
        // Contribution target email
        let contribTotal = contributions
            .filter {
                calendar.component(.month, from: $0.date) == month &&
                calendar.component(.year, from: $0.date) == year
            }
            .reduce(0.0) { $0 + $1.amount }
        
        let contribKey = "\(year)-\(month)-contrib-email"
        if contribTotal >= contributionTarget && !firedAlerts.contains(contribKey) {
            emailService.sendAlert(
                type: .contributionHit,
                contributionTotal: contribTotal,
                contributionTarget: contributionTarget
            )
            firedAlerts.insert(contribKey)
        }
    }
}
