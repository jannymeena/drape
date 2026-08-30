#!/usr/bin/env bash
# 02_profile — walk the dev user through the 7-step Style Blueprint onboarding,
# then submit measurements (which now live outside onboarding, in the Shop /
# Profile tabs). Required precondition for 03_starter_wardrobe and 05_today.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_common.sh disable=SC1091
source "$SCRIPT_DIR/_common.sh"

# --- 1) onboarding-status shows the entry point ------------------------------

call GET /profile/onboarding-status
expect_status "GET /profile/onboarding-status" 200
print_body | head -20

# --- 2) blueprint step 1: identity (shop-for + age) -------------------------

call POST /profile/style-blueprint/identity \
  '{"shopping_style":"womens","age_range":"25-34"}'
expect_status "POST /profile/style-blueprint/identity" 200
expect_body_field "  → next_step advanced" '.next_step' "style_blueprint_2"

# --- 3) blueprint step 2: body shape + fit ----------------------------------

call POST /profile/style-blueprint/fit \
  '{"body_shape":"hourglass","fit_tops":"regular","fit_bottoms":"relaxed"}'
expect_status "POST /profile/style-blueprint/fit" 200
expect_body_field "  → next_step advanced" '.next_step' "style_blueprint_3"

# --- 4) blueprint step 3: style aesthetics ----------------------------------

call POST /profile/style-blueprint/aesthetics \
  '{"style_aesthetics":["minimalist","smart_casual"]}'
expect_status "POST /profile/style-blueprint/aesthetics" 200
expect_body_field "  → next_step advanced" '.next_step' "style_blueprint_4"

# --- 5) blueprint step 4: undertone + palettes ------------------------------

call POST /profile/style-blueprint/color \
  '{"undertone":"warm","color_palettes":["earth_tones","neutrals"]}'
expect_status "POST /profile/style-blueprint/color" 200
expect_body_field "  → next_step advanced" '.next_step' "style_blueprint_5"

# --- 6) blueprint step 5: work + dress code ---------------------------------

call POST /profile/style-blueprint/lifestyle \
  '{"occupation":"Marketing","dress_code":"business_casual","impression_goal":"both"}'
expect_status "POST /profile/style-blueprint/lifestyle" 200
expect_body_field "  → next_step advanced" '.next_step' "style_blueprint_6"

# --- 7) blueprint step 6: habits --------------------------------------------

call POST /profile/style-blueprint/habits \
  '{"shopping_feeling":"confident","accessories":"minimal","brand_tier":"premium"}'
expect_status "POST /profile/style-blueprint/habits" 200
expect_body_field "  → next_step advanced" '.next_step' "style_blueprint_7"

# --- 8) blueprint step 7: goals ---------------------------------------------

call POST /profile/style-blueprint/goals \
  '{"three_month_feeling":"confident_anywhere","style_goals":["polished","maximize_wardrobe"]}'
expect_status "POST /profile/style-blueprint/goals" 200
expect_body_field "  → next_step advanced" '.next_step' "style_blueprint_reveal"

# --- 9) blueprint reveal → app ----------------------------------------------

call POST /profile/style-blueprint/complete '{}'
expect_status "POST /profile/style-blueprint/complete" 200
expect_body_field "  → onboarding finished" '.next_step' "today_dashboard"

# --- 10) measurements (encrypted at rest) -----------------------------------

MEAS_BODY=$(cat <<'JSON'
{
  "height_cm": 175,
  "weight_kg": 70,
  "shoulders_cm": 42,
  "chest_cm": 96,
  "waist_cm": 78,
  "inseam_cm": 80,
  "thigh_cm": 56,
  "hips_cm": 98,
  "unit_system": "metric"
}
JSON
)
call POST /profile/measurements "$MEAS_BODY"
expect_status "POST /profile/measurements" 200
expect_body_field "  → measurements_completed" '.measurements_completed' "true"

# --- 11) GET measurements round-trip — confirms decrypt path ----------------

call GET /profile/measurements
expect_status "GET /profile/measurements" 200
expect_body_field "  → height_cm round-trips" '.height_cm' "175"
expect_body_field "  → unit_system" '.unit_system' "metric"

# --- 12) bad measurement (height 500cm) → 422 -------------------------------

BAD_MEAS=$(echo "$MEAS_BODY" | jq '.height_cm = 500')
call POST /profile/measurements "$BAD_MEAS"
expect_status "POST /profile/measurements (bad height) → 422" 422

# --- 13) timezone + location patch ------------------------------------------
# These columns landed in 5a; PATCH /users/{id} updates them.

ME_ID=$(call GET /users/me; echo "$HTTP_BODY" | jq -r '.id')
call PATCH "/users/$ME_ID" '{"timezone":"America/Toronto","location":"Toronto, ON"}'
# PATCH may return 200 with the updated user, or 204; accept either.
if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "204" ]]; then
  say_pass "PATCH /users/{id} (timezone+location) ${C_GRAY}($HTTP_CODE)${C_RESET}"
else
  say_fail "PATCH /users/{id} — got $HTTP_CODE"; print_body; exit 1
fi

echo
echo "${C_GREEN}=== 02_profile: onboarding through measurements complete ===${C_RESET}"
