import SwiftUI
import SwiftData
import Charts

struct ContributionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Contribution.date, order: .reverse) private var contributions: [Contribution]
    
    @AppStorage("monthlyContributionTarget") private var monthlyTarget: Double = 3500
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var showingAddSheet = false
    
    private var annualSummary: AnnualContributionSummary {
        let yearContribs = contributions.filter {
            Calendar.current.component(.year, from: $0.date) == selectedYear
        }
        
        let months: [MonthlyContributionSummary] = (1...12).map { month in
            let monthContribs = yearContribs.filter {
                Calendar.current.component(.month, from: $0.date) == month
            }
            return MonthlyContributionSummary(
                month: month,
                year: selectedYear,
                tsp: monthContribs.filter { $0.label == .tsp }.reduce(0) { $0 + $1.amount },
                k401: monthContribs.filter { $0.label == .k401 }.reduce(0) { $0 + $1.amount },
                roth: monthContribs.filter { $0.label == .roth }.reduce(0) { $0 + $1.amount },
                other: monthContribs.filter { $0.label == .other }.reduce(0) { $0 + $1.amount }
            )
        }
        
        return AnnualContributionSummary(
            year: selectedYear,
            months: months,
            monthlyTarget: monthlyTarget
        )
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Year picker
                    yearPicker
                    
                    // YTD Summary Card
                    ytdCard
                    
                    // Monthly Bar Chart
                    monthlyChart
                    
                    // Account Breakdown
                    accountBreakdown
                    
                    // Monthly Detail List
                    monthlyDetailList
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(Color.bgPrimary)
            .navigationTitle("Contributions")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.pinkPrimary)
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddContributionSheet()
            }
        }
    }
    
    // MARK: - Year Picker
    
    private var yearPicker: some View {
        HStack {
            Button {
                selectedYear -= 1
            } label: {
                Image(systemName: "chevron.left")
                    .foregroundColor(.pinkPrimary)
            }
            
            Spacer()
            
            Text(String(selectedYear))
                .font(PinkTypography.title)
                .foregroundColor(.textPrimary)
            
            Spacer()
            
            Button {
                selectedYear += 1
            } label: {
                Image(systemName: "chevron.right")
                    .foregroundColor(.pinkPrimary)
            }
        }
        .padding(.horizontal, 8)
    }
    
    // MARK: - YTD Card
    
    private var ytdCard: some View {
        VStack(spacing: 16) {
            // Big number
            VStack(spacing: 4) {
                Text("Year to Date")
                    .font(PinkTypography.callout)
                    .foregroundColor(.textSecondary)
                Text(annualSummary.totalContributed.asCurrency)
                    .font(PinkTypography.money)
                    .foregroundColor(.pinkPrimary)
            }
            
            // Progress toward annual target
            ProgressRing(
                progress: annualSummary.percentOfTarget,
                lineWidth: 10,
                size: 100
            )
            
            // Stats row
            HStack(spacing: 0) {
                miniStat(
                    label: "Annual Target",
                    value: annualSummary.annualTarget.asCurrency
                )
                miniStat(
                    label: "Remaining",
                    value: annualSummary.remainingToTarget.asCurrency
                )
                miniStat(
                    label: "Avg/Month",
                    value: annualSummary.averageMonthly.asCurrency
                )
            }
        }
        .pinkCard()
    }
    
    private func miniStat(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(PinkTypography.callout)
                .foregroundColor(.textPrimary)
            Text(label)
                .font(PinkTypography.caption)
                .foregroundColor(.textMuted)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Monthly Bar Chart
    
    private var monthlyChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Monthly Contributions")
                .font(PinkTypography.headline)
            
            Chart {
                ForEach(annualSummary.months) { month in
                    if month.tsp > 0 {
                        BarMark(
                            x: .value("Month", month.shortMonthName),
                            y: .value("Amount", month.tsp)
                        )
                        .foregroundStyle(Color.tspColor)
                    }
                    if month.k401 > 0 {
                        BarMark(
                            x: .value("Month", month.shortMonthName),
                            y: .value("Amount", month.k401)
                        )
                        .foregroundStyle(Color.k401Color)
                    }
                    if month.roth > 0 {
                        BarMark(
                            x: .value("Month", month.shortMonthName),
                            y: .value("Amount", month.roth)
                        )
                        .foregroundStyle(Color.rothColor)
                    }
                    if month.other > 0 {
                        BarMark(
                            x: .value("Month", month.shortMonthName),
                            y: .value("Amount", month.other)
                        )
                        .foregroundStyle(Color.otherColor)
                    }
                }
                
                // Target line
                RuleMark(y: .value("Target", monthlyTarget))
                    .lineStyle(.init(lineWidth: 1.5, dash: [5, 3]))
                    .foregroundStyle(Color.textMuted)
                    .annotation(position: .trailing, alignment: .leading) {
                        Text("Target")
                            .font(.system(size: 10))
                            .foregroundColor(.textMuted)
                    }
            }
            .chartForegroundStyleScale([
                "TSP": Color.tspColor,
                "401(k)": Color.k401Color,
                "Roth IRA": Color.rothColor,
                "Other": Color.otherColor
            ])
            .frame(height: 200)
        }
        .pinkCard()
    }
    
    // MARK: - Account Breakdown
    
    private var accountBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By Account (YTD)")
                .font(PinkTypography.headline)
            
            accountRow(label: "TSP", amount: annualSummary.tspTotal, color: .tspColor)
            accountRow(label: "401(k)", amount: annualSummary.k401Total, color: .k401Color)
            accountRow(label: "Roth IRA", amount: annualSummary.rothTotal, color: .rothColor)
            
            if annualSummary.otherTotal > 0 {
                accountRow(label: "Other", amount: annualSummary.otherTotal, color: .otherColor)
            }
            
            Divider()
            
            HStack {
                Text("Total")
                    .font(PinkTypography.headline)
                Spacer()
                Text(annualSummary.totalContributed.asCurrency)
                    .font(PinkTypography.headline)
            }
        }
        .pinkCard()
    }
    
    private func accountRow(label: String, amount: Double, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(PinkTypography.body)
            Spacer()
            Text(amount.asCurrency)
                .font(PinkTypography.moneySmall)
                .foregroundColor(.textPrimary)
            
            if annualSummary.totalContributed > 0 {
                Text("(\(Int(amount / annualSummary.totalContributed * 100))%)")
                    .font(PinkTypography.caption)
                    .foregroundColor(.textMuted)
            }
        }
    }
    
    // MARK: - Monthly Detail List
    
    private var monthlyDetailList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Month by Month")
                .font(PinkTypography.headline)
            
            ForEach(annualSummary.months.reversed()) { month in
                HStack {
                    Text(month.monthName)
                        .font(PinkTypography.body)
                        .frame(width: 100, alignment: .leading)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(month.total.asCurrency)
                            .font(PinkTypography.callout)
                            .foregroundColor(month.total >= monthlyTarget ? .success : .textPrimary)
                        
                        if month.total > 0 {
                            let diff = month.vsTarget(monthlyTarget)
                            Text(diff >= 0 ? "+\(diff.asCurrency)" : "\(diff.asCurrency)")
                                .font(PinkTypography.caption)
                                .foregroundColor(diff >= 0 ? .success : .danger)
                        }
                    }
                }
                .padding(.vertical, 4)
                
                if month.month > 1 {
                    Divider()
                }
            }
        }
        .pinkCard()
    }
}

// MARK: - Add Contribution Sheet

struct AddContributionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var amount: String = ""
    @State private var selectedLabel: ContributionLabel = .roth
    @State private var date: Date = Date()
    @State private var notes: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Amount") {
                    TextField("0.00", text: $amount)
                        .keyboardType(.decimalPad)
                        .font(PinkTypography.money)
                        .foregroundColor(.pinkPrimary)
                }
                
                Section("Account") {
                    Picker("Account", selection: $selectedLabel) {
                        ForEach(ContributionLabel.allCases, id: \.self) { label in
                            Text(label.rawValue).tag(label)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Date") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                
                Section("Notes (optional)") {
                    TextField("e.g., extra paycheck contribution", text: $notes)
                }
            }
            .navigationTitle("Add Contribution")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let amt = Double(amount), amt > 0 else { return }
                        let contribution = Contribution(
                            date: date,
                            amount: amt,
                            label: selectedLabel,
                            source: .manual,
                            notes: notes.isEmpty ? nil : notes
                        )
                        modelContext.insert(contribution)
                        dismiss()
                    }
                    .buttonStyle(PinkButtonStyle())
                }
            }
        }
    }
}
