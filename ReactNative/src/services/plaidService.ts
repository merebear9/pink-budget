// PinkBudget Plaid Service
// Calls your Flask backend (not Plaid directly -- never expose secrets in the app)

const BACKEND_URL = 'https://your-backend.railway.app'; // TODO: Update this

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

export async function fetchTransactions(accessToken: string, cursor?: string) {
  const response = await fetch(`${BACKEND_URL}/api/transactions`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ access_token: accessToken, cursor: cursor || '' }),
  });
  return response.json();
}

export async function fetchBalances(accessToken: string) {
  const response = await fetch(`${BACKEND_URL}/api/balances`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ access_token: accessToken }),
  });
  return response.json();
}
