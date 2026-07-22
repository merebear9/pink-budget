import SwiftUI
import SwiftData

struct TransactionListView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @State private var searchText = ""
    @State private var filterClass: Transaction.Classification? = nil
    
    private var filteredTransactions: [Transaction] {
        var result = transactions
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                ($0.merchantName ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
        if let cls = filterClass {
            result = result.filter { $0.classification == cls }
        }
        return result
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter chips
                filterBar
                
                if transactions.isEmpty {
                    emptyState
                } else {
                    List {
                        let grouped = Dictionary(grouping: filteredTransactions) {
                            $0.date.formatted(.dateTime.month().day().year())
                        }
                        let sorted = grouped.sorted { $0.value.first!.date > $1.value.first!.date }
                        
                        ForEach(sorted, id: \.0) { dateString, dayTxs in
                            Section(header: Text(dateString)) {
                                ForEach(dayTxs, id: \.id) { transaction in
                                    TransactionRow(transaction: transaction)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .searchable(text: $searchText, prompt: "Search transactions")
                }
            }
            .background(Color.bgPrimary)
            .navigationTitle("Transactions")
        }
    }
    
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip("All", isSelected: filterClass == nil) {
                    filterClass = nil
                }
                filterChip("Spending", isSelected: filterClass == .spending) {
                    filterClass = .spending
                }
                filterChip("Investing", isSelected: filterClass == .contribution) {
                    filterClass = .contribution
                }
                filterChip("Transfers", isSelected: filterClass == .transfer) {
                    filterClass = .transfer
                }
                filterChip("Income", isSelected: filterClass == .income) {
                    filterClass = .income
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
    
    private func filterChip(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(PinkTypography.callout)
                .foregroundColor(isSelected ? .white : .pinkPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? Color.pinkPrimary : Color.pinkLight)
                )
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 48))
                .foregroundColor(.pinkSoft)
            Text("No transactions yet")
                .font(PinkTypography.title2)
            Text("Connect your bank accounts in Settings to start importing.")
                .font(PinkTypography.body)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Transaction Row

struct TransactionRow: View {
    @Bindable var transaction: Transaction
    @State private var showingReclassify = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon based on classification
            ZStack {
                Circle()
                    .fill(iconBackgroundColor)
                    .frame(width: 36, height: 36)
                
                Image(systemName: transaction.classification.icon)
                    .font(.system(size: 14))
                    .foregroundColor(iconColor)
            }
            
            // Name, category, and classification badge
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.merchantName ?? transaction.name)
                    .font(PinkTypography.body)
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Text(transaction.categoryName)
                        .font(PinkTypography.caption)
                        .foregroundColor(.textMuted)
                    
                    // Show badge for non-spending transactions
                    if !transaction.classificationBadge.isEmpty {
                        Text(transaction.classificationBadge)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(badgeColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(badgeColor.opacity(0.12))
                            )
                    }
                }
            }
            
            Spacer()
            
            // Amount
            VStack(alignment: .trailing, spacing: 2) {
                Text(amountText)
                    .font(PinkTypography.callout)
                    .foregroundColor(amountColor)
                
                if transaction.isPending {
                    Text("Pending")
                        .font(.system(size: 9))
                        .foregroundColor(.warning)
                }
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            // Long-press to reclassify
            Menu("Classify as...") {
                Button("Spending") { transaction.reclassify(as: .spending) }
                Button("Investment") { transaction.reclassify(as: .contribution) }
                Button("Transfer") { transaction.reclassify(as: .transfer) }
                Button("Income") { transaction.reclassify(as: .income) }
                Button("Exclude") { transaction.reclassify(as: .excluded) }
            }
        }
    }
    
    private var amountText: String {
        let prefix: String
        switch transaction.classification {
        case .income: prefix = "+"
        case .spending: prefix = "-"
        case .contribution: prefix = ""
        case .transfer: prefix = ""
        case .excluded: prefix = ""
        }
        return prefix + transaction.displayAmount.asCurrency
    }
    
    private var amountColor: Color {
        switch transaction.classification {
        case .income: return .success
        case .contribution: return .info
        case .transfer: return .textMuted
        case .spending: return .textPrimary
        case .excluded: return .textMuted
        }
    }
    
    private var iconBackgroundColor: Color {
        switch transaction.classification {
        case .spending: return .bgPrimary
        case .contribution: return .pinkLight
        case .income: return Color.success.opacity(0.1)
        case .transfer: return Color.textMuted.opacity(0.1)
        case .excluded: return Color.textMuted.opacity(0.1)
        }
    }
    
    private var iconColor: Color {
        switch transaction.classification {
        case .spending: return .textSecondary
        case .contribution: return .pinkPrimary
        case .income: return .success
        case .transfer: return .textMuted
        case .excluded: return .textMuted
        }
    }
    
    private var badgeColor: Color {
        switch transaction.classification {
        case .contribution: return .info
        case .transfer: return .textMuted
        case .income: return .success
        case .excluded: return .textMuted
        case .spending: return .clear
        }
    }
}
