#!/usr/bin/env bash
# 02_profile — walk the dev user through onboarding (shopping_style → goals →
# measurements). Required precondition for 03_starter_wardrobe and 05_today.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_common.sh disable=SC1091
source "$SCRIPT_DIR/_common.sh"

# --- 1) onboarding-status shows the entry point ------------------------------

call GET /profile/onboarding-status
expect_status "GET /profile/onboarding-status" 200
print_body | head -20

# --- 2) shopping-style ------------------------------------------------------

call POST /profile/shopping-style '{"shopping_style":"womens"}'
expect_status "POST /profile/shopping-style" 200
expect_body_field "  → next_step advanced" '.next_step' "age_range"

# --- 3) age-range -----------------------------------------------------------

call POST /profile/age-range '{"age_range":"25-34"}'
expect_status "POST /profile/age-range" 200
expect_body_field "  → next_step advanced" '.next_step' "style_goals"

# --- 4) style-goals ---------------------------------------------------------

call POST /profile/style-goals '{"style_goals":["polished","maximize_wardrobe"]}'
expect_status "POST /profile/style-goals" 200

# --- 5) measurements (encrypted at rest) ------------------------------------

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

# --- 6) GET measurements round-trip — confirms decrypt path -----------------

call GET /profile/measurements
expect_status "GET /profile/measurements" 200
expect_body_field "  → height_cm round-trips" '.height_cm' "175"
expect_body_field "  → unit_system" '.unit_system' "metric"

# --- 7) bad measurement (height 500cm) → 422 --------------------------------

BAD_MEAS=$(echo "$MEAS_BODY" | jq '.height_cm = 500')
call POST /profile/measurements "$BAD_MEAS"
expect_status "POST /profile/measurements (bad height) → 422" 422

# --- 8) timezone + location patch --------------------------------------------
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
