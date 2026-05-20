#!/usr/bin/env bash
# One-time setup for the pytest test database.
#
# Creates the `drape_test` database in the same Postgres container the dev DB
# uses (port 5433), then runs alembic against it. Idempotent — safe to re-run
# whenever the schema changes.
#
# Usage (from backend/, with venv active):
#   bash tests/init_test_db.sh
set -euo pipefail

TEST_DB_NAME="${TEST_DB_NAME:-drape_test}"
PG_DSN="${PG_DSN:-postgresql://admin:password@localhost:5433/postgres}"
TEST_DB_URL="postgresql+psycopg2://admin:password@localhost:5433/${TEST_DB_NAME}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing required command: $1" >&2; exit 127
  }
}
require_cmd psql
require_cmd alembic

echo "[..] checking $TEST_DB_NAME exists"
EXISTS=$(psql "$PG_DSN" -tAc "SELECT 1 FROM pg_database WHERE datname='$TEST_DB_NAME'" || true)
if [[ "$EXISTS" != "1" ]]; then
  echo "[..] creating database $TEST_DB_NAME"
  psql "$PG_DSN" -c "CREATE DATABASE $TEST_DB_NAME"
else
  echo "[ok] $TEST_DB_NAME already exists"
fi

echo "[..] running alembic upgrade head against $TEST_DB_NAME"
DATABASE_URL="$TEST_DB_URL" alembic upgrade head

echo "[ok] test DB ready: $TEST_DB_URL"
