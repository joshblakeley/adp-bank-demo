# Restore Guide

Scripts to recreate all Redpanda Cloud objects if the cluster is wiped.

## Prerequisites

- `rpk` CLI installed and authenticated (`rpk cloud login`)
- `psql` or any Postgres client
- RDS instance running and accessible (see main README)
- Cluster ID: `d6kjl4h19241bg3ek3h0`
- Dataplane API: `https://api-8a6dfc25.d6kjl4h19241bg3ek3h0.byoc.prd.cloud.redpanda.com`

## Order of operations

1. **Seed the database** — `01-seed-database.sh`
2. **Create the secret** — `02-create-secret.sh`
3. **Create the MCP server** — `03-create-mcp-server.sh`
4. **Create the service account** — `04-create-service-account.sh`
5. **Create the AI agent** — `05-create-agent.sh`

Each script prints the created resource ID — note these down as they will differ from the originals.
