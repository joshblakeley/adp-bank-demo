# Bank Internal Demo — MCP Server Design

**Date:** 2026-04-01
**Status:** Approved
**Goal:** Conference demo showcasing an ADP agent acting as an internal bank employee tool — looking up customers, checking account balances, and surfacing overdraft status with recent transaction context.

---

## Context

The `adp-production` Redpanda Cloud cluster (BYOC, AWS us-east-2) already hosts several MCP servers (Alpaca trading, Perplexity search, a manufacturing Postgres server). This demo adds a new "Bank Internal" MCP server backed by a mock financial database on AWS RDS.

---

## Data Model

**Hosted on:** AWS RDS Postgres, us-east-2 (same region as cluster).
**Database name:** `bank_demo`
**Master username:** `bank_admin` (password stored in Redpanda secret `BANK_DEMO_DSN`)
**RDS security group:** must allow inbound TCP 5432 from Redpanda NAT gateway `3.138.236.26`.
**Instance size:** `db.t3.micro` is sufficient for demo load.

```sql
CREATE TABLE customers (
  id        SERIAL PRIMARY KEY,
  name      TEXT NOT NULL,
  email     TEXT,
  phone     TEXT
);

CREATE TABLE accounts (
  id              SERIAL PRIMARY KEY,
  customer_id     INTEGER REFERENCES customers(id),
  type            TEXT NOT NULL,         -- 'checking' | 'savings'
  balance         NUMERIC(12,2) NOT NULL,
  overdraft_limit NUMERIC(12,2) DEFAULT 0
);

CREATE TABLE transactions (
  id          SERIAL PRIMARY KEY,
  account_id  INTEGER REFERENCES accounts(id),
  amount      NUMERIC(12,2) NOT NULL,   -- negative = debit
  description TEXT,
  ts          TIMESTAMPTZ NOT NULL
);
```

**Seed data:** ~10 realistic mock customers, each with 1-2 accounts (checking and/or savings), ~30 days of transactions per account. Several accounts intentionally overdrawn to give the agent interesting scenarios:
- At least 2 accounts with balance < 0 but within overdraft limit
- At least 1 account with balance below overdraft limit (`overdraft_exceeded`)

The seed script lives in `docs/superpowers/specs/bank-demo-seed.sql` in this repo.

---

## Redpanda Secret

Create secret `BANK_DEMO_DSN` on `adp-production` with value:
```
postgres://bank_admin:<password>@<rds-endpoint>:5432/bank_demo
```

---

## MCP Server: "Bank Internal"

**Cluster:** `adp-production`
**Dataplane URL:** `https://api-8a6dfc25.d6kjl4h19241bg3ek3h0.byoc.prd.cloud.redpanda.com`
**Resources:** `memory_shares: 400M`, `cpu_shares: 100m`

All three tools use `sql_raw` with `unsafe_dynamic_query: false` — all parameterization uses positional args (`$1`, `$2`) so dynamic query mode is not needed and SQL injection protections remain active.

---

### Tool 1: `get_customer`

**Purpose:** Entry point — employee looks up a customer by name.
**Processor:** single `sql_raw` with a JOIN to return account IDs in one call.

**Inputs:**
- `name` (string, required) — partial match, case-insensitive

**Returns:** customer id, name, email, phone, array of account IDs

**Config YAML:**
```yaml
label: get_customer
sql_raw:
  driver: "postgres"
  dsn: "${secrets.BANK_DEMO_DSN}"
  unsafe_dynamic_query: false
  query: |
    SELECT c.id, c.name, c.email, c.phone,
           array_remove(array_agg(a.id ORDER BY a.id), NULL) AS account_ids
    FROM customers c
    LEFT JOIN accounts a ON a.customer_id = c.id
    WHERE c.name ILIKE $1
    GROUP BY c.id
    ORDER BY c.name
  args_mapping: 'root = ["%"+this.name+"%"]'
meta:
  mcp:
    enabled: true
    description: |
      Look up a bank customer by name (partial match supported).
      Returns customer details and their list of account IDs.
    properties:
      - name: name
        type: string
        description: Full or partial customer name to search for (e.g. "jane" or "jane smith")
        required: true
```

---

### Tool 2: `get_account_balance`

**Purpose:** Check balance and overdraft status for a specific account.
**Processors:** two-step — `sql_raw` to fetch the row, then `mutation` to compute `status`.

**Inputs:**
- `account_id` (integer, required)

**Returns:** account type, balance, overdraft_limit, computed `status`

**Status thresholds:**
| Status | Condition |
|---|---|
| `healthy` | balance > 0 |
| `low` | balance >= 0 AND balance < 100 |
| `overdrawn` | balance < 0 AND balance >= -overdraft_limit |
| `overdraft_exceeded` | balance < -overdraft_limit |

**Config YAML:**
```yaml
label: get_account_balance
processors:
  - sql_raw:
      driver: "postgres"
      dsn: "${secrets.BANK_DEMO_DSN}"
      unsafe_dynamic_query: false
      query: |
        SELECT id, type, balance, overdraft_limit
        FROM accounts
        WHERE id = $1
      args_mapping: "root = [this.account_id]"
  - mutation: |
      root = if this.length() == 0 {
        throw("account not found: %v".format(this))
      } else {
        this.index(0)
      }
  - mutation: |
      let bal = this.balance
      let lim = this.overdraft_limit
      root = this
      root.status = if $bal < 0 && $bal >= -$lim { "overdrawn" }
                    else if $bal < -$lim { "overdraft_exceeded" }
                    else if $bal >= 0 && $bal < 100 { "low" }
                    else { "healthy" }
meta:
  mcp:
    enabled: true
    description: |
      Get the current balance and overdraft status for a bank account.
      Status values: healthy (>$0), low ($0-$99), overdrawn (negative but within limit), overdraft_exceeded (below limit).
    properties:
      - name: account_id
        type: integer
        description: The account ID to check (obtained from get_customer)
        required: true
```

---

### Tool 3: `get_recent_transactions`

**Purpose:** Show recent activity — used to explain why an account is overdrawn.
**Processor:** single `sql_raw`. `limit` is capped at 50 to prevent runaway responses.

**Inputs:**
- `account_id` (integer, required)
- `limit` (integer, optional, default 10, max 50)

**Returns:** list of transactions — amount, description, timestamp — sorted newest first

**Config YAML:**
```yaml
label: get_recent_transactions
sql_raw:
  driver: "postgres"
  dsn: "${secrets.BANK_DEMO_DSN}"
  unsafe_dynamic_query: false
  query: |
    SELECT amount, description, ts
    FROM transactions
    WHERE account_id = $1
    ORDER BY ts DESC
    LIMIT $2
  args_mapping: |
      let lim = if this.limit != null { this.limit } else { 10 }
      root = [this.account_id, if $lim > 50 { 50 } else if $lim < 1 { 1 } else { $lim }]
meta:
  mcp:
    enabled: true
    description: |
      Get recent transactions for a bank account, sorted newest first.
      Use this to understand why an account balance has changed or is overdrawn.
    properties:
      - name: account_id
        type: integer
        description: The account ID to retrieve transactions for
        required: true
      - name: limit
        type: integer
        description: Number of transactions to return (default 10, max 50)
        required: false
```

---

## Architecture

```
ADP Agent (Claude)
    │  MCP over HTTPS
    ▼
Redpanda MCP Server ("Bank Internal")
    │  adp-production cluster, us-east-2
    │  3 sql_raw processor tools
    │  secret: BANK_DEMO_DSN
    ▼
AWS RDS Postgres (us-east-2)
    database: bank_demo
    ▼
Mock seed data (docs/superpowers/specs/bank-demo-seed.sql)
```

---

## Typical Demo Agent Flow

**Prompt:** "Is Jane Smith overdrawn?"

1. `get_customer("jane smith")` → returns customer record + account IDs
2. `get_account_balance(account_id)` for each account → finds overdrawn account
3. `get_recent_transactions(account_id, limit=5)` → surfaces recent debits explaining the overdraft
4. Agent responds with natural language summary

---

## Test Queries (also serves as demo script)

1. "Look up customer Alice Johnson and show me her accounts."
2. "What is the balance on account 3? Is it overdrawn?"
3. "Show me the last 5 transactions on account 7."
4. "Which of Sarah Miller's accounts are in overdraft?"
5. "Why is account 2 overdrawn? Walk me through the recent activity."

---

## Implementation Steps

1. Spin up RDS Postgres `db.t3.micro` in `us-east-2`, database `bank_demo`, user `bank_admin`
2. Configure RDS security group to allow TCP 5432 from `3.138.236.26`
3. Run schema DDL and seed script (`docs/superpowers/specs/bank-demo-seed.sql`)
4. Create Redpanda secret `BANK_DEMO_DSN` on `adp-production` — **must exist before Step 5**
5. Create MCP server via Redpanda Cloud API with `display_name: "Bank Internal"` and the 3 tool YAMLs above
6. Start the MCP server and verify it reaches `STATE_RUNNING`
7. Retrieve the MCP server URL via `GetMCPServer` — format is `https://{server_id}.mcp-servers.d6kjl4h19241bg3ek3h0.clusters.rdpa.co/mcp`
8. Add MCP server URL to ADP agent configuration
9. Run the 5 test queries end-to-end

---

## Notes

- No changes required to the openmessaging-benchmark repo — all work is Redpanda Cloud API calls, SQL, and RDS setup
- `unsafe_dynamic_query: false` on all tools — positional args (`$1`, `$2`) are used throughout, so dynamic query mode is not needed
- Accounts with `overdraft_limit = 0` that go negative will show `overdraft_exceeded` (not `overdrawn`) — this is intentional; the seed data uses non-zero overdraft limits for the interesting demo scenarios
- Seed script is committed to this repo so the demo can be re-created from scratch if needed
