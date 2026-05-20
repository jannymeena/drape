#!/usr/bin/env bash
# 06_outfits — reasoning, regenerate (different items), mix-and-match,
# log-as-worn (toast variant), history filter.
#
# Pre: 05_today.sh ran so we have an outfit_id staged at /tmp/drape_dashboard_outfit_id.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_common.sh disable=SC1091
source "$SCRIPT_DIR/_common.sh"

if [[ ! -f /tmp/drape_dashboard_outfit_id ]]; then
  echo "missing /tmp/drape_dashboard_outfit_id — run 05_today.sh first" >&2
  exit 2
fi
OUTFIT_ID=$(cat /tmp/drape_dashboard_outfit_id)

# --- 1) reasoning detail -----------------------------------------------------

call GET "/outfits/$OUTFIT_ID/reasoning"
expect_status "GET /outfits/{id}/reasoning" 200
REASON_LEN=$(echo "$HTTP_BODY" | jq -r '.full_text // "" | length')
[[ "$REASON_LEN" -gt 30 ]] && say_pass "  → reasoning text length=$REASON_LEN" \
  || { say_fail "reasoning text too short: $REASON_LEN"; exit 1; }
ITEM_COUNT=$(echo "$HTTP_BODY" | jq -r '.items | length')
[[ "$ITEM_COUNT" -ge 2 ]] && say_pass "  → reasoning lists $ITEM_COUNT items" \
  || { say_fail "expected ≥2 items in reasoning, got $ITEM_COUNT"; exit 1; }

# --- 2) regenerate produces a new outfit row (different id) ----------------

call POST "/outfits/$OUTFIT_ID/regenerate"
expect_status "POST /outfits/{id}/regenerate" 200
NEW_OUTFIT_ID=$(echo "$HTTP_BODY" | jq -r '.id')
[[ "$NEW_OUTFIT_ID" != "$OUTFIT_ID" ]] && say_pass "  → new outfit_id=${NEW_OUTFIT_ID:0:8}…" \
  || { say_fail "regenerate returned the same id"; exit 1; }

# --- 3) mix-and-match — swap one item in the outfit -------------------------

# Pick the first item in the regenerated outfit, and a wardrobe item NOT in it.
OLD_ITEM=$(echo "$HTTP_BODY" | jq -r '.items[0].item_id')

call GET /wardrobe?limit=50
CURRENT_IDS=$(echo "$HTTP_BODY" | jq -r --arg o "$OLD_ITEM" \
  '.items[] | select(.id != $o) | .id' | head -1)
NEW_ITEM="$CURRENT_IDS"

if [[ -z "$NEW_ITEM" ]]; then
  echo "no candidate item available for swap" >&2
  exit 2
fi

SWAP_BODY=$(jq -n --arg old "$OLD_ITEM" --arg new "$NEW_ITEM" \
  '{swapped_items:[{old_item_id:$old, new_item_id:$new}]}')
call POST "/outfits/$NEW_OUTFIT_ID/mix-and-match" "$SWAP_BODY"
expect_status "POST /outfits/{id}/mix-and-match" 200
SCORE=$(echo "$HTTP_BODY" | jq -r '.compatibility_score')
say_pass "  → compatibility_score=$SCORE (deterministic; no AI roundtrip)"

# --- 4) log-as-worn — first log returns toast.type=default -----------------

call POST "/outfits/$NEW_OUTFIT_ID/log"
expect_status "POST /outfits/{id}/log (first time)" 200
expect_body_field "  → current_streak=1" '.current_streak' "1"
expect_body_field "  → toast.type=default" '.toast.type' "default"

# --- 5) outfit history -------------------------------------------------------

call GET "/outfits/history?filter=all"
expect_status "GET /outfits/history?filter=all" 200
TOTAL=$(echo "$HTTP_BODY" | jq -r '.total_count')
[[ "$TOTAL" -ge 1 ]] && say_pass "  → history has $TOTAL entries" \
  || { say_fail "expected ≥1 history entries, got $TOTAL"; exit 1; }
expect_body_field "  → filter echo" '.filter' "all"

call GET "/outfits/history?filter=this_week"
expect_status "GET /outfits/history?filter=this_week" 200

echo
echo "${C_GREEN}=== 06_outfits: all checks passed ===${C_RESET}"
