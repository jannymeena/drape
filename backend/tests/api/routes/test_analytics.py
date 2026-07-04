"""Analytics route tests — cost-per-wear math, utilization-score normalization,
weekly-report shape, intelligence-report Pro gate (402 → 200)."""
from __future__ import annotations

from datetime import date, timedelta

from app.db.models import WardrobeWearLog
from app.schemas.user import Role
from tests.factories import make_wardrobe_item


# ---------------------------------------------------------------------------
# Cost per wear
# ---------------------------------------------------------------------------


def test_cost_per_wear_per_item_and_category_aggregates(authed_client, db):
    """$120 / 3 wears → cpw=$40 at both per-item and per-category levels."""
    user = authed_client.test_user
    item = make_wardrobe_item(db, user, name="Trousers", category="bottoms", purchase_price=120.0)
    # Manually persist 3 wear-log rows + bump the item's worn_count + cpw.
    today = date.today()
    for offset in range(3):
        db.add(
            WardrobeWearLog(
                user_id=user.id,
                item_id=item.id,
                worn_date=today - timedelta(days=offset),
                logged_at=__import__("datetime").datetime.now(),
            )
        )
    item.worn_count = 3
    item.cost_per_wear = 40.0
    db.commit()

    r = authed_client.get("/api/v1/wardrobe/analytics/cost-per-wear")
    assert r.status_code == 200
    body = r.json()
    rows = {i["item_id"]: i for i in body["items"]}
    assert rows[str(item.id)]["cost_per_wear"] == 40.0
    cats = {c["category"]: c for c in body["categories"]}
    assert cats["bottoms"]["average_cost_per_wear"] == 40.0


def test_cost_per_wear_with_no_data_returns_empty_shape(authed_client):
    r = authed_client.get("/api/v1/wardrobe/analytics/cost-per-wear")
    assert r.status_code == 200
    body = r.json()
    assert body["items"] == []
    assert body["categories"] == []


# ---------------------------------------------------------------------------
# Utilization score
# ---------------------------------------------------------------------------


def test_utilization_score_empty_wardrobe_returns_zero(authed_client):
    r = authed_client.get("/api/v1/wardrobe/analytics/utilization-score")
    assert r.status_code == 200
    body = r.json()
    assert body["score"] == 0
    assert body["label"] == "Low"
    assert body["items_total"] == 0


def test_utilization_score_all_worn_recently_returns_100(authed_client, db):
    """3 items, all worn yesterday → 100% utilization."""
    user = authed_client.test_user
    today = date.today()
    for i in range(3):
        item = make_wardrobe_item(db, user, name=f"Item {i}")
        db.add(
            WardrobeWearLog(
                user_id=user.id,
                item_id=item.id,
                worn_date=today - timedelta(days=1),
                logged_at=__import__("datetime").datetime.now(),
            )
        )
    db.commit()

    r = authed_client.get("/api/v1/wardrobe/analytics/utilization-score")
    body = r.json()
    assert body["score"] == 100
    assert body["items_worn_recently"] == 3
    assert body["items_total"] == 3
    assert body["label"] == "High"


def test_utilization_score_half_worn_returns_moderate(authed_client, db):
    user = authed_client.test_user
    today = date.today()
    for i in range(4):
        item = make_wardrobe_item(db, user, name=f"Item {i}")
        if i < 2:  # only first half is recently worn
            db.add(
                WardrobeWearLog(
                    user_id=user.id,
                    item_id=item.id,
                    worn_date=today - timedelta(days=2),
                    logged_at=__import__("datetime").datetime.now(),
                )
            )
    db.commit()

    r = authed_client.get("/api/v1/wardrobe/analytics/utilization-score")
    body = r.json()
    assert body["score"] == 50
    assert body["label"] == "Moderate"


# ---------------------------------------------------------------------------
# Weekly report (free teaser)
# ---------------------------------------------------------------------------


def test_weekly_report_returns_teaser_string(authed_client):
    r = authed_client.get("/api/v1/wardrobe/analytics/weekly-report")
    assert r.status_code == 200
    body = r.json()
    assert body["pro_teaser"]
    assert "outfits_logged" in body
    assert "streak_days" in body


# ---------------------------------------------------------------------------
# Intelligence report — Pro gate
# ---------------------------------------------------------------------------


def test_intelligence_report_free_user_returns_402(authed_client):
    """Free tier → 402 pro_required with the upsell payload."""
    r = authed_client.get("/api/v1/wardrobe/analytics/intelligence-report")
    assert r.status_code == 402
    detail = r.json()["detail"]
    assert detail["error"] == "pro_required"
    assert "message" in detail
    assert "feature" in detail


def test_intelligence_report_pro_user_returns_200(client, make_user, auth_headers, db):
    pro = make_user(email="pro@example.com", tier="pro")
    # Seed a few items so the report has something to roll up.
    for i in range(3):
        make_wardrobe_item(db, pro, name=f"Item {i}", color_name="navy")
    r = client.get(
        "/api/v1/wardrobe/analytics/intelligence-report",
        headers=auth_headers(pro),
    )
    assert r.status_code == 200
    body = r.json()
    assert body["total_items"] == 3
    assert "color_palette" in body
    assert "underutilized_items" in body
    assert "real_vs_starter_ratio" in body


def test_intelligence_report_admin_user_does_not_bypass_pro_gate(
    client, make_user, auth_headers
):
    """Admins are admins; that doesn't make them Pro. Confirm subscription_tier
    is the only signal `require_pro` reads."""
    admin = make_user(email="admin@example.com", role=Role.admin, tier="free")
    r = client.get(
        "/api/v1/wardrobe/analytics/intelligence-report",
        headers=auth_headers(admin),
    )
    assert r.status_code == 402


# ---------------------------------------------------------------------------
# Profile intelligence (8a)
# ---------------------------------------------------------------------------


def test_profile_intelligence_empty_wardrobe(authed_client):
    r = authed_client.get("/api/v1/profile/intelligence")
    assert r.status_code == 200
    body = r.json()
    assert body["utilization_score"] == 0
    assert body["average_cost_per_wear"] is None
    assert body["items_unworn_60d"] == 0
    assert body["wardrobe_value"] == 0.0
    assert body["items_total"] == 0


def test_profile_intelligence_aggregates(authed_client, db):
    """Two items: one priced+worn recently, one unpriced never worn.
    value=$120; avg cpw = 120/3=$40; 1 unworn 60d+; utilization 50%."""
    user = authed_client.test_user
    worn = make_wardrobe_item(
        db, user, name="Trousers", category="bottoms", purchase_price=120.0
    )
    make_wardrobe_item(db, user, name="Scarf", category="accessories")
    today = date.today()
    for offset in range(3):
        db.add(
            WardrobeWearLog(
                user_id=user.id,
                item_id=worn.id,
                worn_date=today - timedelta(days=offset),
                logged_at=__import__("datetime").datetime.now(),
            )
        )
    worn.worn_count = 3
    db.commit()

    r = authed_client.get("/api/v1/profile/intelligence")
    assert r.status_code == 200
    body = r.json()
    assert body["items_total"] == 2
    assert body["wardrobe_value"] == 120.0
    assert body["average_cost_per_wear"] == 40.0
    assert body["items_unworn_60d"] == 1
    assert body["utilization_score"] == 50
