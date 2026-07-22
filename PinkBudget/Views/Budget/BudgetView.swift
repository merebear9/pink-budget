import SwiftUI
import SwiftData
import Charts

struct BudgetView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BudgetCategory.sortOrder) private var categories: [BudgetCategory]
    @Query private var transactions: [Transaction]
    
    @State private var showingAddCategory = false
    
    private var currentMonth: Int { Calendar.current.component(.month, from: Date()) }
    private var currentYear: Int { Calendar.current.component(.year, from: Date()) }
    
    private var thisMonthTransactions: [Transaction] {
        transactions.filter {
            $0.month == currentMonth && $0.year == currentYear &&
            $0.isExpense && !$0.isContribution && !$0.isExcludedFromBudget
        }
    }
    
    private func spentInCategory(_ categoryName: String) -> Double {
        thisMonthTransactions
            .filter { $0.categoryName == categoryName }
            .reduce(0) { $0 + $1.amount }
    }
    
    private var totalSpent: Double {
        thisMonthTransactions.reduce(0) { $0 + $1.amount }
    }
    
    private var totalBudget: Double {
        categories.filter(\.isActive).reduce(0) { $0 + $1.monthlyLimit }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Overview
                    overviewCard
                    
                    // Category Cards
                    ForEach(categories.filter(\.isActive)) { category in
                        CategoryCard(
                            category: category,
                            spent: spentInCategory(category.name)
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(Color.bgPrimary)
            .navigationTitle("Budget")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddCategory = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.pinkPrimary)
                    }
                }
            }
            .onAppear {
                seedDefaultCategoriesIfNeeded()
            }
        }
    }
    
    private var overviewCard: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(totalSpent.asCurrency)
                    .font(PinkTypography.money)
                    .foregroundColor(.pinkPrimary)
                Text("/ \(totalBudget.asCurrency)")
                    .font(PinkTypography.moneySmall)
                    .foregroundColor(.textMuted)
            }
            
            let remaining = totalBudget - totalSpent
            Text(remaining >= 0
                ? "\(remaining.asCurrency) left this month"
                : "\(abs(remaining).asCurrency) over budget")
                .font(PinkTypography.callout)
                .foregroundColor(remaining >= 0 ? .success : .danger)
            
            // Pie chart of spending by category
            if totalSpent > 0 {
                Chart {
                    ForEach(categories.filter(\.isActive)) { category in
                        let spent = spentInCategory(category.name)
                        if spent > 0 {
                            SectorMark(
                                angle: .value("Spent", spent),
                                innerRadius: .ratio(0.6)
                            )
                            .foregroundStyle(Color(hex: category.colorHex))
                        }
                    }
                }
                .frame(height: 160)
            }
        }
        .pinkCard()
    }
    
    private func seedDefaultCategoriesIfNeeded() {
        guard categories.isEmpty else { return }
        for category in BudgetCategory.defaultCategories() {
            modelContext.insert(category)
        }
    }
}

// MARK: - Category Card

struct CategoryCard: View {
    let category: BudgetCategory
    let spent: Double
    
    private var ratio: Double {
        category.monthlyLimit > 0 ? spent / category.monthlyLimit : 0
    }
    
    private var statusColor: Color {
        if ratio >= 1.0 { return .danger }
        if ratio >= 0.85 { return .warning }
        return Color(hex: category.colorHex)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: category.icon)
                    .foregroundColor(Color(hex: category.colorHex))
                    .frame(width: 24)
                
                Text(category.name)
                    .font(PinkTypography.body)
                
                Spacer()
                
                Text("\(spent.asCurrency) / \(category.monthlyLimit.asCurrency)")
                    .font(PinkTypography.callout)
                    .foregroundColor(.textSecondary)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.pinkLight)
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(statusColor)
                        .frame(
                            width: min(geo.size.width * ratio, geo.size.width),
                            height: 6
                        )
                }
            }
            .frame(height: 6)
        }
        .padding(12)
        .background(Color.bgCard)
        .cornerRadius(12)
        .shadow(color: Color.pinkPrimary.opacity(0.05), radius: 4, x: 0, y: 1)
    }
}
