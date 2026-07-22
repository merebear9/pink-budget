import SwiftUI
import SwiftData
import LinkKit

struct AccountsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var accounts: [Account]
    @State private var showingPlaidLink = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Connected accounts
                    if accounts.isEmpty {
                        emptyState
                    } else {
                        ForEach(accounts, id: \.id) { account in
                            accountCard(account)
                        }
                    }
                    
                    // Add account button
                    Button {
                        showingPlaidLink = true
                    } label: {
                        Label("Connect Account", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(PinkButtonStyle())
                    .padding(.top, 8)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(Color.bgPrimary)
            .navigationTitle("Accounts")
            .sheet(isPresented: $showingPlaidLink) {
                PlaidLinkSheet()
            }
        }
    }
    
    private func accountCard(_ account: Account) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: account.accountType.icon)
                    .foregroundColor(.pinkPrimary)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.accountName)
                        .font(PinkTypography.headline)
                    Text(account.institutionName)
                        .font(PinkTypography.caption)
                        .foregroundColor(.textMuted)
                }
                
                Spacer()
                
                Text(account.currentBalance.asCurrency)
                    .font(PinkTypography.moneySmall)
            }
            
            if account.isRetirementAccount {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.success)
                        .font(.system(size: 12))
                    Text("Tracking as \(account.contributionLabel.rawValue)")
                        .font(PinkTypography.caption)
                        .foregroundColor(.success)
                }
            }
            
            if let synced = account.lastSynced {
                Text("Last synced \(synced.formatted(.relative(presentation: .named)))")
                    .font(PinkTypography.caption)
                    .foregroundColor(.textMuted)
            }
        }
        .pinkCard()
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "building.columns")
                .font(.system(size: 48))
                .foregroundColor(.pinkSoft)
            
            Text("No accounts connected")
                .font(PinkTypography.title2)
            
            Text("Link your bank, retirement, and credit card accounts through Plaid to auto-import transactions.")
                .font(PinkTypography.body)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .padding(.vertical, 40)
    }
}

// MARK: - Plaid Link Sheet
//
// Opens Plaid Link via LinkKit (added through SPM), exchanges the
// resulting public_token for an access_token through the backend,
// fetches balances, and creates local Account records.

struct PlaidLinkSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private enum LinkState: Equatable {
        case loading
        case ready
        case linking
        case error(String)
    }

    @State private var linkState: LinkState = .loading
    @State private var linkSession: PlaidLinkSession?
    @State private var isPresentingLink = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.pinkPrimary)

                Text("Connect via Plaid")
                    .font(PinkTypography.title)

                statusView

                Button("Close") {
                    dismiss()
                }
                .buttonStyle(PinkOutlineButtonStyle())
            }
            .padding()
            .navigationTitle("Link Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task { await createLinkSession() }
            .sheet(isPresented: $isPresentingLink) {
                linkSession?.sheet()
            }
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch linkState {
        case .loading:
            ProgressView("Preparing secure connection…")
        case .ready:
            VStack(spacing: 16) {
                Text("This opens Plaid Link so you can securely log into your bank, retirement, or credit card account.")
                    .font(PinkTypography.body)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button("Connect Bank Account") {
                    isPresentingLink = true
                }
                .buttonStyle(PinkButtonStyle())
            }
        case .linking:
            ProgressView("Finishing setup…")
        case .error(let message):
            Text(message)
                .font(PinkTypography.body)
                .foregroundColor(.danger)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    private func createLinkSession() async {
        do {
            let linkToken = try await PlaidService.shared.createLinkToken()
            let configuration = LinkTokenConfiguration(
                token: linkToken,
                onSuccess: { success in
                    isPresentingLink = false
                    Task { await handleLinkSuccess(publicToken: success.publicToken) }
                },
                onExit: { exit in
                    isPresentingLink = false
                    if let error = exit.error {
                        linkState = .error(error.displayMessage ?? "Plaid Link exited with an error.")
                    }
                },
                onEvent: { _ in },
                onLoad: {
                    linkState = .ready
                }
            )
            linkSession = try Plaid.createPlaidLinkSession(configuration: configuration)
        } catch {
            linkState = .error("Couldn't start Plaid Link: \(error.localizedDescription)")
        }
    }

    private func handleLinkSuccess(publicToken: String) async {
        linkState = .linking
        do {
            let accessToken = try await PlaidService.shared.exchangePublicToken(publicToken)
            let plaidAccounts = try await PlaidService.shared.fetchBalances(accessToken: accessToken)

            var newAccounts: [Account] = []
            for plaidAccount in plaidAccounts {
                let account = Account(
                    plaidAccountId: plaidAccount.accountId,
                    plaidAccessToken: accessToken,
                    institutionName: plaidAccount.officialName ?? plaidAccount.name,
                    accountName: plaidAccount.name,
                    accountType: mapAccountType(plaidAccount.type),
                    currentBalance: plaidAccount.balances.current ?? 0
                )
                modelContext.insert(account)
                newAccounts.append(account)
            }
            try modelContext.save()

            let transactionService = TransactionService(modelContext: modelContext)
            for account in newAccounts {
                try? await transactionService.syncTransactions(for: account)
            }

            dismiss()
        } catch {
            linkState = .error("Connected, but couldn't finish setup: \(error.localizedDescription)")
        }
    }

    private func mapAccountType(_ plaidType: String) -> AccountType {
        switch plaidType {
        case "depository": return .depository
        case "credit": return .credit
        case "loan": return .loan
        case "investment": return .investment
        default: return .other
        }
    }
}
