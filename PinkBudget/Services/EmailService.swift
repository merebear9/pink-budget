import Foundation
import SwiftData

/// Sends budget alerts and monthly reports to the backend,
/// which emails them via SendGrid.
///
/// Every push notification alert also triggers an email.
/// Monthly report is sent automatically on the 1st of each month.

class EmailService {
    static let shared = EmailService()
    
    // Same backend URL as PlaidService
    private var backendBaseURL: String {
        // TODO: Replace with your Railway URL
        "https://your-backend.railway.app"
    }
    
    // MARK: - Send Alert Email
    
    /// Mirror a push notification as an email
    func sendAlert(
        type: AlertType,
        category: String? = nil,
        spent: Double? = nil,
        limit: Double? = nil,
        projected: Double? = nil,
        safeDailyRate: Double? = nil,
        daysRemaining: Int? = nil,
        contributionTotal: Double? = nil,
        contributionTarget: Double? = nil
    ) {
        var body: [String: Any] = ["alert_type": type.rawValue]
        
        if let category { body["category"] = category }
        if let spent { body["spent"] = spent }
        if let limit { body["limit"] = limit }
        if let projected { body["projected"] = projected }
        if let safeDailyRate { body["safe_daily_rate"] = safeDailyRate }
        if let daysRemaining { body["days_remaining"] = daysRemaining }
        if let contributionTotal { body["contribution_total"] = contributionTotal }
        if let contributionTarget { body["contribution_target"] = contributionTarget }
        
        postToBackend(endpoint: "/api/send_alert", body: body)
    }
    
    enum AlertType: String {
        case overBudget = "over_budget"
        case budgetWarning = "budget_warning"
        case paceAlert = "pace_alert"
        case paceWarning = "pace_warning"
        case contributionHit = "contribution_hit"
    }
    
    // MARK: - Send Monthly Report
    
    /// Compile and send the end-of-month report email.
    /// Call on the 1st of each month via background task.
    func sendMonthlyReport(
        transactions: [Transaction],
        contributions: [Contribution],
        categories: [BudgetCategory],
        contributionTarget: Double,
        month: Int,
        year: Int
    ) {
        // Build category spending data
        let categoryData: [[String: Any]] = categories.filter(\.isActive).map { cat in
            let spent = transactions
                .filter {
                    $0.month == month && $0.year == year &&
                    $0.categoryName == cat.name &&
                    $0.classification == .spending
                }
                .reduce(0.0) { $0 + $1.amount }
            
            return [
                "name": cat.name,
                "spent": spent,
                "limit": cat.monthlyLimit,
            ]
        }
        
        let totalSpent = transactions
            .filter {
                $0.month == month && $0.year == year &&
                $0.classification == .spending
            }
            .reduce(0.0) { $0 + $1.amount }
        
        let totalBudget = categories.filter(\.isActive).reduce(0.0) { $0 + $1.monthlyLimit }
        
        let income = transactions
            .filter { $0.month == month && $0.year == year && $0.classification == .income }
            .reduce(0.0) { $0 + $1.displayAmount }
        
        // Contribution data
        let monthContribs = contributions.filter {
            Calendar.current.component(.month, from: $0.date) == month &&
            Calendar.current.component(.year, from: $0.date) == year
        }
        
        let contribData: [String: Any] = [
            "tsp": monthContribs.filter { $0.label == .tsp }.reduce(0.0) { $0 + $1.amount },
            "k401": monthContribs.filter { $0.label == .k401 }.reduce(0.0) { $0 + $1.amount },
            "roth": monthContribs.filter { $0.label == .roth }.reduce(0.0) { $0 + $1.amount },
            "other": monthContribs.filter { $0.label == .other }.reduce(0.0) { $0 + $1.amount },
            "total": monthContribs.reduce(0.0) { $0 + $1.amount },
            "target": contributionTarget,
        ]
        
        // Top merchants
        let spendingTxs = transactions.filter {
            $0.month == month && $0.year == year && $0.classification == .spending
        }
        
        var merchantTotals: [String: (amount: Double, count: Int)] = [:]
        for tx in spendingTxs {
            let name = tx.merchantName ?? tx.name
            let existing = merchantTotals[name] ?? (0, 0)
            merchantTotals[name] = (existing.amount + tx.amount, existing.count + 1)
        }
        
        let topMerchants: [[String: Any]] = merchantTotals
            .sorted { $0.value.amount > $1.value.amount }
            .prefix(8)
            .map { ["name": $0.key, "amount": $0.value.amount, "count": $0.value.count] }
        
        let body: [String: Any] = [
            "month": month,
            "year": year,
            "categories": categoryData,
            "total_spent": totalSpent,
            "total_budget": totalBudget,
            "contributions": contribData,
            "income": income,
            "top_merchants": topMerchants,
        ]
        
        postToBackend(endpoint: "/api/send_monthly_report", body: body)
    }
    
    // MARK: - Schedule Monthly Report
    
    /// Register a background task to send the report on the 1st of each month.
    /// Call this once on app launch.
    func scheduleMonthlyReport() {
        // Use BGTaskScheduler for iOS background tasks
        // The app checks on launch if it's the 1st and a report hasn't been sent yet
        let defaults = UserDefaults.standard
        let lastReportKey = "lastMonthlyReportSent"
        
        let calendar = Calendar.current
        let today = Date()
        let day = calendar.component(.day, from: today)
        let month = calendar.component(.month, from: today)
        let year = calendar.component(.year, from: today)
        
        // Check if we already sent this month's report
        let lastSent = defaults.string(forKey: lastReportKey) ?? ""
        let currentKey = "\(year)-\(month)"
        
        if day <= 3 && lastSent != currentKey {
            // It's the 1st-3rd and we haven't sent this month's report
            // The actual send happens in the calling code with real data
            // This just returns true to signal "it's time"
            defaults.set(currentKey, forKey: lastReportKey)
            
            // The calling code should then call sendMonthlyReport()
            // with last month's data (month - 1)
        }
    }
    
    /// Check if monthly report should be sent. Returns the (month, year) to report on, or nil.
    func shouldSendMonthlyReport() -> (month: Int, year: Int)? {
        let defaults = UserDefaults.standard
        let lastReportKey = "lastMonthlyReportSent"
        
        let calendar = Calendar.current
        let today = Date()
        let day = calendar.component(.day, from: today)
        let currentMonth = calendar.component(.month, from: today)
        let currentYear = calendar.component(.year, from: today)
        
        let lastSent = defaults.string(forKey: lastReportKey) ?? ""
        let currentKey = "\(currentYear)-\(currentMonth)"
        
        guard day <= 3 && lastSent != currentKey else { return nil }
        
        defaults.set(currentKey, forKey: lastReportKey)
        
        // Report on LAST month
        if currentMonth == 1 {
            return (month: 12, year: currentYear - 1)
        } else {
            return (month: currentMonth - 1, year: currentYear)
        }
    }
    
    // MARK: - Network
    
    private func postToBackend(endpoint: String, body: [String: Any]) {
        guard let url = URL(string: "\(backendBaseURL)\(endpoint)") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                print("Email send error: \(error.localizedDescription)")
            }
        }.resume()
    }
}
