#!/usr/bin/env bash
# Create the "Bank Internal Assistant" AI agent.
# Update MCP_SERVER_ID and SERVICE_ACCOUNT_SECRET with values from previous scripts.

set -euo pipefail

DATAPLANE_URL="https://api-8a6dfc25.d6kjl4h19241bg3ek3h0.byoc.prd.cloud.redpanda.com"
GATEWAY_ID="d6pcvp00tgis73ac72mg"

# Update these with IDs from steps 3 and 4:
MCP_SERVER_ID="${MCP_SERVER_ID:-d76lq0o5s2pc73bj5ua0}"
SERVICE_ACCOUNT_SECRET="${SERVICE_ACCOUNT_SECRET:-SERVICE_ACCOUNT_D76O334UM3VHHOR7UOKG}"

TOKEN=$(rpk cloud auth print-token 2>/dev/null || rpk cloud login --print-token 2>/dev/null)

echo "Creating Bank Internal Assistant agent ..."

RESPONSE=$(curl -sf -X POST "${DATAPLANE_URL}/v1alpha3/ai-agents" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"ai_agent\": {
      \"display_name\": \"Bank Internal Assistant\",
      \"description\": \"Internal bank employee tool for customer account lookups, balance checks, and overdraft investigation.\",
      \"model\": \"gpt-5.2\",
      \"provider\": {
        \"openai\": {
          \"api_key\": \"\",
          \"base_url\": \"\"
        }
      },
      \"gateway\": {
        \"virtual_gateway_id\": \"${GATEWAY_ID}\"
      },
      \"mcp_servers\": {
        \"${MCP_SERVER_ID}\": {
          \"id\": \"${MCP_SERVER_ID}\",
          \"tool_filter_regex\": \"\"
        }
      },
      \"service_account\": {
        \"client_id\": \"\${secrets.${SERVICE_ACCOUNT_SECRET}.client_id}\",
        \"client_secret\": \"\${secrets.${SERVICE_ACCOUNT_SECRET}.client_secret}\"
      },
      \"system_prompt\": \"You are an internal assistant for bank employees. You help staff quickly look up customer account information, check balances, and investigate overdraft situations.\n\n## Your capabilities\nYou have access to three tools:\n- **get_customer**: Look up a customer by name (partial match supported)\n- **get_account_balance**: Get the current balance and overdraft status for an account\n- **get_recent_transactions**: Get recent transaction history for an account\n\n## Workflow\nWhen asked about a customer:\n1. Call \`get_customer\` with their name to retrieve their account IDs\n2. Call \`get_account_balance\` for each account to check status\n3. If an account is overdrawn or the employee wants to understand recent activity, call \`get_recent_transactions\`\n\n## Response style\n- Be concise and factual — this is an internal tool, not a customer-facing chat\n- Lead with the most important finding (e.g. \\\"Account 3 is overdrawn by \$87.42\\\")\n- When surfacing overdrafts, always show the 3-5 most recent transactions that explain it\n- Use clear formatting: customer name, account type, balance, status, then transactions if relevant\n\n## Status meanings\n- **healthy**: balance > \$0 and above \$100\n- **low**: balance \$0–\$99, approaching zero\n- **overdrawn**: balance negative but within the overdraft limit — transactions may still clear\n- **overdraft_exceeded**: balance below overdraft limit — transactions will be declined\",
      \"max_iterations\": 10,
      \"resources\": { \"memory_shares\": \"400M\", \"cpu_shares\": \"100m\" },
      \"tags\": { \"env\": \"demo\", \"owner\": \"josh\" }
    }
  }")

AGENT_ID=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['ai_agent']['id'])")
AGENT_URL=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['ai_agent']['url'])")

echo ""
echo "Agent created: $AGENT_ID"
echo "Agent URL:     $AGENT_URL"
echo ""
echo "Test it with:"
echo "  curl -s -X POST ${AGENT_URL}/message/send \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"message/send\",\"params\":{\"message\":{\"role\":\"user\",\"parts\":[{\"kind\":\"text\",\"text\":\"Is Sarah Miller overdrawn?\"}]}}}'"
