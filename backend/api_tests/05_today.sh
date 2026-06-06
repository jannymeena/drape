#!/usr/bin/env bash
# 05_today — dashboard + force-generate. Note: against the dev MockAIProvider,
# outfit JSON parsing falls back to the heuristic path (`_fallback_proposal`),
# so reasoning text is bland but the wiring is fully exercised.
#
# Pre: 02_profile + 03_starter_wardrobe done so the user has items to draw on.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_common.sh disable=SC1091
source "$SCRIPT_DIR/_common.sh"

# --- 1) GET /today/dashboard is read-only: empty outfits + 3 pending ---------

call GET /today/dashboard
expect_status "GET /today/dashboard" 200
OUTFIT_COUNT=$(echo "$HTTP_BODY" | jq -r '.outfits | length')
[[ "$OUTFIT_COUNT" -eq 0 ]] && say_pass "  → 0 outfits (read-only, no inline generation)" \
  || { say_fail "expected 0 outfits, got $OUTFIT_COUNT"; exit 1; }
expect_body_field "  → wardrobe_ready" '.wardrobe_ready' "true"
PENDING_COUNT=$(echo "$HTTP_BODY" | jq -r '.pending_occasions | length')
[[ "$PENDING_COUNT" -eq 3 ]] && say_pass "  → 3 pending occasions" \
  || { say_fail "expected 3 pending_occasions, got $PENDING_COUNT"; exit 1; }
WEATHER_CONDITION=$(echo "$HTTP_BODY" | jq -r '.weather.condition // "null"')
say_pass "  → weather.condition=$WEATHER_CONDITION (Open-Meteo or fallback)"

# --- 2) POST /today/outfits fills ONE occasion (free + idempotent) ----------

call POST /today/outfits '{"occasion":"work"}'
expect_status "POST /today/outfits (work)" 200
WORK_OCCASION=$(echo "$HTTP_BODY" | jq -r '.occasion')
[[ "$WORK_OCCASION" == "work" ]] && say_pass "  → occasion=work" \
  || { say_fail "expected occasion=work, got $WORK_OCCASION"; exit 1; }
expect_body_field "  → image_url is null (server-side composites disabled)" \
  '.image_url' "null"
ITEMS_LEN=$(echo "$HTTP_BODY" | jq -r '.items | length')
[[ "$ITEMS_LEN" -ge 2 && "$ITEMS_LEN" -le 6 ]] && \
  say_pass "  → outfit has $ITEMS_LEN items (within 2-6 cap)" || {
    say_fail "outfit item count out of range: $ITEMS_LEN"; exit 1
  }

# Capture an outfit id for downstream sub-scripts (06_outfits, 07_usage).
echo "$HTTP_BODY" | jq -r '.id' > /tmp/drape_dashboard_outfit_id
OUTFIT_ID=$(cat /tmp/drape_dashboard_outfit_id)
say_pass "  → captured outfit_id=${OUTFIT_ID:0:8}…"

# Idempotent: a second call for the same occasion returns the same outfit.
call POST /today/outfits '{"occasion":"work"}'
expect_status "POST /today/outfits (work, again)" 200
SECOND_ID=$(echo "$HTTP_BODY" | jq -r '.id')
[[ "$SECOND_ID" == "$OUTFIT_ID" ]] && \
  say_pass "  → idempotent: same outfit id returned" || {
    say_fail "expected same id $OUTFIT_ID, got $SECOND_ID"; exit 1
  }

# --- 3) Re-GET dashboard: the work outfit now surfaces; 2 occasions pending --

call GET /today/dashboard
expect_status "GET /today/dashboard (after fill)" 200
AFTER_COUNT=$(echo "$HTTP_BODY" | jq -r '.outfits | length')
[[ "$AFTER_COUNT" -eq 1 ]] && say_pass "  → 1 outfit now present" \
  || { say_fail "expected 1 outfit, got $AFTER_COUNT"; exit 1; }
AFTER_PENDING=$(echo "$HTTP_BODY" | jq -r '.pending_occasions | length')
[[ "$AFTER_PENDING" -eq 2 ]] && say_pass "  → 2 occasions still pending" \
  || { say_fail "expected 2 pending, got $AFTER_PENDING"; exit 1; }
expect_body_field "  → starter_wardrobe banner" '.banners.starter_wardrobe' "true"

# --- 4) Force-generate one extra outfit via /today/generate-outfits --------

call POST /today/generate-outfits '{"occasions":["gym"]}'
expect_status "POST /today/generate-outfits (gym)" 200
GEN_COUNT=$(echo "$HTTP_BODY" | jq -r '.outfits | length')
[[ "$GEN_COUNT" -eq 1 ]] && say_pass "  → 1 outfit generated for gym" \
  || { say_fail "expected 1, got $GEN_COUNT"; exit 1; }
GYM_OCCASION=$(echo "$HTTP_BODY" | jq -r '.outfits[0].occasion')
[[ "$GYM_OCCASION" == "gym" ]] && say_pass "  → occasion=gym" \
  || { say_fail "expected occasion=gym, got $GYM_OCCASION"; exit 1; }

echo
echo "${C_GREEN}=== 05_today: all checks passed ===${C_RESET}"
