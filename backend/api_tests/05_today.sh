#!/usr/bin/env bash
# 05_today — plan today, then the dashboard + one-call styling + force-generate.
# 03 turned the starter wardrobe off, so outfits come only from the user's own
# items (wardrobe mode). Against the dev MockAIProvider the stylist's reply
# doesn't parse, so Today gets the heuristic look (`_fallback_proposal`):
# one look, bland reasoning, but the wiring is fully exercised.
#
# Pre: 02_profile done. Creates its own wardrobe items.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_common.sh disable=SC1091
source "$SCRIPT_DIR/_common.sh"

# --- 0) Own items: two tops, a bottom, shoes ---------------------------------

for spec in "Oxford Shirt (api_tests)|tops" "Silk Blouse (api_tests)|tops" \
            "Tailored Trousers (api_tests)|bottoms" "Loafers (api_tests)|shoes"; do
  call POST /wardrobe/items "{\"name\":\"${spec%%|*}\",\"category\":\"${spec##*|}\",\"formality\":\"smart_casual\"}"
  expect_status "POST /wardrobe/items (${spec%%|*})" 201
done

# --- 1) No plan for today: the dashboard asks for one ----------------------

call GET /today/dashboard
expect_status "GET /today/dashboard (unplanned)" 200
expect_body_field "  → needs_plan" '.needs_plan' "true"
expect_body_field "  → nothing to style yet" '.needs_styling' "false"
expect_body_field "  → wardrobe mode" '.wardrobe_mode' "wardrobe"

call POST /today/outfits '{}'
expect_status "POST /today/outfits without a plan → 400" 400

# --- 2) Plan today (Plan a day) ----------------------------------------------

call GET /today/plans
expect_status "GET /today/plans" 200
TODAY=$(echo "$HTTP_BODY" | jq -r '.days[0].date')
call PUT "/today/plans/$TODAY" '{"occasion":"work_day","dress_level":"business"}'
expect_status "PUT /today/plans/$TODAY (work day)" 200

# --- 3) GET /today/dashboard is read-only: no outfits, styling pending -----

call GET /today/dashboard
expect_status "GET /today/dashboard" 200
OUTFIT_COUNT=$(echo "$HTTP_BODY" | jq -r '.outfits | length')
[[ "$OUTFIT_COUNT" -eq 0 ]] && say_pass "  → 0 outfits (read-only, no inline generation)" \
  || { say_fail "expected 0 outfits, got $OUTFIT_COUNT"; exit 1; }
expect_body_field "  → wardrobe_ready" '.wardrobe_ready' "true"
expect_body_field "  → needs_plan" '.needs_plan' "false"
expect_body_field "  → needs_styling" '.needs_styling' "true"
WEATHER_CONDITION=$(echo "$HTTP_BODY" | jq -r '.weather.condition // "null"')
say_pass "  → weather.condition=$WEATHER_CONDITION (Open-Meteo or fallback)"

# --- 4) POST /today/outfits styles the day in ONE call (free + idempotent) --

call POST /today/outfits '{}'
expect_status "POST /today/outfits" 200
LOOKS=$(echo "$HTTP_BODY" | jq -r '.outfits | length')
[[ "$LOOKS" -ge 1 && "$LOOKS" -le 3 ]] && say_pass "  → $LOOKS look(s) (1-3)" \
  || { say_fail "expected 1-3 looks, got $LOOKS"; exit 1; }
expect_body_field "  → occasion=work (from the work-day plan)" '.outfits[0].occasion' "work"
expect_body_field "  → slot=0" '.outfits[0].slot' "0"
expect_body_field "  → no shop pieces" '.outfits[0].shop_the_look' "false"
expect_body_field "  → image_url is null (server-side composites disabled)" \
  '.outfits[0].image_url' "null"
ITEMS_LEN=$(echo "$HTTP_BODY" | jq -r '.outfits[0].items | length')
[[ "$ITEMS_LEN" -ge 2 && "$ITEMS_LEN" -le 6 ]] && \
  say_pass "  → outfit has $ITEMS_LEN items (within 2-6 cap)" || {
    say_fail "outfit item count out of range: $ITEMS_LEN"; exit 1
  }

# Capture an outfit id for downstream sub-scripts (06_outfits, 07_usage).
echo "$HTTP_BODY" | jq -r '.outfits[0].id' > /tmp/drape_dashboard_outfit_id
OUTFIT_ID=$(cat /tmp/drape_dashboard_outfit_id)
say_pass "  → captured outfit_id=${OUTFIT_ID:0:8}…"

# Idempotent: a second call returns the same looks (no AI call).
call POST /today/outfits '{}'
expect_status "POST /today/outfits (again)" 200
SECOND_ID=$(echo "$HTTP_BODY" | jq -r '.outfits[0].id')
[[ "$SECOND_ID" == "$OUTFIT_ID" ]] && \
  say_pass "  → idempotent: same outfit id returned" || {
    say_fail "expected same id $OUTFIT_ID, got $SECOND_ID"; exit 1
  }

# --- 5) Re-GET dashboard: the looks now surface; nothing pending ------------

call GET /today/dashboard
expect_status "GET /today/dashboard (after styling)" 200
AFTER_COUNT=$(echo "$HTTP_BODY" | jq -r '.outfits | length')
[[ "$AFTER_COUNT" -eq "$LOOKS" ]] && say_pass "  → $LOOKS outfit(s) now present" \
  || { say_fail "expected $LOOKS outfits, got $AFTER_COUNT"; exit 1; }
expect_body_field "  → nothing left to style" '.needs_styling' "false"

# --- 6) Force-generate one off-dashboard outfit via /today/generate-outfits --

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
