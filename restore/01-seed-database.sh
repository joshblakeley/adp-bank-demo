#!/usr/bin/env bash
# Seed the RDS Postgres database with schema and mock data.
# Usage: RDS_HOST=<endpoint> RDS_PASS=<password> ./01-seed-database.sh

set -euo pipefail

RDS_HOST="${RDS_HOST:-joshb-adp-demo.c3uaqo244uj7.us-east-2.rds.amazonaws.com}"
RDS_USER="${RDS_USER:-postgres}"
RDS_DB="${RDS_DB:-bank_demo}"

echo "Seeding $RDS_DB on $RDS_HOST ..."
PGPASSWORD="${RDS_PASS}" psql -h "$RDS_HOST" -U "$RDS_USER" -d "$RDS_DB" -f ../bank-demo-seed.sql
echo "Done."
