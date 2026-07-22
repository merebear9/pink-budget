import SwiftUI
import SwiftData

@main
struct PinkBudgetApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            Account.self,
            Transaction.self,
            BudgetCategory.self,
            Contribution.self,
            MerchantRule.self
        ])
    }
}

// MARK: - Main Tab View

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Image(systemName: "square.grid.2x2.fill")
                    Text("Dashboard")
                }
                .tag(0)
            
            TransactionListView()
                .tabItem {
                    Image(systemName: "list.bullet.rectangle")
                    Text("Transactions")
                }
                .tag(1)
            
            BudgetView()
                .tabItem {
                    Image(systemName: "chart.pie.fill")
                    Text("Budget")
                }
                .tag(2)
            
            ContributionsView()
                .tabItem {
                    Image(systemName: "arrow.up.circle.fill")
                    Text("Retire")
                }
                .tag(3)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
                .tag(4)
        }
        .tint(.pinkPrimary)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            Account.self,
            Transaction.self,
            BudgetCategory.self,
            Contribution.self,
            MerchantRule.self
        ], inMemory: true)
}
