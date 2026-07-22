import SwiftUI
import SwiftData

struct SettingsView: View {
    @AppStorage("monthlyContributionTarget") private var monthlyTarget: Double = 3500
    @AppStorage("plaidEnvironment") private var plaidEnvironment: String = "sandbox"
    @State private var targetInput: String = "3500"
    
    var body: some View {
        NavigationStack {
            Form {
                // Contribution Target
                Section {
                    HStack {
                        Text("Monthly Target")
                        Spacer()
                        TextField("$0", text: $targetInput)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            .foregroundColor(.pinkPrimary)
                            .onChange(of: targetInput) { _, newValue in
                                if let value = Double(newValue) {
                                    monthlyTarget = value
                                }
                            }
                    }
                    
                    HStack {
                        Text("Annual Target")
                            .foregroundColor(.textSecondary)
                        Spacer()
                        Text((monthlyTarget * 12).asCurrency)
                            .foregroundColor(.textSecondary)
                    }
                } header: {
                    Text("Retirement Contributions")
                } footer: {
                    Text("How much you want to contribute to retirement accounts each month across TSP, 401(k), Roth IRA, and others.")
                }
                
                // Accounts
                Section("Accounts") {
                    NavigationLink {
                        AccountsView()
                    } label: {
                        Label("Manage Accounts", systemImage: "building.columns")
                    }
                    
                    Button {
                        // TODO: Trigger sync
                    } label: {
                        Label("Sync Now", systemImage: "arrow.clockwise")
                    }
                }
                
                // Plaid Configuration
                Section {
                    Picker("Environment", selection: $plaidEnvironment) {
                        Text("Sandbox (test)").tag("sandbox")
                        Text("Development (real, free)").tag("development")
                        Text("Production (real, paid)").tag("production")
                    }
                } header: {
                    Text("Plaid")
                } footer: {
                    Text("Start in Sandbox to test, then switch to Development to connect real accounts (200 free API calls). Move to Production for ongoing use.")
                }
                
                // Data
                Section("Data") {
                    Button(role: .destructive) {
                        // TODO: Reset budget categories to defaults
                    } label: {
                        Label("Reset Budget Categories", systemImage: "arrow.counterclockwise")
                    }
                    
                    Button(role: .destructive) {
                        // TODO: Clear all data
                    } label: {
                        Label("Clear All Data", systemImage: "trash")
                    }
                }
                
                // About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.textMuted)
                    }
                    HStack {
                        Text("Bundle ID")
                        Spacer()
                        Text("com.meredithmcclain.pinkbudget")
                            .font(PinkTypography.caption)
                            .foregroundColor(.textMuted)
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                targetInput = String(format: "%.0f", monthlyTarget)
            }
        }
    }
}
