// PinkBudget Plaid Service
// Calls your Flask backend (not Plaid directly -- never expose secrets in the app)

const BACKEND_URL = 'https://your-backend.railway.app'; // TODO: Update this

export interface PlaidPersonalFinanceCategory {
  primary: string;
  detailed: string;
}

export interface PlaidTransaction {
  transaction_id: string;
  account_id: string;
  amount: number;
  date: string;
  name: string;
  merchant_name: string | null;
  personal_finance_category?: PlaidPersonalFinanceCategory;
  pending: boolean;
}

export interface PlaidRemovedTransaction {
  transaction_id: string;
}

export interface TransactionSyncResponse {
  added: PlaidTransaction[];
  modified: PlaidTransaction[];
  removed: PlaidRemovedTransaction[];
  next_cursor: string;
  has_more: boolean;
}

export interface PlaidBalances {
  current: number | null;
  available: number | null;
}

export interface PlaidAccount {
  account_id: string;
  name: string;
  official_name: string | null;
  type: string; // depository, credit, investment, loan, other
  subtype: string | null;
  balances: PlaidBalances;
}

export async function createLinkToken(): Promise<string> {
  const response = await fetch(`${BACKEND_URL}/api/create_link_token`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
  });
  const data = await response.json();
  return data.link_token;
}

export async function exchangePublicToken(publicToken: string): Promise<string> {
  const response = await fetch(`${BACKEND_URL}/api/exchange_token`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ public_token: publicToken }),
  });
  const data = await response.json();
  return data.access_token;
}

export async function fetchTransactions(
  accessToken: string,
  cursor?: string
): Promise<TransactionSyncResponse> {
  const response = await fetch(`${BACKEND_URL}/api/transactions`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ access_token: accessToken, cursor: cursor || '' }),
  });
  return response.json();
}

export async function fetchBalances(accessToken: string): Promise<PlaidAccount[]> {
  const response = await fetch(`${BACKEND_URL}/api/balances`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ access_token: accessToken }),
  });
  const data = await response.json();
  return data.accounts;
}
