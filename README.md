# ADP Bank Demo

Conference demo showcasing Redpanda's Agentic Data Plane (ADP) — an internal bank employee tool that lets staff look up customers, check account balances, and investigate overdrafts using natural language.

## What's in this repo

| File | Description |
|---|---|
| `2026-04-01-bank-demo-mcp-design.md` | Full design spec — MCP server tools, data model, architecture, implementation steps |
| `bank-demo-seed.sql` | Postgres schema DDL + mock seed data (10 customers, ~30 days of transactions) |
| `restore/` | Shell scripts to recreate all Redpanda Cloud objects if the cluster is wiped |

## Architecture

```
ADP Agent (Claude)
    │  natural language
    ▼
"Bank Internal Assistant" AI Agent
    │  MCP over HTTPS
    ▼
"Bank Internal" MCP Server  (Redpanda Cloud, adp-production)
    │  sql_raw processors
    ▼
AWS RDS Postgres  (us-east-2, db: bank_demo)
    │
    ▼
Mock seed data (bank-demo-seed.sql)
```

## MCP Tools

| Tool | Purpose |
|---|---|
| `get_customer` | Look up a customer by name (partial match) — returns customer details + account IDs |
| `get_account_balance` | Get balance and overdraft status for an account (`healthy` / `low` / `overdrawn` / `overdraft_exceeded`) |
| `get_recent_transactions` | Get recent transactions for an account, sorted newest first |

## Demo Queries

1. *"Look up customer Alice Johnson and show me her accounts."*
2. *"What is the balance on account 3? Is it overdrawn?"*
3. *"Show me the last 5 transactions on account 7."*
4. *"Which of Sarah Miller's accounts are in overdraft?"*
5. *"Why is Bob Martinez overdrawn? Walk me through his recent activity."*

## Infrastructure

- **Cluster:** `adp-production` (BYOC, AWS us-east-2) — cluster ID `d6kjl4h19241bg3ek3h0`
- **MCP Server ID:** `d76lq0o5s2pc73bj5ua0`
- **AI Agent ID:** `d76o3ig5s2pc73bj5uag`
- **RDS endpoint:** `joshb-adp-demo.c3uaqo244uj7.us-east-2.rds.amazonaws.com`
- **Redpanda secret:** `BANK_DEMO_DSN` (scopes: `SCOPE_REDPANDA_CONNECT`, `SCOPE_MCP_SERVER`)

## Re-creating from scratch

If starting fresh, first spin up RDS:

1. Spin up RDS Postgres `db.t3.micro` in `us-east-2`, database `bank_demo`
2. Enable "Publicly accessible" and add an inbound TCP 5432 rule for the Redpanda NAT gateway `3.138.236.26`

Then run the restore scripts in order (requires `rpk` CLI authenticated via `rpk cloud login`):

```bash
cd restore/

RDS_HOST=<your-rds-endpoint> RDS_PASS=<your-password> ./01-seed-database.sh
RDS_HOST=<your-rds-endpoint> RDS_PASS=<your-password> ./02-create-secret.sh
./03-create-mcp-server.sh   # prints new MCP_SERVER_ID
./04-create-service-account.sh  # prints new SERVICE_ACCOUNT_SECRET
MCP_SERVER_ID=<id-from-step-3> SERVICE_ACCOUNT_SECRET=<secret-from-step-4> ./05-create-agent.sh
```

See `restore/README.md` for full details. No tokens or secrets are hardcoded — all credentials are passed as environment variables or fetched at runtime via `rpk`.
