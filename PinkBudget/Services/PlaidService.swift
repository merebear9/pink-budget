import Foundation

// MARK: - Plaid Service
//
// Plaid requires a backend server. The flow is:
//
//   iOS App                     Your Backend                  Plaid API
//   ────────                    ────────────                  ─────────
//   1. Request link_token  ──>  POST /api/create_link_token
//                               (calls Plaid /link/token/create) ──>
//                          <──  returns link_token
//
//   2. Open Plaid Link with link_token
//      (user logs into bank)
//      Plaid Link returns public_token
//
//   3. Send public_token   ──>  POST /api/exchange_token
//                               (calls Plaid /item/public_token/exchange) ──>
//                          <──  returns access_token (STORE THIS SECURELY)
//
//   4. Fetch transactions  ──>  POST /api/transactions
//                               (calls Plaid /transactions/sync with access_token) ──>
//                          <──  returns transaction data
//
// IMPORTANT: Never send your Plaid secret to the iOS app.
//            The backend holds the secret and access_tokens.

class PlaidService {
    static let shared = PlaidService()
    
    // TODO: Replace with your deployed backend URL
    // Options for free hosting:
    //   - Railway.app (free tier)
    //   - Render.com (free tier)
    //   - Vercel serverless functions
    //   - Firebase Cloud Functions
    private let backendBaseURL = "https://your-backend.railway.app"
    
    // MARK: - Step 1: Get Link Token
    
    /// Call your backend to create a Plaid Link token
    func createLinkToken() async throws -> String {
        let url = URL(string: "\(backendBaseURL)/api/create_link_token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(LinkTokenResponse.self, from: data)
        return response.linkToken
    }
    
    // MARK: - Step 3: Exchange Public Token
    
    /// Send the public_token from Plaid Link to your backend
    func exchangePublicToken(_ publicToken: String) async throws -> String {
        let url = URL(string: "\(backendBaseURL)/api/exchange_token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["public_token": publicToken]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(ExchangeTokenResponse.self, from: data)
        return response.accessToken
    }
    
    // MARK: - Step 4: Fetch Transactions
    
    /// Fetch transactions from Plaid via your backend
    func fetchTransactions(accessToken: String, cursor: String? = nil) async throws -> TransactionSyncResponse {
        let url = URL(string: "\(backendBaseURL)/api/transactions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: String] = ["access_token": accessToken]
        if let cursor = cursor {
            body["cursor"] = cursor
        }
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(TransactionSyncResponse.self, from: data)
    }
    
    // MARK: - Fetch Account Balances
    
    func fetchBalances(accessToken: String) async throws -> [PlaidAccount] {
        let url = URL(string: "\(backendBaseURL)/api/balances")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["access_token": accessToken]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(BalancesResponse.self, from: data)
        return response.accounts
    }
}

// MARK: - Response Models

struct LinkTokenResponse: Codable {
    let linkToken: String
    
    enum CodingKeys: String, CodingKey {
        case linkToken = "link_token"
    }
}

struct ExchangeTokenResponse: Codable {
    let accessToken: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
    }
}

struct TransactionSyncResponse: Codable {
    let added: [PlaidTransaction]
    let modified: [PlaidTransaction]
    let removed: [RemovedTransaction]
    let nextCursor: String
    let hasMore: Bool
    
    enum CodingKeys: String, CodingKey {
        case added, modified, removed
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }
}

struct PlaidTransaction: Codable {
    let transactionId: String
    let accountId: String
    let amount: Double             // Positive = debit, Negative = credit
    let date: String               // "2026-07-15"
    let name: String
    let merchantName: String?
    let personalFinanceCategory: PersonalFinanceCategory?
    let pending: Bool
    
    enum CodingKeys: String, CodingKey {
        case transactionId = "transaction_id"
        case accountId = "account_id"
        case amount, date, name
        case merchantName = "merchant_name"
        case personalFinanceCategory = "personal_finance_category"
        case pending
    }
}

struct PersonalFinanceCategory: Codable {
    let primary: String
    let detailed: String
}

struct RemovedTransaction: Codable {
    let transactionId: String
    
    enum CodingKeys: String, CodingKey {
        case transactionId = "transaction_id"
    }
}

struct PlaidAccount: Codable {
    let accountId: String
    let name: String
    let officialName: String?
    let type: String               // depository, credit, investment, loan
    let subtype: String?           // checking, savings, 401k, ira, etc.
    let balances: PlaidBalances
    
    enum CodingKeys: String, CodingKey {
        case accountId = "account_id"
        case name, type, subtype, balances
        case officialName = "official_name"
    }
}

struct PlaidBalances: Codable {
    let current: Double?
    let available: Double?
}

struct BalancesResponse: Codable {
    let accounts: [PlaidAccount]
}
