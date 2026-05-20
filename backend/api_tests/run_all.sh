#!/usr/bin/env bash
# run_all — full smoke run from a clean state.
#
# Requires: server running on $BASE_URL (default localhost:8000), venv active,
# cwd = backend/. Resets the DB before each run, so it's destructive — only
# use against the dev DB.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -t 1 ]]; then
  C_RESET=$'\e[0m'; C_BOLD=$'\e[1m'; C_GREEN=$'\e[32m'; C_RED=$'\e[31m'
else
  C_RESET=""; C_BOLD=""; C_GREEN=""; C_RED=""
fi

started_at=$(date +%s)
echo "${C_BOLD}=== run_all: starting full smoke run ===${C_RESET}"

bash "$SCRIPT_DIR/reset.sh"

for script in \
  "01_auth.sh" \
  "02_profile.sh" \
  "03_starter_wardrobe.sh" \
  "04_wardrobe.sh" \
  "05_today.sh" \
  "06_outfits.sh" \
  "07_usage.sh" \
  "08_analytics.sh"
do
  echo
  echo "${C_BOLD}--- running $script ---${C_RESET}"
  if ! bash "$SCRIPT_DIR/$script"; then
    echo "${C_RED}FAILED at $script${C_RESET}"
    exit 1
  fi
done

elapsed=$(( $(date +%s) - started_at ))
echo
echo "${C_GREEN}${C_BOLD}=== run_all: PASS (${elapsed}s) ===${C_RESET}"
