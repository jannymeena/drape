#!/usr/bin/env bash
# 08_analytics — cost-per-wear, utilization-score, weekly-report (free), and
# the intelligence-report Pro gate (402 → 200 on subscription_tier flip).
#
# Pre: dev user has wardrobe items + at least one logged outfit (after 04+05+06).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_common.sh disable=SC1091
source "$SCRIPT_DIR/_common.sh"

# --- 1) cost-per-wear ------------------------------------------------------

call GET /wardrobe/analytics/cost-per-wear
expect_status "GET /wardrobe/analytics/cost-per-wear" 200
ITEM_COUNT=$(echo "$HTTP_BODY" | jq -r '.items | length')
say_pass "  → ${ITEM_COUNT} items in cpw report"

# --- 2) utilization-score --------------------------------------------------

call GET /wardrobe/analytics/utilization-score
expect_status "GET /wardrobe/analytics/utilization-score" 200
SCORE=$(echo "$HTTP_BODY" | jq -r '.score')
LABEL=$(echo "$HTTP_BODY" | jq -r '.label')
say_pass "  → score=$SCORE, label=$LABEL"

# --- 3) weekly-report (free teaser) ----------------------------------------

call GET /wardrobe/analytics/weekly-report
expect_status "GET /wardrobe/analytics/weekly-report" 200
expect_body_field "  → has pro_teaser string" \
  '.pro_teaser | length > 0' "true"

# --- 4) intelligence-report — 402 for free user ----------------------------
# Make sure dev user is on free tier first.

db_exec "UPDATE users SET subscription_tier = 'free' WHERE email = '$DEV_EMAIL'"

call GET /wardrobe/analytics/intelligence-report
expect_status "GET /wardrobe/analytics/intelligence-report (free) → 402" 402
expect_body_field "  → error=pro_required" '.detail.error' "pro_required"
say_pass "  → upsell sheet payload received"

# --- 5) flip to pro, expect 200 --------------------------------------------

db_exec "UPDATE users SET subscription_tier = 'pro' WHERE email = '$DEV_EMAIL'"

call GET /wardrobe/analytics/intelligence-report
expect_status "GET /wardrobe/analytics/intelligence-report (pro) → 200" 200
TOTAL_ITEMS=$(echo "$HTTP_BODY" | jq -r '.total_items')
say_pass "  → total_items=$TOTAL_ITEMS"

# --- 6) restore dev user to free tier (cleanup) ----------------------------

db_exec "UPDATE users SET subscription_tier = 'free' WHERE email = '$DEV_EMAIL'"
say_pass "  → dev user restored to free tier"

echo
echo "${C_GREEN}=== 08_analytics: all checks passed ===${C_RESET}"
