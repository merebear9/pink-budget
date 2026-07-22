# PinkBudget

A personal budgeting app that connects to your bank, credit cards, and
retirement accounts via Plaid, auto-categorizes transactions, and tracks
retirement contributions (TSP / 401(k) / Roth IRA) separately from spending.

Two clients, sharing one backend:
- **Native iOS** (`PinkBudget.xcodeproj`) — SwiftUI + SwiftData, with home screen widgets.
- **React Native** (`ReactNative/`) — cross-platform iOS + Android, no widgets.

If you don't need home screen widgets, the React Native app is the simpler path since
it's one codebase for both platforms instead of maintaining native iOS separately.

## Repo layout

```
PinkBudget.xcodeproj/   Xcode project (app target + widget extension target)
PinkBudget/              Main app target sources (SwiftUI + SwiftData)
  Models/                 SwiftData models: Account, Transaction, BudgetCategory, Contribution
  Views/                  Dashboard, Transactions, Budget, Contributions, Accounts, Settings
  Services/               Plaid sync, transaction classification, budget alerts, email, notifications
  Theme/                  Pink color palette, typography, button styles
  Utils/                  Currency/date formatting helpers
PinkBudgetWidget/         WidgetKit extension target (budget + retirement widgets)
Backend/                  Flask server that talks to the Plaid API (holds your Plaid secret)
ReactNative/              Cross-platform (iOS + Android) client — see ReactNative/README.md
SETUP_GUIDE.md            Full step-by-step setup (Plaid, backend hosting, Xcode, email alerts)
```

## Status

### iOS (native)

The Xcode project is fully wired up:
- Both targets (`PinkBudget` app + `PinkBudgetWidget` extension) are configured with
  bundle IDs under `com.meredithmcclain`, iOS 17.0 deployment target, and team
  `M2W97D5FSY`.
- Plaid's [LinkKit](https://github.com/plaid/plaid-link-ios) is wired in via Swift
  Package Manager and actually used in `AccountsView.swift`'s `PlaidLinkSheet` to open
  Plaid Link, exchange the public token, and create `Account` records.
- App Groups (`group.com.meredithmcclain.pinkbudget`) are enabled on both targets so the
  widget can read data the main app writes to shared `UserDefaults`.
- Push Notifications + Background Modes (fetch, remote notification) are enabled on the
  app target.

Since this project was assembled outside of Xcode (no macOS available in this
environment), **you still need to open it in Xcode on a Mac** to let it resolve the
Swift Package, code-sign with your Apple Developer account, and do a real build. See
`SETUP_GUIDE.md` for the full walkthrough (Plaid account, backend hosting, email alerts).

Two things to plug in before it's fully live:
1. `Backend/` needs to be deployed somewhere (Railway, Render, etc.) — see Phase 2 of the
   setup guide.
2. `PinkBudget/Services/PlaidService.swift` has a placeholder
   `backendBaseURL = "https://your-backend.railway.app"` — replace with your deployed
   backend's URL.

### Known gap carried over from the scaffold

Nothing currently writes to the widget's shared `UserDefaults` suite
(`group.com.meredithmcclain.pinkbudget`, key `widget_budget_data`) from the main app, so
the home screen widgets will show their built-in sample data until that's added (e.g. in
`BudgetAlertService`, alongside its existing `WidgetCenter.shared.reloadAllTimelines()`
call).

### React Native (iOS + Android)

`ReactNative/` is a real, installable Expo project — `npm install` and
`npx tsc --noEmit` both run clean (verified in this environment, unlike the native iOS
build which needs an actual Mac/Xcode to compile). It has its own SQLite-backed
persistence layer, Plaid Link via `react-native-plaid-link-sdk`, and all five screens
wired to real data. See `ReactNative/README.md` for details, requirements (it needs a
dev build — Plaid Link's native code doesn't run in Expo Go), and known gaps.
