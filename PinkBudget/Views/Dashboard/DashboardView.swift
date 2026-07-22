import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var transactions: [Transaction]
    @Query private var contributions: [Contribution]
    @Query private var categories: [BudgetCategory]
    
    @AppStorage("monthlyContributionTarget") private var monthlyTarget: Double = 3500
    
    private var currentMonth: Int { Calendar.current.component(.month, from: Date()) }
    private var currentYear: Int { Calendar.current.component(.year, from: Date()) }
    
    // This month's spending (non-contribution expenses)
    private var thisMonthSpending: Double {
        transactions
            .filter { $0.month == currentMonth && $0.year == currentYear }
            .filter { $0.isExpense && !$0.isContribution && !$0.isExcludedFromBudget }
            .reduce(0) { $0 + $1.amount }
    }
    
    // This month's income
    private var thisMonthIncome: Double {
        transactions
            .filter { $0.month == currentMonth && $0.year == currentYear }
            .filter { $0.isIncome }
            .reduce(0) { $0 + $1.displayAmount }
    }
    
    // This month's total budget
    private var totalBudget: Double {
        categories.filter(\.isActive).reduce(0) { $0 + $1.monthlyLimit }
    }
    
    // This month's contributions
    private var thisMonthContributions: Double {
        contributions
            .filter {
                Calendar.current.component(.month, from: $0.date) == currentMonth &&
                Calendar.current.component(.year, from: $0.date) == currentYear
            }
            .reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Budget Health Card
                    budgetCard
                    
                    // Contribution Progress Card
                    contributionCard
                    
                    // Quick Stats Row
                    HStack(spacing: 12) {
                        StatCard(
                            title: "Income",
                            value: thisMonthIncome,
                            icon: "arrow.down.circle.fill",
                            color: .success
                        )
                        StatCard(
                            title: "Spent",
                            value: thisMonthSpending,
                            icon: "arrow.up.circle.fill",
                            color: thisMonthSpending > totalBudget ? .danger : .textSecondary
                        )
                    }
                    
                    // Recent Transactions
                    recentTransactionsSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(Color.bgPrimary)
            .navigationTitle("PinkBudget")
        }
    }
    
    // MARK: - Budget Card
    
    private var budgetCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.pie.fill")
                    .foregroundColor(.pinkPrimary)
                Text("Budget This Month")
                    .font(PinkTypography.headline)
                Spacer()
                Text(budgetStatusText)
                    .font(PinkTypography.caption)
                    .foregroundColor(budgetStatusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(budgetStatusColor.opacity(0.1))
                    .cornerRadius(8)
            }
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.pinkLight)
                        .frame(height: 12)
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(budgetStatusColor)
                        .frame(
                            width: min(
                                geo.size.width * (totalBudget > 0 ? thisMonthSpending / totalBudget : 0),
                                geo.size.width
                            ),
                            height: 12
                        )
                }
            }
            .frame(height: 12)
            
            HStack {
                Text("\(thisMonthSpending.asCurrency) spent")
                    .font(PinkTypography.callout)
                    .foregroundColor(.textSecondary)
                Spacer()
                Text("\(totalBudget.asCurrency) budget")
                    .font(PinkTypography.callout)
                    .foregroundColor(.textSecondary)
            }
        }
        .pinkCard()
    }
    
    private var budgetStatusText: String {
        let ratio = totalBudget > 0 ? thisMonthSpending / totalBudget : 0
        if ratio >= 1.0 { return "Over Budget" }
        if ratio >= 0.85 { return "Close" }
        return "On Track"
    }
    
    private var budgetStatusColor: Color {
        let ratio = totalBudget > 0 ? thisMonthSpending / totalBudget : 0
        if ratio >= 1.0 { return .danger }
        if ratio >= 0.85 { return .warning }
        return .success
    }
    
    // MARK: - Contribution Card
    
    private var contributionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundColor(.pinkPrimary)
                Text("Retirement Contributions")
                    .font(PinkTypography.headline)
                Spacer()
            }
            
            HStack(alignment: .firstTextBaseline) {
                Text(thisMonthContributions.asCurrency)
                    .font(PinkTypography.money)
                    .foregroundColor(.pinkPrimary)
                Text("/ \(monthlyTarget.asCurrency)")
                    .font(PinkTypography.moneySmall)
                    .foregroundColor(.textMuted)
            }
            
            // Progress ring inline
            ProgressRing(
                progress: monthlyTarget > 0
                    ? min(thisMonthContributions / monthlyTarget, 1.0)
                    : 0,
                lineWidth: 8,
                size: 60
            )
            .frame(maxWidth: .infinity, alignment: .center)
            
            let diff = thisMonthContributions - monthlyTarget
            if diff >= 0 {
                Label("Target hit! \(diff.asCurrency) over", systemImage: "checkmark.circle.fill")
                    .font(PinkTypography.callout)
                    .foregroundColor(.success)
            } else {
                Label("\(abs(diff).asCurrency) to go", systemImage: "arrow.up.right")
                    .font(PinkTypography.callout)
                    .foregroundColor(.textSecondary)
            }
        }
        .pinkCard()
    }
    
    // MARK: - Recent Transactions
    
    private var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Transactions")
                .font(PinkTypography.headline)
                .padding(.top, 4)
            
            let recent = transactions
                .sorted { $0.date > $1.date }
                .prefix(5)
            
            if recent.isEmpty {
                Text("Connect your accounts to see transactions here.")
                    .font(PinkTypography.body)
                    .foregroundColor(.textMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                ForEach(Array(recent), id: \.id) { transaction in
                    TransactionRow(transaction: transaction)
                }
            }
        }
        .pinkCard()
    }
}
