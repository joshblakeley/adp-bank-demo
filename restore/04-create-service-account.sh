#!/usr/bin/env bash
# Create a service account for the AI agent and store credentials as a secret.
# Prints the secret name — update 05-create-agent.sh with it.

set -euo pipefail

CONTROL_PLANE_URL="https://api.redpanda.com"
DATAPLANE_URL="https://api-8a6dfc25.d6kjl4h19241bg3ek3h0.byoc.prd.cloud.redpanda.com"
ORG_ID="617d637f-4645-4627-8841-c24be02f8817"

TOKEN=$(rpk cloud auth print-token 2>/dev/null || rpk cloud login --print-token 2>/dev/null)

# 1. Create service account
echo "Creating service account ..."
SA_RESPONSE=$(curl -sf -X POST "${CONTROL_PLANE_URL}/v1/service-accounts" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"service_account\": {\"name\": \"bank-demo-agent-sa\", \"description\": \"Service account for Bank Internal Assistant agent\", \"organization_id\": \"${ORG_ID}\"}}")

SA_ID=$(echo "$SA_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['service_account']['id'])")
echo "Service account created: $SA_ID"

# 2. Create client credentials for the service account
echo "Creating client credentials ..."
CREDS_RESPONSE=$(curl -sf -X POST "${CONTROL_PLANE_URL}/v1/service-accounts/${SA_ID}/client-credentials" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{}')

CLIENT_ID=$(echo "$CREDS_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['client_id'])")
CLIENT_SECRET=$(echo "$CREDS_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['client_secret'])")

# 3. Store as a JSON secret
SECRET_NAME="SERVICE_ACCOUNT_$(echo $SA_ID | tr '[:lower:]' '[:upper:]')"
SECRET_DATA=$(echo -n "{\"client_id\":\"${CLIENT_ID}\",\"client_secret\":\"${CLIENT_SECRET}\"}" | base64)

echo "Storing credentials as secret $SECRET_NAME ..."
curl -sf -X PUT "${DATAPLANE_URL}/v1/secrets/${SECRET_NAME}" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"scopes\": [\"SCOPE_REDPANDA_CONNECT\", \"SCOPE_AI_AGENT\"],
    \"secret_data\": \"$SECRET_DATA\"
  }"

echo ""
echo "Service account: $SA_ID"
echo "Secret name:     $SECRET_NAME"
echo "Update SERVICE_ACCOUNT_SECRET in 05-create-agent.sh with: $SECRET_NAME"
