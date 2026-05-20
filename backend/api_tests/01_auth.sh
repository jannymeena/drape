#!/usr/bin/env bash
# 01_auth — exercise the auth surface: signup, login, refresh, /users/me, logout.
#
# Pre: server running, dev user seeded (or signs one up).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_common.sh disable=SC1091
source "$SCRIPT_DIR/_common.sh"

# --- 1) /users/me with the cached dev token ---------------------------------

call GET /users/me
expect_status "GET /users/me" 200
expect_body_field "  → email matches dev user" '.email' "$DEV_EMAIL"

# --- 2) login round-trip — capture refresh_token for the next step -----------

LOGIN_BODY=$(jq -n --arg e "$DEV_EMAIL" --arg p "$DEV_PASSWORD" \
  '{auth_method:"email", email:$e, password:$p}')
call_unauth POST /auth/login "$LOGIN_BODY"
expect_status "POST /auth/login (email)" 200
REFRESH=$(echo "$HTTP_BODY" | jq -r '.refresh_token')
ACCESS=$(echo "$HTTP_BODY" | jq -r '.access_token')
[[ -n "$REFRESH" && "$REFRESH" != "null" ]] || { say_fail "no refresh_token in body"; exit 1; }
say_pass "  → captured refresh_token (${REFRESH:0:8}…)"

# --- 3) refresh-token rotation ----------------------------------------------

REFRESH_BODY=$(jq -n --arg t "$REFRESH" '{refresh_token:$t}')
call_unauth POST /auth/refresh-token "$REFRESH_BODY"
expect_status "POST /auth/refresh-token" 200
NEW_ACCESS=$(echo "$HTTP_BODY" | jq -r '.access_token')
[[ "$NEW_ACCESS" != "$ACCESS" ]] && say_pass "  → access_token rotated" \
  || { say_fail "refresh returned the same access_token"; exit 1; }

# --- 4) wrong password → 401 -------------------------------------------------

BAD_BODY=$(jq -n --arg e "$DEV_EMAIL" '{auth_method:"email", email:$e, password:"wrong-password-1"}')
call_unauth POST /auth/login "$BAD_BODY"
expect_status "POST /auth/login (wrong password)" 401

# --- 5) signup → fail because email already exists ---------------------------

SIGNUP_DUP=$(jq -n --arg e "$DEV_EMAIL" \
  '{auth_method:"email", email:$e, password:"password1", display_name:"X",
    agreed_to_terms:true, agreed_to_privacy:true}')
call_unauth POST /auth/signup "$SIGNUP_DUP"
# 409 conflict per typical convention; backend may also return 400 — accept either.
if [[ "$HTTP_CODE" == "409" || "$HTTP_CODE" == "400" ]]; then
  say_pass "POST /auth/signup (duplicate email) ${C_GRAY}($HTTP_CODE)${C_RESET}"
else
  say_fail "POST /auth/signup (duplicate email) — expected 409/400, got $HTTP_CODE"
  print_body
  exit 1
fi

# --- 6) signup a new user, then logout via refresh_token ---------------------

NEW_EMAIL="api-test-$(date +%s)@drape.local"
SIGNUP_BODY=$(jq -n --arg e "$NEW_EMAIL" \
  '{auth_method:"email", email:$e, password:"password1", display_name:"API Test",
    agreed_to_terms:true, agreed_to_privacy:true}')
call_unauth POST /auth/signup "$SIGNUP_BODY"
expect_status "POST /auth/signup (new user)" 201
NEW_REFRESH=$(echo "$HTTP_BODY" | jq -r '.refresh_token')

LOGOUT_BODY=$(jq -n --arg t "$NEW_REFRESH" '{refresh_token:$t}')
call_unauth POST /auth/logout "$LOGOUT_BODY"
# Logout typically returns 204 or 200; accept either.
if [[ "$HTTP_CODE" == "204" || "$HTTP_CODE" == "200" ]]; then
  say_pass "POST /auth/logout ${C_GRAY}($HTTP_CODE)${C_RESET}"
else
  say_fail "POST /auth/logout — expected 200/204, got $HTTP_CODE"
  print_body
  exit 1
fi

echo
echo "${C_GREEN}=== 01_auth: all checks passed ===${C_RESET}"
