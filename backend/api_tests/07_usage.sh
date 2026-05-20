#!/usr/bin/env bash
# 07_usage — verifies the /usage/current-week endpoint and the 21/wk outfit
# limit. Drives the limit by directly bumping `usage_tracking.outfits_generated`
# (faster than calling /today/generate-outfits 21 times). Resets the counter
# at the end so subsequent scripts aren't blocked.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_common.sh disable=SC1091
source "$SCRIPT_DIR/_common.sh"

# --- 1) GET /usage/current-week -------------------------------------------

call GET /usage/current-week
expect_status "GET /usage/current-week" 200
LIMIT=$(echo "$HTTP_BODY" | jq -r '.outfits.limit')
say_pass "  → outfits.limit=$LIMIT (free tier should be 21)"

# --- 2) Bump usage_tracking to 21 outfits, then attempt one more outfit ---

# Make sure a usage_tracking row exists (one summary read creates it).
db_exec "
UPDATE usage_tracking
SET outfits_generated = 21
WHERE user_id = (SELECT id FROM users WHERE email = '$DEV_EMAIL')
"

# Confirm the bump landed.
USED=$(db_scalar "
SELECT outfits_generated FROM usage_tracking
WHERE user_id = (SELECT id FROM users WHERE email = '$DEV_EMAIL')
ORDER BY week_start_date DESC LIMIT 1
")
[[ "$USED" == "21" ]] && say_pass "  → usage_tracking.outfits_generated bumped to 21" \
  || { say_fail "expected 21, DB shows $USED"; exit 1; }

# --- 3) 22nd outfit attempt → 429 ------------------------------------------

call POST /today/generate-outfits '{"occasions":["work"]}'
expect_status "POST /today/generate-outfits (22nd) → 429" 429
expect_body_field "  → error=limit_reached" '.detail.error' "limit_reached"
expect_body_field "  → resource=outfits" '.detail.resource' "outfits"
RESETS_AT=$(echo "$HTTP_BODY" | jq -r '.detail.resets_at')
[[ -n "$RESETS_AT" && "$RESETS_AT" != "null" ]] && \
  say_pass "  → resets_at=$RESETS_AT" || {
    say_fail "no resets_at in 429 body"; print_body; exit 1
  }

# --- 4) Cleanup — restore the counter so other scripts can run ------------

db_exec "
UPDATE usage_tracking
SET outfits_generated = 0
WHERE user_id = (SELECT id FROM users WHERE email = '$DEV_EMAIL')
"
say_pass "  → usage_tracking.outfits_generated reset to 0"

# --- 5) GET /usage/current-week now reflects the reset --------------------

call GET /usage/current-week
expect_status "GET /usage/current-week (after reset)" 200
expect_body_field "  → outfits.used=0" '.outfits.used' "0"

echo
echo "${C_GREEN}=== 07_usage: all checks passed ===${C_RESET}"
