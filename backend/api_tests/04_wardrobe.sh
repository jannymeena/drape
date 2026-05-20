#!/usr/bin/env bash
# 04_wardrobe — manual item CRUD, log-worn idempotency, favorites, scanner,
# and the cross-user IDOR check (404, not 403).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_common.sh disable=SC1091
source "$SCRIPT_DIR/_common.sh"

# --- 1) list (post-starter assignment, should be ≥1) -------------------------

call GET /wardrobe
expect_status "GET /wardrobe" 200
INITIAL_TOTAL=$(echo "$HTTP_BODY" | jq -r '.total')
say_pass "  → wardrobe has $INITIAL_TOTAL items"

# --- 2) create a manual item ------------------------------------------------

CREATE_BODY=$(cat <<'JSON'
{
  "name": "Linen Blouse (api_tests)",
  "category": "tops",
  "subcategory": "blouses",
  "color_hex": "#FFFFFF",
  "color_name": "white",
  "pattern": "solid",
  "formality": "smart_casual",
  "season": ["spring","summer"],
  "purchase_price": 120.00
}
JSON
)
call POST /wardrobe/items "$CREATE_BODY"
expect_status "POST /wardrobe/items" 201
ITEM_ID=$(echo "$HTTP_BODY" | jq -r '.id')
say_pass "  → created item_id=$ITEM_ID"

# --- 3) get the item back ----------------------------------------------------

call GET "/wardrobe/items/$ITEM_ID"
expect_status "GET /wardrobe/items/{id}" 200
expect_body_field "  → name matches" '.name' "Linen Blouse (api_tests)"
expect_body_field "  → cost_per_wear is null" '.cost_per_wear' "null"

# --- 4) log-worn (1st time) — bumps worn_count, computes cost_per_wear ------

call POST "/wardrobe/items/$ITEM_ID/log-worn" '{}'
expect_status "POST /wardrobe/items/{id}/log-worn (first)" 200
expect_body_field "  → worn_count=1" '.worn_count' "1"
expect_body_field "  → already_logged_today=false" '.already_logged_today' "false"
expect_body_field "  → cost_per_wear=$120/1=120" '.cost_per_wear' "120"

# --- 5) log-worn (same day, idempotent) -------------------------------------

call POST "/wardrobe/items/$ITEM_ID/log-worn" '{}'
expect_status "POST /wardrobe/items/{id}/log-worn (idempotent)" 200
expect_body_field "  → worn_count still 1" '.worn_count' "1"
expect_body_field "  → already_logged_today=true" '.already_logged_today' "true"

# --- 6) toggle favorite -----------------------------------------------------

call POST "/wardrobe/items/$ITEM_ID/toggle-favorite"
expect_status "POST /wardrobe/items/{id}/toggle-favorite (on)" 200
expect_body_field "  → is_favorite=true" '.is_favorite' "true"

call POST "/wardrobe/items/$ITEM_ID/toggle-favorite"
expect_status "POST /wardrobe/items/{id}/toggle-favorite (off)" 200
expect_body_field "  → is_favorite=false" '.is_favorite' "false"

# --- 7) PATCH the item — recomputes cost_per_wear when price changes -------

call PATCH "/wardrobe/items/$ITEM_ID" '{"purchase_price": 60}'
expect_status "PATCH /wardrobe/items/{id} (price)" 200
expect_body_field "  → cost_per_wear=$60/1=60" '.cost_per_wear' "60"

# --- 8) filter ?category=tops returns rows ---------------------------------

call GET "/wardrobe?category=tops&limit=5"
expect_status "GET /wardrobe?category=tops&limit=5" 200
TOPS_COUNT=$(echo "$HTTP_BODY" | jq -r '.items | length')
[[ "$TOPS_COUNT" -ge 1 ]] && say_pass "  → $TOPS_COUNT 'tops' returned" \
  || { say_fail "expected ≥1 tops, got $TOPS_COUNT"; exit 1; }

# --- 9) cross-user IDOR check — 404, not 403 (no existence oracle) ---------
# Mint a second user, attempt to fetch the dev user's item with that user's
# token. Should return 404 — same path as a non-existent item id.

OTHER_EMAIL="api-other-$(date +%s)@drape.local"
SIGNUP=$(jq -n --arg e "$OTHER_EMAIL" \
  '{auth_method:"email", email:$e, password:"password1", display_name:"Other",
    agreed_to_terms:true, agreed_to_privacy:true}')
call_unauth POST /auth/signup "$SIGNUP"
expect_status "POST /auth/signup (other user)" 201
OTHER_TOKEN=$(echo "$HTTP_BODY" | jq -r '.access_token')

# Manually set Authorization for this one call (don't disturb the cached dev token).
HTTP_CODE=$(curl -sS -o /tmp/_idor_body -w "%{http_code}" \
  -H "Authorization: Bearer $OTHER_TOKEN" \
  "$BASE_URL/wardrobe/items/$ITEM_ID")
HTTP_BODY=$(cat /tmp/_idor_body); rm -f /tmp/_idor_body
expect_status "GET /wardrobe/items/{id} (cross-user) → 404" 404

# --- 10) scan-item (Mock provider returns canned tops/blue/solid/casual) ---
# We need a tiny image to multipart-upload. Generate a 1x1 PNG inline.

PNG_TMP=$(mktemp -t scan_XXXX).png
# 1x1 transparent PNG, base64-decoded
echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkAAIAAAoAAv/lxKUAAAAASUVORK5CYII=" \
  | base64 -d > "$PNG_TMP"

HTTP_CODE=$(curl -sS -o /tmp/_scan_body -w "%{http_code}" \
  -X POST "$BASE_URL/wardrobe/scan-item" \
  -H "Authorization: Bearer $(auth)" \
  -F "file=@$PNG_TMP;type=image/png")
HTTP_BODY=$(cat /tmp/_scan_body); rm -f /tmp/_scan_body "$PNG_TMP"
expect_status "POST /wardrobe/scan-item (mock)" 200
expect_body_field "  → category=tops" '.detection.category' "tops"

# --- 11) DELETE the manual item — 204 ---------------------------------------

call DELETE "/wardrobe/items/$ITEM_ID"
expect_status "DELETE /wardrobe/items/{id}" 204

# Subsequent GET → 404
call GET "/wardrobe/items/$ITEM_ID"
expect_status "GET /wardrobe/items/{id} (after delete)" 404

echo
echo "${C_GREEN}=== 04_wardrobe: all checks passed ===${C_RESET}"
