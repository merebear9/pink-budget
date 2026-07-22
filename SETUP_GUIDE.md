# PinkBudget: Complete Setup Guide
## Step-by-step from zero to fully working

---

## PHASE 1: Plaid Account (10 minutes)

### Step 1: Create Plaid developer account
- Go to https://dashboard.plaid.com/signup
- Sign up with your email
- Verify your email

### Step 2: Get your API keys
- Log into https://dashboard.plaid.com
- Click "Developers" in the left sidebar, then "Keys"
- You'll see three sets of keys:
  - **client_id** (same across all environments)
  - **Sandbox secret** (for testing with fake data)
  - **Development secret** (for real bank connections, 200 free calls)
- Copy your **client_id** and **Sandbox secret** for now

### Step 3: Request Development access
- In the dashboard, go to "API" or "Settings"
- Click "Request Development Access"
- Fill out the form:
  - Use case: "Personal finance tracking"
  - Products: select "Transactions" and "Investments"
  - Expected users: 1 (just you)
- Plaid approves Development access in 1-3 business days
- You'll get an email when approved

---

## PHASE 2: Backend Server (20 minutes)

The backend sits between your app and Plaid. It holds your secret keys
so they never touch your phone.

### Step 4: Create a Railway account
- Go to https://railway.app
- Sign up with GitHub (easiest)
- You get a free tier ($5/month credit, more than enough)

### Step 5: Create a new project on Railway
- Click "New Project"
- Select "Empty Project"
- Click "Add Service" then "Empty Service"

### Step 6: Upload the backend code
- Open the PinkBudget download folder
- Find the `Backend/` folder containing:
  - server.py
  - requirements.txt
  - Procfile
  - .env.example
- Option A: Push to a GitHub repo and connect Railway to it
- Option B: Use Railway CLI:
  ```
  npm install -g @railway/cli
  railway login
  cd Backend
  railway up
  ```

### Step 7: Set environment variables on Railway
- In your Railway service, click "Variables"
- Add these three:
  ```
  PLAID_CLIENT_ID = (paste your client_id from Step 2)
  PLAID_SECRET = (paste your sandbox secret from Step 2)
  PLAID_ENV = sandbox
  ```
- Also add your email settings (see Phase 5 below):
  ```
  SENDGRID_API_KEY = (from Step 18)
  ALERT_EMAIL = (your email address)
  ```

### Step 8: Get your backend URL
- Railway auto-generates a URL like `https://pinkbudget-production-xxxx.up.railway.app`
- Copy this URL, you'll need it in Step 13
- Test it: open `https://your-url.up.railway.app/api/create_link_token` in a browser
  - If you see a JSON response with a link_token, it's working
  - If you see an error, check your environment variables

---

## PHASE 3: Xcode Project (30 minutes)

### Step 9: Create the Xcode project
- Open Xcode
- File > New > Project
- Choose "App" under iOS
- Settings:
  - Product Name: PinkBudget
  - Team: Meredith McClain (M2W97D5FSY)
  - Organization Identifier: com.meredithmcclain
  - Interface: SwiftUI
  - Storage: SwiftData
  - Check "Include Tests" if you want

### Step 10: Add Plaid Link SDK
- File > Add Package Dependencies
- Paste: `https://github.com/plaid/plaid-link-ios`
- Click "Add Package"
- Select "LinkKit" and add to your target

### Step 11: Import the Swift files
- Unzip PinkBudget-iOS-v3.zip
- Drag these folders into your Xcode project navigator:
  - Models/ (4 files)
  - Views/ (7 files across subfolders)
  - Services/ (5 files)
  - Theme/ (1 file)
  - Utils/ (1 file)
- Replace the auto-generated ContentView.swift with PinkBudgetApp.swift
- When prompted, select "Copy items if needed"
- Make sure all .swift files have a checkmark next to your target

### Step 12: Add the Widget Extension
- File > New > Target
- Search "Widget Extension"
- Name: PinkBudgetWidget
- Click Finish
- Delete the auto-generated widget files
- Drag Widgets/PinkBudgetWidget.swift into the widget target
- Make sure its Target Membership is set to PinkBudgetWidget (not the main app)

### Step 13: Configure the backend URL
- Open Services/PlaidService.swift
- Find this line:
  ```swift
  private let backendBaseURL = "https://your-backend.railway.app"
  ```
- Replace with your actual Railway URL from Step 8

### Step 14: Enable App Groups (for widgets)
- Click your project in the navigator
- Select the main app target
- Go to "Signing & Capabilities"
- Click "+ Capability"
- Add "App Groups"
- Create group: `group.com.meredithmcclain.pinkbudget`
- Repeat for the Widget Extension target (same group ID)

### Step 15: Enable Push Notifications
- Still in "Signing & Capabilities"
- Click "+ Capability"
- Add "Push Notifications"
- Add "Background Modes" and check "Background fetch" and "Remote notifications"

### Step 16: Build and run
- Connect your iPhone via USB
- Select your device as the build target
- Hit Cmd+R to build and run
- The app will install on your phone via your dev account
- You'll need to trust the developer certificate:
  Settings > General > VPN & Device Management > find your dev cert > Trust

---

## PHASE 4: Connect Your Accounts (10 minutes)

### Step 17: Start in Sandbox to test
- Open PinkBudget on your phone
- Go to Settings tab, make sure Plaid Environment is "Sandbox"
- Go to Accounts tab, tap "Connect Account"
- Plaid Link will open
- Use these sandbox test credentials:
  - Username: user_good
  - Password: pass_good
- This connects a fake bank with fake transactions
- Verify transactions show up and are categorized correctly

### Step 17b: Switch to Development (after Plaid approves, Step 3)
- In Railway, update the environment variable:
  ```
  PLAID_SECRET = (paste your Development secret)
  PLAID_ENV = development
  ```
- In the app, go to Settings > Plaid > Development
- Now connect your real accounts:
  1. TSP (tsp.gov login)
  2. Empower Retirement / 401(k) (your Empower login)
  3. Vanguard (Roth IRA)
  4. Each credit card issuer (Chase, Amex, etc.)
  5. Your checking/savings bank
- Each connection goes through Plaid Link where you log in securely
- Transactions start importing automatically

### Step 17c: Label your retirement accounts
- After connecting, go to Accounts tab
- For each retirement account, tap it and set:
  - "Is Retirement Account" = ON
  - Contribution Label = TSP, 401(k), or Roth IRA
- This tells the app which deposits are contributions vs spending

---

## PHASE 5: Email Alerts & Monthly Report (15 minutes)

### Step 18: Create a SendGrid account (free)
- Go to https://signup.sendgrid.com
- Sign up (free tier = 100 emails/day, way more than you need)
- Go to Settings > API Keys
- Create an API key with "Mail Send" permission
- Copy the key

### Step 19: Add email settings to Railway
- In your Railway service, add these variables:
  ```
  SENDGRID_API_KEY = (paste your SendGrid API key)
  ALERT_EMAIL = (your email, e.g. meredith@gmail.com)
  FROM_EMAIL = alerts@pinkbudget.app (or any verified sender)
  ```

### Step 20: Verify your sender email in SendGrid
- In SendGrid, go to Settings > Sender Authentication
- Add and verify your FROM_EMAIL address
- They'll send a verification email, click the link

### Step 21: Redeploy your backend
- The updated server.py (in Phase 5 download) includes email endpoints
- Push the updated code to Railway:
  ```
  cd Backend
  railway up
  ```

---

## PHASE 6: You're Done!

### What happens automatically now:
- Plaid syncs transactions daily
- Each transaction is auto-classified (spending, transfer, contribution, income)
- Contributions to TSP, 401(k), and Roth IRA are tracked separately
- Budget categories fill up with real spending data
- Widgets update every 30 minutes on your home screen

### Alerts you'll receive (push notification + email):
- "Dining Almost at Limit" when you hit 85% of a category
- "Groceries Over Budget" when you exceed a category
- "At this pace, you'll spend ~$400 on Dining" when projected to overspend
- "Retirement Target Hit!" when you reach $3,500/month
- End-of-month email report on the 1st of each month

### First week tips:
- Check your transactions daily for the first week
- Long-press any miscategorized transaction to reclassify it
- The app learns from every correction (MerchantLearningService)
- After ~2 weeks, almost everything should auto-categorize correctly
- Add the widgets to your home screen (long-press home screen > + button)

---

## TROUBLESHOOTING

**Plaid Link won't open:**
- Make sure LinkKit is added to your target (Step 10)
- Check that your backend URL is correct (Step 13)
- Test the backend URL in Safari first

**Transactions not syncing:**
- Check that your backend environment variables are correct
- Make sure PLAID_ENV matches what's in the app Settings
- TSP can be slow to connect, give it 24 hours

**Widget shows placeholder data:**
- Make sure App Groups are enabled on BOTH targets (Step 14)
- The group ID must match exactly: group.com.meredithmcclain.pinkbudget
- Open the main app at least once after installing the widget

**Categories are wrong:**
- Long-press the transaction to reclassify
- The app remembers and applies your correction to future transactions
- For the first 1-2 weeks, expect to reclassify 10-20% of transactions

**CC payments counting as spending:**
- This should be handled automatically by the classification engine
- If a CC payment slips through, long-press it and classify as "Transfer"
- The app will remember that merchant pattern

---

## COST SUMMARY

| Service | Cost |
|---------|------|
| Plaid Development | Free (200 API calls) |
| Plaid Production | ~$1-3/month after free tier |
| Railway hosting | Free ($5 credit/month) |
| SendGrid email | Free (100 emails/day) |
| Apple Dev Account | Already have it |
| **Total** | **$0-3/month** |
