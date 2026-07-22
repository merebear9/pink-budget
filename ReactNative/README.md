# PinkBudget (React Native)

Cross-platform personal finance app for iOS and Android — one codebase for both
platforms, since neither the widgets nor Apple-only frameworks (SwiftUI/SwiftData)
are needed here. Budget tracking + retirement contribution monitoring with Plaid
auto-import, backed by the same Flask backend as the iOS app.

## Status

This is a real, installable Expo project (not just loose source files) — `npm install`
+ `npx tsc --noEmit` both run clean.

- **Navigation**: bottom tabs (Dashboard, Transactions, Budget, Retire, Settings) plus
  an "Accounts" screen pushed from Settings, matching the iOS app's structure.
- **Persistence**: `src/database.ts` — a SQLite-backed store (via `expo-sqlite`) for
  accounts, transactions, budget categories, contributions, and settings. No server
  round-trip needed for anything except Plaid itself.
- **Plaid Link**: wired in `AccountsScreen.tsx` via `react-native-plaid-link-sdk`,
  using the real `createPlaidLinkSession` API — opens Link, exchanges the public
  token, fetches balances, and creates local accounts.
- **Sync + classification**: `src/services/transactionService.ts` has the same
  anti-double-count classification logic as the iOS app (spending vs. transfer vs.
  contribution vs. income), plus a `syncAccountTransactions` function that pages
  through Plaid's `/transactions/sync` cursor and persists results.
- **All screens are wired to real data** via `src/context/DataContext.tsx` (a React
  Context wrapping the database) — nothing is hardcoded to `$0` or empty arrays
  anymore.

## Requirements

`react-native-plaid-link-sdk` ships real native code, so **Expo Go will not work** —
Plaid Link needs a development build. Use `npx expo run:ios` / `npx expo run:android`
(requires Xcode / Android Studio respectively), or build one with
[EAS Build](https://docs.expo.dev/build/introduction/) if you don't have the native
SDKs installed locally.

## Quick start

```bash
cd ReactNative
npm install
npx expo run:android   # or: npx expo run:ios (macOS only)
```

Then, same as the iOS app:
1. Deploy `../Backend/` (Flask) somewhere reachable — see the root `SETUP_GUIDE.md`.
2. Update `BACKEND_URL` in `src/services/plaidService.ts` with that URL.
3. Register your Android package name (`com.meredithmcclain.pinkbudget`, set in
   `app.json`) and/or iOS bundle identifier in the Plaid Dashboard so OAuth redirects
   work.

## Project Structure

```
App.tsx                          # Thin re-export of src/App (Expo's entry point)
index.ts                         # registerRootComponent
app.json                         # Expo config (bundle IDs, icons, etc.)
src/
├── App.tsx                      # Navigation root: DataProvider + Stack(Main tabs, Accounts)
├── screens/
│   ├── DashboardScreen.tsx      # Budget + contribution overview, recent transactions
│   ├── TransactionsScreen.tsx   # Transaction list with classification filters
│   ├── BudgetScreen.tsx         # Category-based budget tracking
│   ├── ContributionsScreen.tsx  # Monthly retirement tracking + Add Contribution modal
│   ├── AccountsScreen.tsx       # Plaid Link + connected account list
│   └── SettingsScreen.tsx       # Monthly target, Plaid environment, sync
├── context/
│   └── DataContext.tsx          # App-wide state: loads/persists via database.ts
├── database.ts                  # SQLite schema + CRUD (expo-sqlite)
├── services/
│   ├── plaidService.ts          # Plaid API calls via backend (+ response types)
│   ├── transactionService.ts    # Classification + Plaid sync loop
│   └── budgetService.ts         # Spending/contribution aggregation for the UI
├── models/
│   └── types.ts                 # Shared TypeScript interfaces + default categories
├── navigation/
│   └── types.ts                 # RootStackParamList
├── theme/
│   └── pink.ts                  # Colors, typography, spacing
└── utils/
    └── formatters.ts            # Currency/date formatting helpers
```

## Anti-Double-Count Logic

Same classification system as the iOS app:
- **Spending**: Real purchases on credit/debit → counts toward budget
- **Transfer**: CC payments, internal moves → EXCLUDED
- **Contribution**: Money to Vanguard/TSP/401k/IRA → tracked separately
- **Income**: Paychecks, deposits → cash flow only

## Known gaps

- Manual transaction reclassification (long-press to fix a miscategorized
  transaction) has a `reclassifyTransaction` function in `database.ts` but no UI
  hooked up to it yet.
- No account-level UI for marking an account as retirement / setting its
  contribution label after connecting (`setAccountRetirementInfo` exists in
  `database.ts`, unused) — mirrors a similar gap in the iOS app's Setup Guide (its
  Step 17c isn't implemented there either).
