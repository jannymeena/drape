#!/usr/bin/env bash
# Wipe the dev DB, reseed starter wardrobe templates + dev user, clear the
# cached bearer token. Safe to run anytime; refuses to run when ENVIRONMENT != dev.
#
# Usage (from backend/, with venv active):
#   bash api_tests/reset.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_common.sh disable=SC1091
# Don't source _common.sh here — it preflights the server, which we don't need
# for a DB-only reset. Just clear the cached token so the next script logs in fresh.
TOKEN_FILE="${TOKEN_FILE:-/tmp/drape_dev_token}"
rm -f "$TOKEN_FILE"

echo "[..] resetting dev DB via reset_dev_db.py"
python "$SCRIPT_DIR/../scripts/reset_dev_db.py"
echo "[ok] reset complete; token cache cleared"
