#!/usr/bin/env bash
# Create the BANK_DEMO_DSN secret with the correct scopes.
# Usage: RDS_HOST=<endpoint> RDS_PASS=<password> ./02-create-secret.sh

set -euo pipefail

RDS_HOST="${RDS_HOST:-joshb-adp-demo.c3uaqo244uj7.us-east-2.rds.amazonaws.com}"
RDS_USER="${RDS_USER:-postgres}"
RDS_PASS="${RDS_PASS:?RDS_PASS is required}"
RDS_DB="${RDS_DB:-bank_demo}"

CLUSTER_ID="d6kjl4h19241bg3ek3h0"
DATAPLANE_URL="https://api-8a6dfc25.d6kjl4h19241bg3ek3h0.byoc.prd.cloud.redpanda.com"

DSN="host=${RDS_HOST} user=${RDS_USER} password=${RDS_PASS} dbname=${RDS_DB} sslmode=require"
DSN_B64=$(echo -n "$DSN" | base64)

TOKEN=$(rpk cloud auth print-token 2>/dev/null || rpk cloud login --print-token 2>/dev/null)

echo "Creating/updating BANK_DEMO_DSN secret ..."
curl -sf -X PUT "${DATAPLANE_URL}/v1/secrets/BANK_DEMO_DSN" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"scopes\": [
      \"SCOPE_REDPANDA_CONNECT\",
      \"SCOPE_MCP_SERVER\"
    ],
    \"secret_data\": \"$DSN_B64\"
  }"

echo ""
echo "Secret BANK_DEMO_DSN created."
