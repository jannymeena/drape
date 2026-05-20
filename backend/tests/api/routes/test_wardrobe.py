"""Wardrobe route tests — ports the bash 04_wardrobe.sh checks plus
validation, pagination, and IDOR coverage.

Tests are organized into thematic groups (CRUD, log-worn, favorites, scanner,
images, IDOR, free-tier limits). Each group is independent.
"""
from __future__ import annotations

import pytest

from tests.factories import make_wardrobe_item


# ---------------------------------------------------------------------------
# CRUD
# ---------------------------------------------------------------------------


def test_create_item_returns_201_with_full_shape(authed_client):
    body = {
        "name": "Linen Blouse",
        "category": "tops",
        "subcategory": "blouses",
        "color_hex": "#FFFFFF",
        "color_name": "white",
        "pattern": "solid",
        "formality": "smart_casual",
        "season": ["spring", "summer"],
    }
    r = authed_client.post("/api/v1/wardrobe/items", json=body)
    assert r.status_code == 201, r.text
    payload = r.json()
    assert payload["name"] == "Linen Blouse"
    assert payload["category"] == "tops"
    assert payload["worn_count"] == 0
    assert payload["cost_per_wear"] is None
    assert payload["is_favorite"] is False
    assert payload["is_starter_wardrobe"] is False


def test_create_with_price_but_no_wear_keeps_cpw_null(authed_client):
    r = authed_client.post(
        "/api/v1/wardrobe/items",
        json={"name": "Trousers", "category": "bottoms", "purchase_price": 120.0},
    )
    assert r.status_code == 201
    assert r.json()["cost_per_wear"] is None


def test_get_item_returns_200(authed_client, db):
    item = make_wardrobe_item(db, authed_client.test_user, name="Sweater")
    r = authed_client.get(f"/api/v1/wardrobe/items/{item.id}")
    assert r.status_code == 200, r.text
    assert r.json()["name"] == "Sweater"


def test_get_unknown_item_returns_404(authed_client):
    fake_id = "00000000-0000-0000-0000-000000000000"
    r = authed_client.get(f"/api/v1/wardrobe/items/{fake_id}")
    assert r.status_code == 404


def test_patch_price_recomputes_cost_per_wear(authed_client, db):
    item = make_wardrobe_item(
        db, authed_client.test_user, name="Jeans", worn_count=4, purchase_price=80.0
    )
    # cost_per_wear was 80/4=20.0 at creation. Bump price to 200 → 50.0.
    r = authed_client.patch(
        f"/api/v1/wardrobe/items/{item.id}", json={"purchase_price": 200.0}
    )
    assert r.status_code == 200
    assert r.json()["cost_per_wear"] == 50.0


def test_delete_item_returns_204_then_404(authed_client, db):
    item = make_wardrobe_item(db, authed_client.test_user)
    r = authed_client.delete(f"/api/v1/wardrobe/items/{item.id}")
    assert r.status_code == 204
    r2 = authed_client.get(f"/api/v1/wardrobe/items/{item.id}")
    assert r2.status_code == 404


# ---------------------------------------------------------------------------
# List + filter + pagination
# ---------------------------------------------------------------------------


def test_list_empty_wardrobe_returns_zero(authed_client):
    r = authed_client.get("/api/v1/wardrobe")
    assert r.status_code == 200
    assert r.json()["total"] == 0
    assert r.json()["items"] == []


def test_list_filter_by_category(authed_client, db):
    user = authed_client.test_user
    make_wardrobe_item(db, user, name="Top1", category="tops")
    make_wardrobe_item(db, user, name="Top2", category="tops")
    make_wardrobe_item(db, user, name="Pants", category="bottoms")

    r = authed_client.get("/api/v1/wardrobe?category=tops")
    body = r.json()
    assert r.status_code == 200
    assert body["total"] == 2
    assert all(i["category"] == "tops" for i in body["items"])


def test_list_pagination_limit_and_offset(authed_client, db):
    user = authed_client.test_user
    for i in range(5):
        make_wardrobe_item(db, user, name=f"Item {i}")

    r1 = authed_client.get("/api/v1/wardrobe?limit=2&offset=0")
    r2 = authed_client.get("/api/v1/wardrobe?limit=2&offset=2")
    r3 = authed_client.get("/api/v1/wardrobe?limit=2&offset=4")
    assert r1.json()["total"] == 5 and len(r1.json()["items"]) == 2
    assert r2.json()["total"] == 5 and len(r2.json()["items"]) == 2
    assert r3.json()["total"] == 5 and len(r3.json()["items"]) == 1


def test_list_filter_by_is_favorite(authed_client, db):
    user = authed_client.test_user
    fav = make_wardrobe_item(db, user, name="Fav")
    make_wardrobe_item(db, user, name="NotFav")
    authed_client.post(f"/api/v1/wardrobe/items/{fav.id}/toggle-favorite")

    r = authed_client.get("/api/v1/wardrobe?is_favorite=true")
    body = r.json()
    assert body["total"] == 1
    assert body["items"][0]["name"] == "Fav"


# ---------------------------------------------------------------------------
# Validation (Pydantic)
# ---------------------------------------------------------------------------


def test_create_missing_name_returns_422(authed_client):
    r = authed_client.post("/api/v1/wardrobe/items", json={"category": "tops"})
    assert r.status_code == 422


def test_create_bad_category_returns_422(authed_client):
    r = authed_client.post(
        "/api/v1/wardrobe/items",
        json={"name": "X", "category": "spaceships"},
    )
    assert r.status_code == 422


def test_create_bad_color_hex_returns_422(authed_client):
    r = authed_client.post(
        "/api/v1/wardrobe/items",
        json={"name": "X", "category": "tops", "color_hex": "not-a-hex"},
    )
    assert r.status_code == 422


# ---------------------------------------------------------------------------
# Log-worn
# ---------------------------------------------------------------------------


def test_log_worn_first_time_bumps_count_and_computes_cpw(authed_client, db):
    item = make_wardrobe_item(
        db, authed_client.test_user, name="Coat", purchase_price=300.0
    )
    r = authed_client.post(f"/api/v1/wardrobe/items/{item.id}/log-worn", json={})
    assert r.status_code == 200
    body = r.json()
    assert body["worn_count"] == 1
    assert body["cost_per_wear"] == 300.0
    assert body["already_logged_today"] is False


def test_log_worn_idempotent_per_day(authed_client, db):
    item = make_wardrobe_item(db, authed_client.test_user)
    authed_client.post(f"/api/v1/wardrobe/items/{item.id}/log-worn", json={})
    r2 = authed_client.post(f"/api/v1/wardrobe/items/{item.id}/log-worn", json={})
    assert r2.status_code == 200
    body = r2.json()
    assert body["worn_count"] == 1, "second same-day log shouldn't bump count"
    assert body["already_logged_today"] is True


# ---------------------------------------------------------------------------
# Favorites
# ---------------------------------------------------------------------------


def test_toggle_favorite_round_trip(authed_client, db):
    item = make_wardrobe_item(db, authed_client.test_user)
    r1 = authed_client.post(f"/api/v1/wardrobe/items/{item.id}/toggle-favorite")
    assert r1.status_code == 200
    assert r1.json()["is_favorite"] is True
    assert r1.json()["favorited_at"] is not None

    r2 = authed_client.post(f"/api/v1/wardrobe/items/{item.id}/toggle-favorite")
    assert r2.status_code == 200
    assert r2.json()["is_favorite"] is False
    assert r2.json()["favorited_at"] is None


# ---------------------------------------------------------------------------
# Scanner (mock AI returns canned tops/blue/solid/casual @ 80% confidence)
# ---------------------------------------------------------------------------


# Tiny 1x1 transparent PNG. Real-image-bytes-shaped, but the mock provider
# ignores content — it returns canned scanner JSON regardless.
_TINY_PNG = (
    b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01"
    b"\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\rIDATx\x9cc\xfc\xcf"
    b"\xc0\x00\x00\x00\x05\x00\x01\xa5\x86\x82\x16\x00\x00\x00\x00IEND\xaeB`\x82"
)


def test_scan_item_returns_canned_detection(authed_client):
    r = authed_client.post(
        "/api/v1/wardrobe/scan-item",
        files={"file": ("test.png", _TINY_PNG, "image/png")},
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["detection"]["category"] == "tops"
    assert body["detection"]["confidence"] == 80
    # confidence=80 ≥ WARN_CONFIDENCE_THRESHOLD=70 → no manual entry suggested.
    assert body["suggest_manual_entry"] is False


def test_scan_item_rejects_unsupported_content_type(authed_client):
    r = authed_client.post(
        "/api/v1/wardrobe/scan-item",
        files={"file": ("test.gif", b"GIF89a", "image/gif")},
    )
    assert r.status_code == 415


def test_scan_item_rejects_empty_upload(authed_client):
    r = authed_client.post(
        "/api/v1/wardrobe/scan-item",
        files={"file": ("test.png", b"", "image/png")},
    )
    assert r.status_code == 400


# ---------------------------------------------------------------------------
# Images (multipart upload)
# ---------------------------------------------------------------------------


def test_add_images_appends_to_item_and_sets_primary(authed_client, db):
    item = make_wardrobe_item(db, authed_client.test_user)
    r = authed_client.post(
        f"/api/v1/wardrobe/items/{item.id}/images",
        files={"files": ("a.png", _TINY_PNG, "image/png")},
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert len(body["images"]) == 1
    assert body["primary_image_url"] == body["images"][0]


def test_add_5th_image_returns_400_too_many_images(authed_client, db):
    item = make_wardrobe_item(db, authed_client.test_user)
    # 4 uploads succeed.
    for _ in range(4):
        r = authed_client.post(
            f"/api/v1/wardrobe/items/{item.id}/images",
            files={"files": ("a.png", _TINY_PNG, "image/png")},
        )
        assert r.status_code == 200
    # 5th must fail with 400.
    r = authed_client.post(
        f"/api/v1/wardrobe/items/{item.id}/images",
        files={"files": ("a.png", _TINY_PNG, "image/png")},
    )
    assert r.status_code == 400


# ---------------------------------------------------------------------------
# Cross-user IDOR — every read/write returns 404, never 403 (no oracle)
# ---------------------------------------------------------------------------


def test_cross_user_get_returns_404(client, make_user, auth_headers, db):
    alice = make_user(email="alice@example.com")
    bob = make_user(email="bob@example.com")
    alice_item = make_wardrobe_item(db, alice, name="Alice's blouse")

    r = client.get(
        f"/api/v1/wardrobe/items/{alice_item.id}", headers=auth_headers(bob)
    )
    assert r.status_code == 404, "cross-user must look identical to non-existent"


def test_cross_user_patch_returns_404(client, make_user, auth_headers, db):
    alice = make_user(email="alice@example.com")
    bob = make_user(email="bob@example.com")
    alice_item = make_wardrobe_item(db, alice)

    r = client.patch(
        f"/api/v1/wardrobe/items/{alice_item.id}",
        headers=auth_headers(bob),
        json={"name": "Hacked"},
    )
    assert r.status_code == 404


def test_cross_user_delete_returns_404(client, make_user, auth_headers, db):
    alice = make_user(email="alice@example.com")
    bob = make_user(email="bob@example.com")
    alice_item = make_wardrobe_item(db, alice)

    r = client.delete(
        f"/api/v1/wardrobe/items/{alice_item.id}", headers=auth_headers(bob)
    )
    assert r.status_code == 404


# ---------------------------------------------------------------------------
# Free-tier wardrobe item limit (Phase 6d)
# ---------------------------------------------------------------------------


def test_31st_real_item_returns_429_with_limit_reached(authed_client, db):
    user = authed_client.test_user
    # Seed 30 real items via the factory (faster than 30 POST calls).
    for i in range(30):
        make_wardrobe_item(db, user, name=f"Real {i}")

    # 31st via the API should hit the limit.
    r = authed_client.post(
        "/api/v1/wardrobe/items",
        json={"name": "Real 30", "category": "tops"},
    )
    assert r.status_code == 429, r.text
    detail = r.json()["detail"]
    assert detail["error"] == "limit_reached"
    assert detail["resource"] == "wardrobe_items"


def test_starter_items_dont_count_toward_limit(authed_client, db):
    user = authed_client.test_user
    # 9 starter + 30 real = 39 items but only 30 count toward the cap.
    for i in range(9):
        make_wardrobe_item(db, user, name=f"Starter {i}", is_starter_wardrobe=True)
    for i in range(30):
        make_wardrobe_item(db, user, name=f"Real {i}", is_starter_wardrobe=False)

    r = authed_client.post(
        "/api/v1/wardrobe/items",
        json={"name": "One more real", "category": "tops"},
    )
    assert r.status_code == 429, "30 real should already be at the cap"


def test_pro_user_bypasses_item_limit(client, make_user, auth_headers, db):
    pro = make_user(email="pro@example.com", tier="pro")
    for i in range(30):
        make_wardrobe_item(db, pro, name=f"Real {i}")

    r = client.post(
        "/api/v1/wardrobe/items",
        headers=auth_headers(pro),
        json={"name": "Real 30 (pro)", "category": "tops"},
    )
    assert r.status_code == 201, r.text


# ---------------------------------------------------------------------------
# Batch upload (scanner, 12-image cap, mixed-result folding)
# ---------------------------------------------------------------------------


def test_batch_upload_returns_all_results(authed_client):
    files = [("files", (f"item-{i}.png", _TINY_PNG, "image/png")) for i in range(3)]
    r = authed_client.post("/api/v1/wardrobe/batch-upload", files=files)
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["total"] == 3
    assert len(body["results"]) == 3
    # Mock provider always returns confidence=80 → all "ok".
    assert body["succeeded"] == 3
    assert body["errored"] == 0


def test_batch_upload_exceeds_max_size_returns_400(authed_client):
    """MAX_BATCH_SIZE=12 — the 13th file must reject the whole batch."""
    files = [("files", (f"item-{i}.png", _TINY_PNG, "image/png")) for i in range(13)]
    r = authed_client.post("/api/v1/wardrobe/batch-upload", files=files)
    assert r.status_code == 400


def test_batch_upload_per_file_indices_are_stable(authed_client):
    """Index 0..N-1 corresponds to position in the uploaded list."""
    files = [("files", (f"item-{i}.png", _TINY_PNG, "image/png")) for i in range(4)]
    r = authed_client.post("/api/v1/wardrobe/batch-upload", files=files)
    indices = sorted(item["index"] for item in r.json()["results"])
    assert indices == [0, 1, 2, 3]
