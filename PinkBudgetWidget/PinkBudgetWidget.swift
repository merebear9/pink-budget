// PinkBudgetWidget.swift
// Add via File > New > Target > Widget Extension in Xcode
// Name: PinkBudgetWidget
// IMPORTANT: Enable App Group in both main app and widget targets
//   Group ID: group.com.meredithmcclain.pinkbudget

import WidgetKit
import SwiftUI

// MARK: - Shared Data (App Group)
// Both the main app and widget read from the same shared container

struct BudgetWidgetData: Codable {
    let categories: [CategorySpend]
    let contributionTotal: Double
    let contributionTarget: Double
    let tsp: Double
    let k401: Double
    let roth: Double
    let other: Double
    let lastUpdated: Date
    
    struct CategorySpend: Codable, Identifiable {
        let id: String
        let name: String
        let icon: String
        let spent: Double
        let limit: Double
        let colorHex: String
        
        var ratio: Double { limit > 0 ? spent / limit : 0 }
        var isOver: Bool { spent > limit }
        var remaining: Double { limit - spent }
    }
}

// Helper to read/write shared data
struct SharedDataStore {
    static let suiteName = "group.com.meredithmcclain.pinkbudget"
    static let budgetKey = "widget_budget_data"
    
    static func load() -> BudgetWidgetData? {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: budgetKey) else { return nil }
        return try? JSONDecoder().decode(BudgetWidgetData.self, from: data)
    }
    
    static func save(_ data: BudgetWidgetData) {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let encoded = try? JSONEncoder().encode(data) else { return }
        defaults.set(encoded, forKey: budgetKey)
    }
}

// MARK: - Timeline Provider

struct BudgetTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> BudgetEntry {
        BudgetEntry(date: Date(), data: sampleData)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (BudgetEntry) -> Void) {
        let data = SharedDataStore.load() ?? sampleData
        completion(BudgetEntry(date: Date(), data: data))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<BudgetEntry>) -> Void) {
        let data = SharedDataStore.load() ?? sampleData
        let entry = BudgetEntry(date: Date(), data: data)
        // Refresh every 30 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private var sampleData: BudgetWidgetData {
        BudgetWidgetData(
            categories: [
                .init(id: "1", name: "Groceries", icon: "cart.fill", spent: 187, limit: 300, colorHex: "10B981"),
                .init(id: "2", name: "Dining", icon: "fork.knife", spent: 142, limit: 150, colorHex: "F59E0B"),
                .init(id: "3", name: "Gas", icon: "car.fill", spent: 89, limit: 200, colorHex: "6366F1"),
                .init(id: "4", name: "Cat Care", icon: "pawprint.fill", spent: 45, limit: 100, colorHex: "EC4899"),
                .init(id: "5", name: "Rent", icon: "house.fill", spent: 800, limit: 800, colorHex: "E91E8C"),
                .init(id: "6", name: "Subscriptions", icon: "tv.fill", spent: 32, limit: 50, colorHex: "8B5CF6"),
                .init(id: "7", name: "Personal", icon: "bag.fill", spent: 67, limit: 150, colorHex: "06B6D4"),
                .init(id: "8", name: "Misc", icon: "ellipsis.circle", spent: 23, limit: 100, colorHex: "9CA3AF"),
            ],
            contributionTotal: 2133,
            contributionTarget: 3500,
            tsp: 400,
            k401: 650,
            roth: 583,
            other: 500,
            lastUpdated: Date()
        )
    }
}

// MARK: - Timeline Entry

struct BudgetEntry: TimelineEntry {
    let date: Date
    let data: BudgetWidgetData
}

// ═══════════════════════════════════════════════
// WIDGET 1: Budget Categories (Medium or Large)
// ═══════════════════════════════════════════════

struct BudgetCategoriesWidget: Widget {
    let kind = "BudgetCategoriesWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BudgetTimelineProvider()) { entry in
            BudgetCategoriesView(entry: entry)
                .containerBackground(.white, for: .widget)
        }
        .configurationDisplayName("Budget Tracker")
        .description("See spending by category this month")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct BudgetCategoriesView: View {
    let entry: BudgetEntry
    
    @Environment(\.widgetFamily) var family
    
    private var totalSpent: Double {
        entry.data.categories.reduce(0) { $0 + $1.spent }
    }
    private var totalBudget: Double {
        entry.data.categories.reduce(0) { $0 + $1.limit }
    }
    private var overBudgetCount: Int {
        entry.data.categories.filter(\.isOver).count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack {
                Text("Budget")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "E91E8C"))
                
                Spacer()
                
                if overBudgetCount > 0 {
                    Text("\(overBudgetCount) over")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: "EF4444"))
                        .cornerRadius(4)
                }
                
                Text("\(totalSpent.shortCurrency) / \(totalBudget.shortCurrency)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(hex: "6B7280"))
            }
            
            // Category rows
            let displayCount = family == .systemLarge ? entry.data.categories.count : min(entry.data.categories.count, 4)
            let sortedCats = entry.data.categories.sorted { $0.ratio > $1.ratio }
            
            ForEach(sortedCats.prefix(displayCount)) { cat in
                HStack(spacing: 6) {
                    // Icon
                    Image(systemName: cat.icon)
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: cat.colorHex))
                        .frame(width: 14)
                    
                    // Name
                    Text(cat.name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: "1F1F1F"))
                        .frame(width: 70, alignment: .leading)
                    
                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(hex: "FCE4F2"))
                                .frame(height: 6)
                            
                            RoundedRectangle(cornerRadius: 2)
                                .fill(cat.isOver ? Color(hex: "EF4444") : Color(hex: cat.colorHex))
                                .frame(width: min(geo.size.width * cat.ratio, geo.size.width), height: 6)
                        }
                    }
                    .frame(height: 6)
                    
                    // Amount
                    Text(cat.isOver ? "OVER" : cat.remaining.shortCurrency)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(cat.isOver ? Color(hex: "EF4444") : Color(hex: "9CA3AF"))
                        .frame(width: 36, alignment: .trailing)
                }
            }
            
            if family == .systemMedium && entry.data.categories.count > 4 {
                Text("+\(entry.data.categories.count - 4) more")
                    .font(.system(size: 9))
                    .foregroundColor(Color(hex: "9CA3AF"))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(14)
    }
}

// ═══════════════════════════════════════════════
// WIDGET 2: Retirement Contributions (Small)
// ═══════════════════════════════════════════════

struct ContributionsWidget: Widget {
    let kind = "ContributionsWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BudgetTimelineProvider()) { entry in
            ContributionsWidgetView(entry: entry)
                .containerBackground(.white, for: .widget)
        }
        .configurationDisplayName("Retire Tracker")
        .description("Monthly retirement contributions vs target")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct ContributionsWidgetView: View {
    let entry: BudgetEntry
    
    @Environment(\.widgetFamily) var family
    
    private var progress: Double {
        entry.data.contributionTarget > 0
            ? min(entry.data.contributionTotal / entry.data.contributionTarget, 1.0)
            : 0
    }
    private var isOnTrack: Bool {
        entry.data.contributionTotal >= entry.data.contributionTarget
    }
    
    var body: some View {
        if family == .systemSmall {
            smallView
        } else {
            mediumView
        }
    }
    
    // Small widget: ring + amount
    private var smallView: some View {
        VStack(spacing: 8) {
            Text("Retire")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "E91E8C"))
            
            ZStack {
                Circle()
                    .stroke(Color(hex: "FCE4F2"), lineWidth: 6)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        isOnTrack ? Color(hex: "10B981") : Color(hex: "E91E8C"),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(isOnTrack ? Color(hex: "10B981") : Color(hex: "E91E8C"))
            }
            
            Text(entry.data.contributionTotal.shortCurrency)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: "1F1F1F"))
            
            Text("of \(entry.data.contributionTarget.shortCurrency)")
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "9CA3AF"))
        }
        .padding(12)
    }
    
    // Medium widget: ring + account breakdown
    private var mediumView: some View {
        HStack(spacing: 16) {
            // Left: ring
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .stroke(Color(hex: "FCE4F2"), lineWidth: 8)
                        .frame(width: 70, height: 70)
                    
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            isOnTrack ? Color(hex: "10B981") : Color(hex: "E91E8C"),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 0) {
                        Text(entry.data.contributionTotal.shortCurrency)
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                        Text("of \(entry.data.contributionTarget.shortCurrency)")
                            .font(.system(size: 8))
                            .foregroundColor(Color(hex: "9CA3AF"))
                    }
                }
                
                Text(isOnTrack ? "On Track" : "\((entry.data.contributionTarget - entry.data.contributionTotal).shortCurrency) to go")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isOnTrack ? Color(hex: "10B981") : Color(hex: "6B7280"))
            }
            
            // Right: account breakdown
            VStack(alignment: .leading, spacing: 6) {
                Text("Retire")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "E91E8C"))
                
                accountRow("TSP", amount: entry.data.tsp, color: "E91E8C")
                accountRow("401(k)", amount: entry.data.k401, color: "8B5CF6")
                accountRow("Roth", amount: entry.data.roth, color: "06B6D4")
                
                if entry.data.other > 0 {
                    accountRow("Other", amount: entry.data.other, color: "F59E0B")
                }
            }
        }
        .padding(14)
    }
    
    private func accountRow(_ label: String, amount: Double, color: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color(hex: color))
                .frame(width: 6, height: 6)
            
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "6B7280"))
                .frame(width: 40, alignment: .leading)
            
            Text(amount.shortCurrency)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(Color(hex: "1F1F1F"))
        }
    }
}

// ═══════════════════════════════════════════════
// WIDGET 3: Combined (Large)
// ═══════════════════════════════════════════════

struct CombinedWidget: Widget {
    let kind = "CombinedWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BudgetTimelineProvider()) { entry in
            CombinedWidgetView(entry: entry)
                .containerBackground(.white, for: .widget)
        }
        .configurationDisplayName("PinkBudget")
        .description("Budget + retirement contributions at a glance")
        .supportedFamilies([.systemLarge])
    }
}

struct CombinedWidgetView: View {
    let entry: BudgetEntry
    
    private var totalSpent: Double {
        entry.data.categories.reduce(0) { $0 + $1.spent }
    }
    private var totalBudget: Double {
        entry.data.categories.reduce(0) { $0 + $1.limit }
    }
    private var progress: Double {
        entry.data.contributionTarget > 0
            ? min(entry.data.contributionTotal / entry.data.contributionTarget, 1.0)
            : 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // ── Top: Retirement ──
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Retirement")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "E91E8C"))
                    
                    Text("\(entry.data.contributionTotal.shortCurrency) / \(entry.data.contributionTarget.shortCurrency)")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                }
                
                Spacer()
                
                // Mini ring
                ZStack {
                    Circle()
                        .stroke(Color(hex: "FCE4F2"), lineWidth: 5)
                        .frame(width: 40, height: 40)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color(hex: "E91E8C"), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color(hex: "E91E8C"))
                }
                
                // Account mini-bars
                VStack(alignment: .leading, spacing: 3) {
                    miniAccount("TSP", entry.data.tsp, "E91E8C")
                    miniAccount("401k", entry.data.k401, "8B5CF6")
                    miniAccount("Roth", entry.data.roth, "06B6D4")
                }
            }
            
            Divider()
            
            // ── Bottom: Budget categories ──
            HStack {
                Text("Budget")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "E91E8C"))
                Spacer()
                Text("\(totalSpent.shortCurrency) / \(totalBudget.shortCurrency)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(hex: "6B7280"))
            }
            
            let sorted = entry.data.categories.sorted { $0.ratio > $1.ratio }
            ForEach(sorted.prefix(6)) { cat in
                HStack(spacing: 6) {
                    Image(systemName: cat.icon)
                        .font(.system(size: 9))
                        .foregroundColor(Color(hex: cat.colorHex))
                        .frame(width: 12)
                    
                    Text(cat.name)
                        .font(.system(size: 10, weight: .medium))
                        .frame(width: 65, alignment: .leading)
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(hex: "FCE4F2"))
                                .frame(height: 5)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(cat.isOver ? Color(hex: "EF4444") : Color(hex: cat.colorHex))
                                .frame(width: min(geo.size.width * cat.ratio, geo.size.width), height: 5)
                        }
                    }
                    .frame(height: 5)
                    
                    Text("\(cat.spent.shortCurrency)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(cat.isOver ? Color(hex: "EF4444") : Color(hex: "6B7280"))
                        .frame(width: 32, alignment: .trailing)
                }
            }
        }
        .padding(14)
    }
    
    private func miniAccount(_ label: String, _ amount: Double, _ color: String) -> some View {
        HStack(spacing: 3) {
            Circle().fill(Color(hex: color)).frame(width: 4, height: 4)
            Text("\(label) \(amount.shortCurrency)")
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(Color(hex: "6B7280"))
        }
    }
}

// MARK: - Widget Bundle

@main
struct PinkBudgetWidgets: WidgetBundle {
    var body: some Widget {
        BudgetCategoriesWidget()
        ContributionsWidget()
        CombinedWidget()
    }
}

// MARK: - Currency Helper

extension Double {
    var shortCurrency: String {
        if abs(self) >= 1000 {
            return String(format: "$%.1fK", self / 1000)
        }
        return String(format: "$%.0f", self)
    }
}

// MARK: - Color Helper (duplicated for widget target)

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b)
    }
}
