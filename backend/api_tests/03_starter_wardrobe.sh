#!/usr/bin/env bash
# 03_starter_wardrobe — list templates, assign one to the dev user, confirm
# items materialize. Idempotency: re-running this should be a no-op once the
# user has any real items (the assign endpoint preserves existing state).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_common.sh disable=SC1091
source "$SCRIPT_DIR/_common.sh"

# --- 1) list available templates ---------------------------------------------

call GET /starter-wardrobe/templates
expect_status "GET /starter-wardrobe/templates" 200
TEMPLATE_COUNT=$(echo "$HTTP_BODY" | jq -r '.templates | length')
[[ "$TEMPLATE_COUNT" -ge 6 ]] && \
  say_pass "  → $TEMPLATE_COUNT templates seeded" || {
    say_fail "expected ≥6 templates, got $TEMPLATE_COUNT"; exit 1
  }

# --- 2) assign (auto-pick based on user's shopping_style + age_range) -------

call POST /starter-wardrobe/assign '{}'
expect_status "POST /starter-wardrobe/assign (auto)" 200
TEMPLATE_ID=$(echo "$HTTP_BODY" | jq -r '.template_id')
ITEMS_MATERIALIZED=$(echo "$HTTP_BODY" | jq -r '.items_materialized')
say_pass "  → template_id=$TEMPLATE_ID, items_materialized=$ITEMS_MATERIALIZED"

# --- 3) wardrobe list now contains starter items ----------------------------

call GET "/wardrobe?is_starter_wardrobe=true"
expect_status "GET /wardrobe?is_starter_wardrobe=true" 200
STARTER_COUNT=$(echo "$HTTP_BODY" | jq -r '.total')
[[ "$STARTER_COUNT" -ge 8 ]] && \
  say_pass "  → $STARTER_COUNT starter items materialized in wardrobe" || {
    say_fail "expected ≥8 starter items, got $STARTER_COUNT"; exit 1
  }

# --- 4) re-assign without override is a no-op (idempotency) -----------------
# After the first assign, transition row exists but real_items=0, so the service
# allows a swap. Add 1 real item first to lock the assignment, then re-test.

call POST /wardrobe/items '{"name":"Test Real Item","category":"tops","color_name":"black"}'
expect_status "POST /wardrobe/items (real)" 201

call POST /starter-wardrobe/assign '{}'
expect_status "POST /starter-wardrobe/assign (idempotent — has real items)" 200
expect_body_field "  → swapped=false" '.swapped' "false"
expect_body_field "  → items_materialized=0" '.items_materialized' "0"

# --- 5) deactivate manually --------------------------------------------------

call POST /starter-wardrobe/deactivate '{"reason":"manual"}'
expect_status "POST /starter-wardrobe/deactivate" 200
expect_body_field "  → is_active=false" '.assignment.is_active' "false"

# --- 6) double-deactivate is idempotent -------------------------------------

call POST /starter-wardrobe/deactivate '{"reason":"manual"}'
expect_status "POST /starter-wardrobe/deactivate (already inactive)" 200

echo
echo "${C_GREEN}=== 03_starter_wardrobe: all checks passed ===${C_RESET}"
