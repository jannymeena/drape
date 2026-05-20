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

# --- 1) GET /today/dashboard returns 3 outfits -------------------------------

call GET /today/dashboard
expect_status "GET /today/dashboard" 200
OUTFIT_COUNT=$(echo "$HTTP_BODY" | jq -r '.outfits | length')
[[ "$OUTFIT_COUNT" -eq 3 ]] && say_pass "  → 3 outfits returned" \
  || { say_fail "expected 3 outfits, got $OUTFIT_COUNT"; exit 1; }

# Capture an outfit id for downstream sub-scripts (06_outfits, 07_usage).
echo "$HTTP_BODY" | jq -r '.outfits[0].id' > /tmp/drape_dashboard_outfit_id
OUTFIT_ID=$(cat /tmp/drape_dashboard_outfit_id)
say_pass "  → captured outfit_id=${OUTFIT_ID:0:8}…"

# Banner & weather sanity checks.
expect_body_field "  → starter_wardrobe banner" '.banners.starter_wardrobe' "true"
WEATHER_CONDITION=$(echo "$HTTP_BODY" | jq -r '.weather.condition // "null"')
say_pass "  → weather.condition=$WEATHER_CONDITION (Open-Meteo or fallback)"

# --- 2) Re-call /today/dashboard returns the same 3 outfits (cached today) --

call GET /today/dashboard
expect_status "GET /today/dashboard (re-call)" 200
SECOND_FIRST_ID=$(echo "$HTTP_BODY" | jq -r '.outfits[0].id')
[[ "$SECOND_FIRST_ID" == "$OUTFIT_ID" ]] && \
  say_pass "  → first outfit id stable across reads (today's outfits cached)" || {
    say_fail "outfit id changed between reads — caching broken?"; exit 1
  }

# --- 3) Force-generate one extra outfit via /today/generate-outfits --------

call POST /today/generate-outfits '{"occasions":["gym"]}'
expect_status "POST /today/generate-outfits (gym)" 200
GEN_COUNT=$(echo "$HTTP_BODY" | jq -r '.outfits | length')
[[ "$GEN_COUNT" -eq 1 ]] && say_pass "  → 1 outfit generated for gym" \
  || { say_fail "expected 1, got $GEN_COUNT"; exit 1; }
GYM_OCCASION=$(echo "$HTTP_BODY" | jq -r '.outfits[0].occasion')
[[ "$GYM_OCCASION" == "gym" ]] && say_pass "  → occasion=gym" \
  || { say_fail "expected occasion=gym, got $GYM_OCCASION"; exit 1; }

# --- 4) Outfit body shape: image_url is null (decision #2) ------------------

expect_body_field "  → image_url is null (server-side composites disabled)" \
  '.outfits[0].image_url' "null"

# Item count sanity (2-6 per outfit).
ITEMS_LEN=$(echo "$HTTP_BODY" | jq -r '.outfits[0].items | length')
[[ "$ITEMS_LEN" -ge 2 && "$ITEMS_LEN" -le 6 ]] && \
  say_pass "  → outfit has $ITEMS_LEN items (within 2-6 cap)" || {
    say_fail "outfit item count out of range: $ITEMS_LEN"; exit 1
  }

echo
echo "${C_GREEN}=== 05_today: all checks passed ===${C_RESET}"
