#!/usr/bin/env bash
# Create the "Bank Internal" MCP server with all three tools.
# Prints the new MCP server ID on success — update 05-create-agent.sh with it.

set -euo pipefail

DATAPLANE_URL="https://api-8a6dfc25.d6kjl4h19241bg3ek3h0.byoc.prd.cloud.redpanda.com"
TOKEN=$(rpk cloud auth print-token 2>/dev/null || rpk cloud login --print-token 2>/dev/null)

echo "Creating Bank Internal MCP server ..."

RESPONSE=$(curl -sf -X POST "${DATAPLANE_URL}/v1alpha3/mcp-servers" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d @- << 'PAYLOAD'
{
  "mcp_server": {
    "display_name": "Bank Internal",
    "description": "Internal bank employee tool for looking up customers, checking account balances, and reviewing recent transactions.",
    "tags": { "env": "demo", "owner": "josh" },
    "resources": { "memory_shares": "400M", "cpu_shares": "100m" },
    "tools": {
      "get_customer": {
        "component_type": "COMPONENT_TYPE_PROCESSOR",
        "config_yaml": "label: get_customer\nsql_raw:\n  driver: \"postgres\"\n  dsn: \"${secrets.BANK_DEMO_DSN}\"\n  unsafe_dynamic_query: false\n  query: |\n    SELECT c.id, c.name, c.email, c.phone,\n           array_remove(array_agg(a.id ORDER BY a.id), NULL) AS account_ids\n    FROM customers c\n    LEFT JOIN accounts a ON a.customer_id = c.id\n    WHERE c.name ILIKE $1\n    GROUP BY c.id\n    ORDER BY c.name\n  args_mapping: 'root = [\"%\"+this.name+\"%\"]'\nmeta:\n  mcp:\n    enabled: true\n    description: |\n      Look up a bank customer by name (partial match supported).\n      Returns customer details and their list of account IDs.\n    properties:\n      - name: name\n        type: string\n        description: Full or partial customer name to search for (e.g. \"jane\" or \"jane smith\")\n        required: true\n"
      },
      "get_account_balance": {
        "component_type": "COMPONENT_TYPE_PROCESSOR",
        "config_yaml": "label: get_account_balance\nprocessors:\n  - sql_raw:\n      driver: \"postgres\"\n      dsn: \"${secrets.BANK_DEMO_DSN}\"\n      unsafe_dynamic_query: false\n      query: |\n        SELECT id, type, balance::float8 AS balance, overdraft_limit::float8 AS overdraft_limit\n        FROM accounts\n        WHERE id = $1\n      args_mapping: \"root = [this.account_id]\"\n  - mutation: |\n      root = if this.length() == 0 {\n        throw(\"account not found: %v\".format(this))\n      } else {\n        this.index(0)\n      }\n  - mutation: |\n      let bal = this.balance\n      let lim = this.overdraft_limit\n      root = this\n      root.status = if $bal < 0 && $bal >= -$lim { \"overdrawn\" }\n                    else if $bal < -$lim { \"overdraft_exceeded\" }\n                    else if $bal >= 0 && $bal < 100 { \"low\" }\n                    else { \"healthy\" }\nmeta:\n  mcp:\n    enabled: true\n    description: |\n      Get the current balance and overdraft status for a bank account.\n      Status values: healthy (balance>$0), low ($0-$99), overdrawn (negative but within limit), overdraft_exceeded (below limit).\n    properties:\n      - name: account_id\n        type: integer\n        description: The account ID to check (obtained from get_customer)\n        required: true\n"
      },
      "get_recent_transactions": {
        "component_type": "COMPONENT_TYPE_PROCESSOR",
        "config_yaml": "label: get_recent_transactions\nsql_raw:\n  driver: \"postgres\"\n  dsn: \"${secrets.BANK_DEMO_DSN}\"\n  unsafe_dynamic_query: false\n  query: |\n    SELECT amount::float8 AS amount, description, ts\n    FROM transactions\n    WHERE account_id = $1\n    ORDER BY ts DESC\n    LIMIT $2\n  args_mapping: |\n    let lim = if this.limit != null { this.limit } else { 10 }\n    root = [this.account_id, if $lim > 50 { 50 } else if $lim < 1 { 1 } else { $lim }]\nmeta:\n  mcp:\n    enabled: true\n    description: |\n      Get recent transactions for a bank account, sorted newest first.\n      Use this to understand why an account balance has changed or is overdrawn.\n    properties:\n      - name: account_id\n        type: integer\n        description: The account ID to retrieve transactions for\n        required: true\n      - name: limit\n        type: integer\n        description: Number of transactions to return (default 10, max 50)\n        required: false\n"
      }
    }
  }
}
PAYLOAD
)

MCP_ID=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['mcp_server']['id'])")
echo ""
echo "MCP server created: $MCP_ID"
echo "Update MCP_SERVER_ID in 05-create-agent.sh with: $MCP_ID"
