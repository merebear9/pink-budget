# PinkBudget (React Native)

Cross-platform personal finance app for iOS and Android.
Budget tracking + retirement contribution monitoring with Plaid auto-import.

## Quick Start

```bash
# Install Expo CLI
npm install -g expo-cli

# Create the project
npx create-expo-app PinkBudget --template blank-typescript
cd PinkBudget

# Install dependencies
npx expo install react-native-plaid-link-sdk
npx expo install @react-navigation/native @react-navigation/bottom-tabs
npx expo install react-native-screens react-native-safe-area-context
npx expo install react-native-svg victory-native     # Charts
npx expo install @react-native-async-storage/async-storage
npx expo install expo-sqlite                          # Local database
npx expo install expo-haptics                         # Haptic feedback
npx expo install react-native-reanimated              # Animations

# Copy src/ files into the project
# Update App.tsx to import from src/App

# Run
npx expo start
```

## Project Structure

```
src/
├── App.tsx                      # Entry point with tab navigation
├── screens/
│   ├── DashboardScreen.tsx      # Combined budget + contribution overview
│   ├── TransactionsScreen.tsx   # Transaction list with filters
│   ├── BudgetScreen.tsx         # Category-based budget tracking
│   ├── ContributionsScreen.tsx  # Monthly retirement tracking
│   ├── AccountsScreen.tsx       # Plaid account management
│   └── SettingsScreen.tsx       # Configuration
├── components/
│   ├── ProgressRing.tsx         # Animated circular progress
│   ├── StatCard.tsx             # Metric display card
│   ├── TransactionRow.tsx       # Single transaction with classification
│   ├── CategoryCard.tsx         # Budget category with progress bar
│   └── FilterChips.tsx          # Filter bar for transaction types
├── services/
│   ├── plaidService.ts          # Plaid API calls via backend
│   ├── transactionService.ts    # Sync, classify, anti-double-count
│   └── database.ts              # SQLite operations
├── models/
│   └── types.ts                 # TypeScript interfaces
├── theme/
│   └── pink.ts                  # Colors, typography, spacing
└── utils/
    └── formatters.ts            # Currency, date formatting
```

## Backend

Same Flask backend as the iOS version. See `backend/server.py`.
Deploy to Railway.app (free tier) or Render.com.

## Anti-Double-Count Logic

Same classification system as iOS version:
- **Spending**: Real purchases on credit/debit → counts toward budget
- **Transfer**: CC payments, internal moves → EXCLUDED
- **Contribution**: Money to Vanguard/TSP/401k/IRA → tracked separately  
- **Income**: Paychecks, deposits → cash flow only

Users can long-press any transaction to reclassify it manually.
