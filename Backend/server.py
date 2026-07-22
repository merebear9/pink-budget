"""
PinkBudget Backend Server (v2)
──────────────────────────────
Flask server for Plaid API + Email Alerts + Monthly Reports

Setup:
  pip install flask plaid-python python-dotenv sendgrid apscheduler

  .env file:
    PLAID_CLIENT_ID=your_client_id
    PLAID_SECRET=your_secret
    PLAID_ENV=sandbox
    SENDGRID_API_KEY=your_sendgrid_key
    ALERT_EMAIL=your@email.com
    FROM_EMAIL=alerts@pinkbudget.app
"""

import os
import json
from datetime import datetime, timedelta
from flask import Flask, request, jsonify
from dotenv import load_dotenv
import plaid
from plaid.api import plaid_api
from plaid.model.link_token_create_request import LinkTokenCreateRequest
from plaid.model.link_token_create_request_user import LinkTokenCreateRequestUser
from plaid.model.item_public_token_exchange_request import ItemPublicTokenExchangeRequest
from plaid.model.transactions_sync_request import TransactionsSyncRequest
from plaid.model.accounts_balance_get_request import AccountsBalanceGetRequest
from plaid.model.products import Products
from plaid.model.country_code import CountryCode
from sendgrid import SendGridAPIClient
from sendgrid.helpers.mail import Mail, HtmlContent
from apscheduler.schedulers.background import BackgroundScheduler

load_dotenv()

app = Flask(__name__)

# ── Plaid Setup ──
PLAID_CLIENT_ID = os.getenv("PLAID_CLIENT_ID")
PLAID_SECRET = os.getenv("PLAID_SECRET")
PLAID_ENV = os.getenv("PLAID_ENV", "sandbox")

env_map = {
    "sandbox": plaid.Environment.Sandbox,
    "development": plaid.Environment.Development,
    "production": plaid.Environment.Production,
}

configuration = plaid.Configuration(
    host=env_map.get(PLAID_ENV, plaid.Environment.Sandbox),
    api_key={"clientId": PLAID_CLIENT_ID, "secret": PLAID_SECRET},
)
api_client = plaid.ApiClient(configuration)
client = plaid_api.PlaidApi(api_client)

# ── Email Setup ──
SENDGRID_API_KEY = os.getenv("SENDGRID_API_KEY")
ALERT_EMAIL = os.getenv("ALERT_EMAIL")
FROM_EMAIL = os.getenv("FROM_EMAIL", "alerts@pinkbudget.app")

sg = SendGridAPIClient(SENDGRID_API_KEY) if SENDGRID_API_KEY else None


# ═══════════════════════════════════════
# PLAID ENDPOINTS (same as v1)
# ═══════════════════════════════════════

@app.route("/api/create_link_token", methods=["POST"])
def create_link_token():
    req = LinkTokenCreateRequest(
        products=[Products("transactions"), Products("investments")],
        client_name="PinkBudget",
        country_codes=[CountryCode("US")],
        language="en",
        user=LinkTokenCreateRequestUser(client_user_id="pinkbudget-user"),
    )
    response = client.link_token_create(req)
    return jsonify({"link_token": response["link_token"]})


@app.route("/api/exchange_token", methods=["POST"])
def exchange_token():
    data = request.get_json()
    req = ItemPublicTokenExchangeRequest(public_token=data["public_token"])
    response = client.item_public_token_exchange(req)
    return jsonify({
        "access_token": response["access_token"],
        "item_id": response["item_id"],
    })


@app.route("/api/transactions", methods=["POST"])
def get_transactions():
    data = request.get_json()
    req = TransactionsSyncRequest(
        access_token=data["access_token"],
        cursor=data.get("cursor", ""),
    )
    response = client.transactions_sync(req)
    return jsonify({
        "added": [_tx_to_dict(tx) for tx in response["added"]],
        "modified": [_tx_to_dict(tx) for tx in response["modified"]],
        "removed": [{"transaction_id": tx["transaction_id"]} for tx in response["removed"]],
        "next_cursor": response["next_cursor"],
        "has_more": response["has_more"],
    })


@app.route("/api/balances", methods=["POST"])
def get_balances():
    data = request.get_json()
    req = AccountsBalanceGetRequest(access_token=data["access_token"])
    response = client.accounts_balance_get(req)
    accounts = []
    for acct in response["accounts"]:
        accounts.append({
            "account_id": acct["account_id"],
            "name": acct["name"],
            "official_name": acct.get("official_name"),
            "type": acct["type"],
            "subtype": acct.get("subtype"),
            "balances": {
                "current": acct["balances"].get("current"),
                "available": acct["balances"].get("available"),
            },
        })
    return jsonify({"accounts": accounts})


# ═══════════════════════════════════════
# EMAIL ALERT ENDPOINTS
# ═══════════════════════════════════════

@app.route("/api/send_alert", methods=["POST"])
def send_alert():
    """
    Send a budget alert email.
    Called by the iOS app when a budget threshold is triggered.
    
    Body:
    {
        "alert_type": "over_budget" | "pace_warning" | "pace_alert" | "contribution_hit",
        "category": "Dining",
        "spent": 162.50,
        "limit": 150.00,
        "projected": 310.00,        (for pace alerts)
        "safe_daily_rate": 5.30,     (for pace alerts)
        "days_remaining": 19,        (for pace alerts)
        "contribution_total": 3500,  (for contribution alerts)
        "contribution_target": 3500  (for contribution alerts)
    }
    """
    if not sg:
        return jsonify({"error": "SendGrid not configured"}), 500

    data = request.get_json()
    alert_type = data.get("alert_type")

    subject, html = _build_alert_email(data)

    message = Mail(
        from_email=FROM_EMAIL,
        to_emails=ALERT_EMAIL,
        subject=subject,
        html_content=HtmlContent(html),
    )

    try:
        sg.send(message)
        return jsonify({"sent": True})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/send_monthly_report", methods=["POST"])
def send_monthly_report():
    """
    Send end-of-month summary report email.
    Called by the iOS app on the 1st of each month (or via scheduler).
    
    Body:
    {
        "month": 7,
        "year": 2026,
        "categories": [
            {"name": "Groceries", "spent": 287, "limit": 300},
            {"name": "Dining", "spent": 162, "limit": 150},
            ...
        ],
        "total_spent": 1850,
        "total_budget": 1950,
        "contributions": {
            "tsp": 400,
            "k401": 650,
            "roth": 583,
            "other": 0,
            "total": 1633,
            "target": 3500
        },
        "income": 4200,
        "top_merchants": [
            {"name": "Walmart", "amount": 245, "count": 8},
            {"name": "Shell", "amount": 120, "count": 6},
            ...
        ]
    }
    """
    if not sg:
        return jsonify({"error": "SendGrid not configured"}), 500

    data = request.get_json()
    subject, html = _build_monthly_report(data)

    message = Mail(
        from_email=FROM_EMAIL,
        to_emails=ALERT_EMAIL,
        subject=subject,
        html_content=HtmlContent(html),
    )

    try:
        sg.send(message)
        return jsonify({"sent": True})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


# ═══════════════════════════════════════
# EMAIL BUILDERS
# ═══════════════════════════════════════

def _build_alert_email(data):
    alert_type = data.get("alert_type", "")
    category = data.get("category", "")
    spent = data.get("spent", 0)
    limit = data.get("limit", 0)

    if alert_type == "over_budget":
        over = spent - limit
        subject = f"PinkBudget: {category} Over Budget"
        body = f"""
        <h2 style="color:#EF4444;">Over Budget: {category}</h2>
        <p>You've spent <strong>${spent:,.2f}</strong> on {category} this month.</p>
        <p>That's <strong style="color:#EF4444;">${over:,.2f} over</strong> your ${limit:,.2f} limit.</p>
        """

    elif alert_type == "budget_warning":
        remaining = limit - spent
        pct = int((spent / limit) * 100) if limit > 0 else 0
        subject = f"PinkBudget: {category} at {pct}%"
        body = f"""
        <h2 style="color:#F59E0B;">Almost at Limit: {category}</h2>
        <p>You've used <strong>{pct}%</strong> of your {category} budget.</p>
        <p><strong>${remaining:,.2f}</strong> remaining out of ${limit:,.2f}.</p>
        """

    elif alert_type == "pace_alert":
        projected = data.get("projected", 0)
        over = projected - limit
        safe_rate = data.get("safe_daily_rate", 0)
        days_left = data.get("days_remaining", 0)
        subject = f"PinkBudget: {category} On Pace to Overspend"
        body = f"""
        <h2 style="color:#E91E8C;">Spending Pace: {category}</h2>
        <p>At your current pace, you'll spend <strong>~${projected:,.2f}</strong> on {category} this month.</p>
        <p>That's <strong style="color:#EF4444;">${over:,.2f} over</strong> your ${limit:,.2f} limit.</p>
        <p style="color:#6B7280;">To stay on budget, keep {category} spending under
        <strong>${safe_rate:,.2f}/day</strong> for the next {days_left} days.</p>
        """

    elif alert_type == "pace_warning":
        remaining = limit - spent
        safe_rate = data.get("safe_daily_rate", 0)
        days_left = data.get("days_remaining", 0)
        subject = f"PinkBudget: {category} Getting Tight"
        body = f"""
        <h2 style="color:#F59E0B;">Getting Tight: {category}</h2>
        <p>You have <strong>${remaining:,.2f}</strong> left in {category}
        for the next {days_left} days.</p>
        <p>That's <strong>${safe_rate:,.2f}/day</strong> to stay on track.</p>
        """

    elif alert_type == "contribution_hit":
        total = data.get("contribution_total", 0)
        target = data.get("contribution_target", 0)
        subject = "PinkBudget: Retirement Target Hit!"
        body = f"""
        <h2 style="color:#10B981;">Target Hit!</h2>
        <p>You've contributed <strong>${total:,.2f}</strong> to retirement this month,
        hitting your <strong>${target:,.2f}</strong> target.</p>
        <p>Keep it up!</p>
        """

    else:
        subject = "PinkBudget Alert"
        body = f"<p>{json.dumps(data)}</p>"

    html = _wrap_email(body)
    return subject, html


def _build_monthly_report(data):
    month_names = [
        "", "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]
    month = data.get("month", 1)
    year = data.get("year", 2026)
    month_name = month_names[month]

    categories = data.get("categories", [])
    total_spent = data.get("total_spent", 0)
    total_budget = data.get("total_budget", 0)
    contributions = data.get("contributions", {})
    income = data.get("income", 0)
    top_merchants = data.get("top_merchants", [])

    # Sort categories: over budget first, then by % spent
    categories.sort(
        key=lambda c: c.get("spent", 0) / c.get("limit", 1) if c.get("limit", 0) > 0 else 0,
        reverse=True
    )

    over_count = sum(1 for c in categories if c.get("spent", 0) > c.get("limit", 0))
    under_budget = total_budget - total_spent

    # Contribution data
    c_total = contributions.get("total", 0)
    c_target = contributions.get("target", 3500)
    c_tsp = contributions.get("tsp", 0)
    c_k401 = contributions.get("k401", 0)
    c_roth = contributions.get("roth", 0)
    c_other = contributions.get("other", 0)
    c_hit = c_total >= c_target

    subject = f"PinkBudget: {month_name} {year} Report"

    # ── Build HTML ──
    body = f"""
    <h1 style="color:#E91E8C; margin-bottom:4px;">{month_name} {year}</h1>
    <p style="color:#6B7280; margin-top:0;">Monthly Financial Report</p>

    <!-- BUDGET SUMMARY -->
    <div style="background:#FFF5F9; border-radius:12px; padding:20px; margin:20px 0;">
        <h2 style="color:#1F1F1F; margin-top:0;">Budget Summary</h2>
        <table style="width:100%; border-collapse:collapse;">
            <tr>
                <td style="padding:8px 0; color:#6B7280;">Total Spent</td>
                <td style="padding:8px 0; text-align:right; font-weight:bold; font-family:monospace;">
                    ${total_spent:,.2f}
                </td>
            </tr>
            <tr>
                <td style="padding:8px 0; color:#6B7280;">Total Budget</td>
                <td style="padding:8px 0; text-align:right; font-family:monospace;">
                    ${total_budget:,.2f}
                </td>
            </tr>
            <tr style="border-top:1px solid #F3E8F0;">
                <td style="padding:8px 0; font-weight:bold;">
                    {"Under Budget" if under_budget >= 0 else "Over Budget"}
                </td>
                <td style="padding:8px 0; text-align:right; font-weight:bold; font-family:monospace;
                    color:{"#10B981" if under_budget >= 0 else "#EF4444"};">
                    ${abs(under_budget):,.2f}
                </td>
            </tr>
        </table>
        {f'<p style="color:#EF4444; font-weight:bold;">{over_count} categories over budget</p>' if over_count > 0 else '<p style="color:#10B981;">All categories on track!</p>'}
    </div>

    <!-- CATEGORY BREAKDOWN -->
    <h2 style="color:#1F1F1F;">By Category</h2>
    <table style="width:100%; border-collapse:collapse;">
        <tr style="border-bottom:2px solid #E91E8C;">
            <th style="text-align:left; padding:8px; color:#6B7280; font-size:12px;">CATEGORY</th>
            <th style="text-align:right; padding:8px; color:#6B7280; font-size:12px;">SPENT</th>
            <th style="text-align:right; padding:8px; color:#6B7280; font-size:12px;">LIMIT</th>
            <th style="text-align:right; padding:8px; color:#6B7280; font-size:12px;">STATUS</th>
        </tr>
    """

    for cat in categories:
        spent = cat.get("spent", 0)
        limit = cat.get("limit", 0)
        is_over = spent > limit
        pct = int((spent / limit) * 100) if limit > 0 else 0

        status_color = "#EF4444" if is_over else "#10B981" if pct < 85 else "#F59E0B"
        status_text = f"${spent - limit:,.0f} over" if is_over else f"${limit - spent:,.0f} left"

        # Progress bar
        bar_width = min(pct, 100)
        bar_color = "#EF4444" if is_over else "#E91E8C"

        body += f"""
        <tr style="border-bottom:1px solid #F3E8F0;">
            <td style="padding:10px 8px;">
                <strong>{cat.get("name", "")}</strong>
                <div style="background:#FCE4F2; border-radius:3px; height:4px; margin-top:4px; width:100%;">
                    <div style="background:{bar_color}; border-radius:3px; height:4px; width:{bar_width}%;"></div>
                </div>
            </td>
            <td style="text-align:right; padding:8px; font-family:monospace;">${spent:,.2f}</td>
            <td style="text-align:right; padding:8px; font-family:monospace; color:#9CA3AF;">${limit:,.2f}</td>
            <td style="text-align:right; padding:8px; color:{status_color}; font-size:13px;">{status_text}</td>
        </tr>
        """

    body += "</table>"

    # ── RETIREMENT CONTRIBUTIONS ──
    body += f"""
    <div style="background:{"#ECFDF5" if c_hit else "#FFF5F9"}; border-radius:12px; padding:20px; margin:20px 0;">
        <h2 style="color:#1F1F1F; margin-top:0;">
            Retirement Contributions
            {"&#10003;" if c_hit else ""}
        </h2>
        <p style="font-size:28px; font-weight:bold; font-family:monospace; color:{"#10B981" if c_hit else "#E91E8C"}; margin:8px 0;">
            ${c_total:,.2f} <span style="font-size:16px; color:#9CA3AF;">/ ${c_target:,.2f}</span>
        </p>
        <table style="width:100%; border-collapse:collapse; margin-top:12px;">
            <tr>
                <td style="padding:4px 0;">
                    <span style="display:inline-block; width:8px; height:8px; border-radius:4px; background:#E91E8C; margin-right:8px;"></span>
                    TSP
                </td>
                <td style="text-align:right; font-family:monospace;">${c_tsp:,.2f}</td>
            </tr>
            <tr>
                <td style="padding:4px 0;">
                    <span style="display:inline-block; width:8px; height:8px; border-radius:4px; background:#8B5CF6; margin-right:8px;"></span>
                    401(k)
                </td>
                <td style="text-align:right; font-family:monospace;">${c_k401:,.2f}</td>
            </tr>
            <tr>
                <td style="padding:4px 0;">
                    <span style="display:inline-block; width:8px; height:8px; border-radius:4px; background:#06B6D4; margin-right:8px;"></span>
                    Roth IRA
                </td>
                <td style="text-align:right; font-family:monospace;">${c_roth:,.2f}</td>
            </tr>
    """

    if c_other > 0:
        body += f"""
            <tr>
                <td style="padding:4px 0;">
                    <span style="display:inline-block; width:8px; height:8px; border-radius:4px; background:#F59E0B; margin-right:8px;"></span>
                    Other
                </td>
                <td style="text-align:right; font-family:monospace;">${c_other:,.2f}</td>
            </tr>
        """

    body += """
        </table>
    </div>
    """

    # ── TOP MERCHANTS ──
    if top_merchants:
        body += """
        <h2 style="color:#1F1F1F;">Top Merchants</h2>
        <table style="width:100%; border-collapse:collapse;">
        """
        for i, m in enumerate(top_merchants[:8]):
            body += f"""
            <tr style="border-bottom:1px solid #F3E8F0;">
                <td style="padding:8px; color:#6B7280; width:20px;">{i + 1}.</td>
                <td style="padding:8px;">{m.get("name", "Unknown")}</td>
                <td style="text-align:right; padding:8px; font-family:monospace;">${m.get("amount", 0):,.2f}</td>
                <td style="text-align:right; padding:8px; color:#9CA3AF; font-size:12px;">{m.get("count", 0)} txns</td>
            </tr>
            """
        body += "</table>"

    # ── CASH FLOW ──
    savings_rate = ((income - total_spent) / income * 100) if income > 0 else 0
    body += f"""
    <div style="background:#F0F9FF; border-radius:12px; padding:20px; margin:20px 0;">
        <h2 style="color:#1F1F1F; margin-top:0;">Cash Flow</h2>
        <table style="width:100%; border-collapse:collapse;">
            <tr>
                <td style="padding:6px 0; color:#6B7280;">Income</td>
                <td style="text-align:right; font-family:monospace; color:#10B981;">${income:,.2f}</td>
            </tr>
            <tr>
                <td style="padding:6px 0; color:#6B7280;">Spending</td>
                <td style="text-align:right; font-family:monospace; color:#EF4444;">-${total_spent:,.2f}</td>
            </tr>
            <tr>
                <td style="padding:6px 0; color:#6B7280;">Retirement</td>
                <td style="text-align:right; font-family:monospace; color:#6366F1;">-${c_total:,.2f}</td>
            </tr>
            <tr style="border-top:1px solid #E0E7FF;">
                <td style="padding:6px 0; font-weight:bold;">Savings Rate</td>
                <td style="text-align:right; font-weight:bold; color:#E91E8C;">{savings_rate:.1f}%</td>
            </tr>
        </table>
    </div>
    """

    html = _wrap_email(body)
    return subject, html


def _wrap_email(body_content):
    return f"""
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
    </head>
    <body style="margin:0; padding:0; background:#FFF5F9; font-family:-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;">
        <div style="max-width:600px; margin:0 auto; padding:24px; background:#FFFFFF;">
            {body_content}
            <hr style="border:none; border-top:1px solid #F3E8F0; margin:24px 0;">
            <p style="color:#9CA3AF; font-size:12px; text-align:center;">
                PinkBudget &middot; Sent automatically
            </p>
        </div>
    </body>
    </html>
    """


def _tx_to_dict(tx):
    result = {
        "transaction_id": tx["transaction_id"],
        "account_id": tx["account_id"],
        "amount": tx["amount"],
        "date": str(tx["date"]),
        "name": tx["name"],
        "merchant_name": tx.get("merchant_name"),
        "pending": tx["pending"],
    }
    if tx.get("personal_finance_category"):
        result["personal_finance_category"] = {
            "primary": tx["personal_finance_category"]["primary"],
            "detailed": tx["personal_finance_category"]["detailed"],
        }
    return result


if __name__ == "__main__":
    port = int(os.getenv("PORT", 5000))
    app.run(host="0.0.0.0", port=port, debug=True)
# ═══════════════════════════════════════
# ADD THESE ENDPOINTS TO server.py
# ═══════════════════════════════════════

@app.route("/api/send_weekly_report", methods=["POST"])
def send_weekly_report():
    """
    Weekly spending check-in email.
    Sent every Sunday evening with the week's spending
    and how close each category is to its monthly limit.
    """
    if not sg:
        return jsonify({"error": "SendGrid not configured"}), 500

    data = request.get_json()
    subject, html = _build_weekly_report(data)

    message = Mail(
        from_email=FROM_EMAIL,
        to_emails=ALERT_EMAIL,
        subject=subject,
        html_content=HtmlContent(html),
    )

    try:
        sg.send(message)
        return jsonify({"sent": True})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


def _build_weekly_report(data):
    """
    Expected data:
    {
        "week_number": 3,
        "month": "July",
        "year": 2026,
        "days_left": 10,
        "categories": [
            {
                "name": "Groceries",
                "spent": 187,
                "limit": 275,
                "week_spent": 62,
                "projected": 290,
                "safe_daily": 8.80
            }, ...
        ],
        "total_spent": 2100,
        "total_budget": 3950,
        "contributions": {
            "total": 1200,
            "target": 2000,
            "tsp": 0,
            "k401": 0,
            "roth": 583,
            "other": 617,
            "note": "TSP and 401(k) are pre-paycheck"
        }
    }
    """
    month = data.get("month", "")
    year = data.get("year", 2026)
    week = data.get("week_number", 1)
    days_left = data.get("days_left", 0)
    categories = data.get("categories", [])
    total_spent = data.get("total_spent", 0)
    total_budget = data.get("total_budget", 3950)
    contributions = data.get("contributions", {})

    remaining_budget = total_budget - total_spent
    pct_spent = (total_spent / total_budget * 100) if total_budget > 0 else 0

    # Sort categories by % used (highest first)
    categories.sort(key=lambda c: c.get("spent", 0) / c.get("limit", 1) if c.get("limit", 0) > 0 else 0, reverse=True)

    # Count warnings
    over_count = sum(1 for c in categories if c.get("spent", 0) > c.get("limit", 0))
    tight_count = sum(1 for c in categories if 0.85 <= (c.get("spent", 0) / c.get("limit", 1) if c.get("limit", 0) > 0 else 0) < 1.0)
    on_pace_over = sum(1 for c in categories if c.get("projected", 0) > c.get("limit", 0) and c.get("spent", 0) <= c.get("limit", 0))

    # Contribution data
    c_total = contributions.get("total", 0)
    c_target = contributions.get("target", 2000)
    c_pct = (c_total / c_target * 100) if c_target > 0 else 0

    subject = f"PinkBudget: Week {week} of {month} - ${total_spent:,.0f} of ${total_budget:,.0f} spent"

    # Build status emoji
    if pct_spent > 100:
        budget_status = "Over Budget"
        budget_color = "#EF4444"
    elif pct_spent > 85:
        budget_status = "Getting Tight"
        budget_color = "#F59E0B"
    else:
        budget_status = "On Track"
        budget_color = "#10B981"

    body = f"""
    <h1 style="color:#E91E8C; margin-bottom:4px;">Week {week} Check-In</h1>
    <p style="color:#6B7280; margin-top:0;">{month} {year} &middot; {days_left} days left</p>

    <!-- OVERALL STATUS -->
    <div style="background:#FFF5F9; border-radius:12px; padding:20px; margin:16px 0; text-align:center;">
        <p style="font-size:36px; font-weight:bold; font-family:monospace; color:#E91E8C; margin:0;">
            ${total_spent:,.0f} <span style="font-size:18px; color:#9CA3AF;">/ ${total_budget:,.0f}</span>
        </p>
        <p style="color:{budget_color}; font-weight:bold; margin:8px 0 0 0;">{budget_status}</p>
        <p style="color:#6B7280; font-size:13px; margin:4px 0 0 0;">
            ${remaining_budget:,.0f} remaining &middot; ${remaining_budget/days_left if days_left > 0 else 0:,.0f}/day to stay on budget
        </p>

        <!-- Progress bar -->
        <div style="background:#FCE4F2; border-radius:6px; height:12px; margin:12px 0 0 0; width:100%;">
            <div style="background:{budget_color}; border-radius:6px; height:12px; width:{min(pct_spent, 100):.0f}%;"></div>
        </div>
    </div>
    """

    # Alerts summary
    if over_count > 0 or tight_count > 0 or on_pace_over > 0:
        body += '<div style="background:#FEF2F2; border-left:4px solid #EF4444; padding:12px; margin:12px 0; border-radius:0 8px 8px 0;">'
        alerts = []
        if over_count > 0:
            alerts.append(f"<strong>{over_count} {'category' if over_count == 1 else 'categories'} over budget</strong>")
        if on_pace_over > 0:
            alerts.append(f"{on_pace_over} on pace to overspend")
        if tight_count > 0:
            alerts.append(f"{tight_count} getting tight")
        body += " &middot; ".join(alerts)
        body += '</div>'

    # Category breakdown
    body += """
    <h2 style="color:#1F1F1F; margin-top:24px;">By Category</h2>
    <table style="width:100%; border-collapse:collapse;">
        <tr style="border-bottom:2px solid #E91E8C;">
            <th style="text-align:left; padding:8px; color:#6B7280; font-size:11px;">CATEGORY</th>
            <th style="text-align:right; padding:8px; color:#6B7280; font-size:11px;">SPENT</th>
            <th style="text-align:right; padding:8px; color:#6B7280; font-size:11px;">LIMIT</th>
            <th style="text-align:right; padding:8px; color:#6B7280; font-size:11px;">THIS WEEK</th>
            <th style="text-align:right; padding:8px; color:#6B7280; font-size:11px;">LEFT</th>
        </tr>
    """

    for cat in categories:
        spent = cat.get("spent", 0)
        limit = cat.get("limit", 0)
        week_spent = cat.get("week_spent", 0)
        projected = cat.get("projected", 0)
        safe_daily = cat.get("safe_daily", 0)
        is_over = spent > limit
        pct = (spent / limit * 100) if limit > 0 else 0
        remaining = limit - spent

        # Status indicator
        if is_over:
            status_color = "#EF4444"
            status_icon = "&#10060;"
            left_text = f"${abs(remaining):,.0f} over"
        elif projected > limit and not is_over:
            status_color = "#F59E0B"
            status_icon = "&#9888;"
            left_text = f"${remaining:,.0f} (${safe_daily:,.0f}/day)"
        elif pct >= 85:
            status_color = "#F59E0B"
            status_icon = "&#9888;"
            left_text = f"${remaining:,.0f}"
        else:
            status_color = "#10B981"
            status_icon = "&#10004;"
            left_text = f"${remaining:,.0f}"

        bar_width = min(pct, 100)
        bar_color = "#EF4444" if is_over else "#F59E0B" if pct >= 85 else "#E91E8C"

        body += f"""
        <tr style="border-bottom:1px solid #F3E8F0;">
            <td style="padding:10px 8px;">
                {status_icon} <strong>{cat.get("name", "")}</strong>
                <div style="background:#FCE4F2; border-radius:3px; height:4px; margin-top:4px; width:100%;">
                    <div style="background:{bar_color}; border-radius:3px; height:4px; width:{bar_width}%;"></div>
                </div>
            </td>
            <td style="text-align:right; padding:8px; font-family:monospace; font-size:13px;">${spent:,.0f}</td>
            <td style="text-align:right; padding:8px; font-family:monospace; font-size:13px; color:#9CA3AF;">${limit:,.0f}</td>
            <td style="text-align:right; padding:8px; font-family:monospace; font-size:13px; color:#6B7280;">${week_spent:,.0f}</td>
            <td style="text-align:right; padding:8px; font-size:12px; color:{status_color};">{left_text}</td>
        </tr>
        """

    body += "</table>"

    # Retirement section with PACE tracking
    c_roth = contributions.get("roth", 0)
    c_other = contributions.get("other", 0)
    c_hit = c_total >= c_target

    # Pace calculation
    days_in_month = days_left + (31 - days_left)  # approximate
    days_elapsed = days_in_month - days_left if days_left else days_in_month
    month_pct = days_elapsed / days_in_month if days_in_month > 0 else 1
    c_expected_by_now = c_target * month_pct
    c_on_pace = c_total >= c_expected_by_now
    c_behind_amt = c_expected_by_now - c_total if not c_on_pace else 0
    c_ahead_amt = c_total - c_expected_by_now if c_on_pace else 0

    if c_hit:
        pace_color = "#10B981"
        pace_status = "Target hit!"
        pace_detail = f"You've already reached your ${c_target:,.0f} goal for the month."
    elif c_on_pace:
        pace_color = "#10B981"
        pace_status = "On Pace"
        pace_detail = f"${c_ahead_amt:,.0f} ahead of where you need to be. Expected ${c_expected_by_now:,.0f} by day {days_elapsed}, you have ${c_total:,.0f}."
    else:
        pace_color = "#F59E0B"
        pace_status = "Behind Pace"
        pace_detail = f"${c_behind_amt:,.0f} behind. Expected ${c_expected_by_now:,.0f} by day {days_elapsed}, you have ${c_total:,.0f}. Need ${c_target - c_total:,.0f} more in {days_left} days."

    body += f"""
    <div style="background:{"#ECFDF5" if c_hit else "#FFF5F9"}; border-radius:12px; padding:20px; margin:20px 0;">
        <h2 style="color:#1F1F1F; margin-top:0;">
            Retirement Goal
        </h2>
        <p style="font-size:28px; font-weight:bold; font-family:monospace; color:{"#10B981" if c_hit else "#E91E8C"}; margin:4px 0;">
            ${c_total:,.0f} <span style="font-size:16px; color:#9CA3AF;">/ ${c_target:,.0f}</span>
        </p>
        <div style="background:#FCE4F2; border-radius:6px; height:10px; margin:8px 0; width:100%;">
            <div style="background:{"#10B981" if c_hit or c_on_pace else "#F59E0B"}; border-radius:6px; height:10px; width:{min(c_pct, 100):.0f}%;"></div>
        </div>
        <p style="color:{pace_color}; font-weight:bold; font-size:14px; margin:8px 0;">
            {pace_status}
        </p>
        <p style="color:#6B7280; font-size:13px; margin:4px 0;">
            {pace_detail}
        </p>
        <p style="color:#9CA3AF; font-size:12px; margin:8px 0 0 0;">
            TSP &amp; 401(k) already deducted from paycheck
        </p>
        <table style="width:100%; margin-top:8px;">
            <tr>
                <td style="color:#6B7280; font-size:13px;">Roth IRA</td>
                <td style="text-align:right; font-family:monospace; font-size:13px;">${c_roth:,.0f}</td>
            </tr>
            <tr>
                <td style="color:#6B7280; font-size:13px;">Other (brokerage)</td>
                <td style="text-align:right; font-family:monospace; font-size:13px;">${c_other:,.0f}</td>
            </tr>
        </table>
    </div>
    """

    # Quick tips based on what's happening
    body += '<div style="background:#F0F9FF; border-radius:12px; padding:16px; margin:16px 0;">'
    body += '<p style="font-weight:bold; color:#1F1F1F; margin:0 0 8px 0;">This Week:</p>'

    tips = []
    for cat in categories:
        if cat.get("spent", 0) > cat.get("limit", 0):
            tips.append(f"<strong>{cat['name']}</strong> is over. No more spending here this month.")
        elif cat.get("projected", 0) > cat.get("limit", 0) and cat.get("spent", 0) <= cat.get("limit", 0):
            safe = cat.get("safe_daily", 0)
            tips.append(f"<strong>{cat['name']}</strong> is trending over. Keep it under ${safe:,.0f}/day.")

    if not tips:
        tips.append("All categories on track. Keep it up!")

    for tip in tips[:4]:
        body += f'<p style="color:#6B7280; font-size:13px; margin:4px 0;">&bull; {tip}</p>'

    body += '</div>'

    html = _wrap_email(body)
    return subject, html
