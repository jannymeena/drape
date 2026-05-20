#!/usr/bin/env bash
# Shared helpers for api_tests/*.sh — sourced, not executed.
#
# Exposes:
#   $BASE_URL          — defaults to http://localhost:8000/api/v1; override via env.
#   auth               — echoes a cached access token (logs in once, caches in /tmp).
#   call METHOD PATH [JSON_BODY]
#                      — runs an authenticated request; sets $HTTP_CODE + $HTTP_BODY.
#   call_unauth METHOD PATH [JSON_BODY]
#                      — same shape but without bearer auth (used for /auth/* + /billing/webhook).
#   expect_status LABEL CODE
#                      — asserts $HTTP_CODE matches; pretty-prints body; exit 1 on miss.
#   expect_body_field LABEL JQ_FILTER EXPECTED
#                      — asserts a jq filter against $HTTP_BODY equals EXPECTED.
#   say MSG            — yellow status line. say_pass / say_fail also available.
#
# Hard requirements: bash 3.2+, curl, jq.
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8000/api/v1}"
DEV_EMAIL="${DEV_EMAIL:-dev@example.com}"
DEV_PASSWORD="${DEV_PASSWORD:-password1}"
TOKEN_FILE="${TOKEN_FILE:-/tmp/drape_dev_token}"

# --- terminal output helpers ---------------------------------------------------

if [[ -t 1 ]]; then
  C_RESET=$'\e[0m'
  C_GREEN=$'\e[32m'
  C_RED=$'\e[31m'
  C_YELLOW=$'\e[33m'
  C_GRAY=$'\e[90m'
else
  C_RESET="" C_GREEN="" C_RED="" C_YELLOW="" C_GRAY=""
fi

say()      { echo "${C_YELLOW}[..] $*${C_RESET}"; }
say_pass() { echo "${C_GREEN}[PASS]${C_RESET} $*"; }
say_fail() { echo "${C_RED}[FAIL]${C_RESET} $*"; }

# --- preflight -----------------------------------------------------------------

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing required command: $1" >&2
    exit 127
  }
}
require_cmd curl
require_cmd jq

server_up() {
  curl -fsS "$BASE_URL/health" >/dev/null 2>&1
}

if ! server_up; then
  echo "${C_RED}server not reachable at $BASE_URL/health${C_RESET}" >&2
  echo "  start it with: cd backend && uvicorn app.main:app --reload" >&2
  exit 2
fi

# --- token cache + auth --------------------------------------------------------

# Force a fresh login next call. Use after reset.sh wipes the dev user.
clear_token() {
  rm -f "$TOKEN_FILE"
}

# Echo the cached access token, refreshing it if missing or stale.
auth() {
  if [[ ! -s "$TOKEN_FILE" ]]; then
    refresh_token
  fi
  cat "$TOKEN_FILE"
}

refresh_token() {
  local body resp
  body=$(jq -n --arg e "$DEV_EMAIL" --arg p "$DEV_PASSWORD" \
    '{auth_method:"email", email:$e, password:$p}')
  resp=$(curl -fsS -X POST "$BASE_URL/auth/login" \
    -H "Content-Type: application/json" -d "$body" 2>&1) || {
      echo "${C_RED}login failed:${C_RESET} $resp" >&2
      exit 3
    }
  echo "$resp" | jq -r '.access_token' > "$TOKEN_FILE"
}

# --- HTTP call helpers ---------------------------------------------------------
#
# After call/call_unauth runs, two globals are set:
#   $HTTP_CODE — 3-digit status code as string
#   $HTTP_BODY — full response body
# Callers use these in expect_status / expect_body_field.

HTTP_CODE=""
HTTP_BODY=""

_curl_with_status() {
  # $1=method $2=path $3=body $4=auth_header_or_empty
  local method="$1" path="$2" body="${3:-}" auth_header="${4:-}"
  local tmp; tmp=$(mktemp)
  local args=(-sS -o "$tmp" -w "%{http_code}" -X "$method" "$BASE_URL$path"
              -H "Content-Type: application/json"
              -H "Accept: application/json")
  [[ -n "$auth_header" ]] && args+=(-H "$auth_header")
  [[ -n "$body" ]] && args+=(-d "$body")
  HTTP_CODE=$(curl "${args[@]}")
  HTTP_BODY=$(cat "$tmp")
  rm -f "$tmp"
}

call() {
  _curl_with_status "$1" "$2" "${3:-}" "Authorization: Bearer $(auth)"
}

call_unauth() {
  _curl_with_status "$1" "$2" "${3:-}" ""
}

# --- assertion helpers ---------------------------------------------------------

# expect_status LABEL EXPECTED_CODE
expect_status() {
  local label="$1" want="$2"
  if [[ "$HTTP_CODE" != "$want" ]]; then
    say_fail "$label — got $HTTP_CODE, expected $want"
    echo "$HTTP_BODY" | jq . 2>/dev/null || echo "$HTTP_BODY"
    exit 1
  fi
  echo "${C_GREEN}[PASS]${C_RESET} $label ${C_GRAY}($HTTP_CODE)${C_RESET}"
}

# expect_body_field LABEL JQ_FILTER EXPECTED
expect_body_field() {
  local label="$1" filter="$2" want="$3"
  local got
  got=$(echo "$HTTP_BODY" | jq -r "$filter") || {
    say_fail "$label — jq error on filter $filter"
    echo "$HTTP_BODY"
    exit 1
  }
  if [[ "$got" != "$want" ]]; then
    say_fail "$label — $filter = $got, expected $want"
    echo "$HTTP_BODY" | jq . 2>/dev/null || echo "$HTTP_BODY"
    exit 1
  fi
  echo "${C_GREEN}[PASS]${C_RESET} $label ${C_GRAY}($filter == $want)${C_RESET}"
}

# print_body — echoes $HTTP_BODY pretty-printed when run interactively.
print_body() {
  echo "$HTTP_BODY" | jq . 2>/dev/null || echo "$HTTP_BODY"
}

# --- DB helpers (used by 07_usage / 08_analytics for state setup) -------------
#
# These shell out to a Python one-liner against the same DB the API uses.
# Requires: venv activated, cwd = backend/ (so `from app.core.config` resolves).

db_exec() {
  local sql="$1"
  python -c "
from app.core.config import settings
from sqlalchemy import create_engine, text
e = create_engine(settings.database_url)
with e.begin() as c:
    c.execute(text(\"\"\"$sql\"\"\"))
" 2>/dev/null
}

db_scalar() {
  local sql="$1"
  python -c "
from app.core.config import settings
from sqlalchemy import create_engine, text
e = create_engine(settings.database_url)
with e.connect() as c:
    print(c.execute(text(\"\"\"$sql\"\"\")).scalar())
" 2>/dev/null
}
