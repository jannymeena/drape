"""Shop routes (2.4, items 7a-7e) — feed sync/ordering, advisor with
structured suggestions + weekly limit, buy/don't-buy verdict + limit,
gap-analysis teaser vs Pro, wishlist with price drops."""
from __future__ import annotations

import io
import json

from app.api.dependencies.providers import get_ai_provider
from app.main import app
from app.services.providers.ai.base import AIProvider
from tests.factories import make_wardrobe_item


class _ShopAI(AIProvider):
    """Deterministic advisor/buy-check responses."""

    def __init__(self, chat_json=None, image_json=None):
        self._chat = chat_json or {
            "reply": "Linen layers will beat the heat.",
            "suggestions": [
                {"name": "Linen shirt", "category": "tops", "reason": "Breathable."},
                {"name": "Loafers", "category": "shoes", "reason": "Smart casual."},
            ],
        }
        self._image = image_json or {
            "verdict": "dont_buy",
            "score": 34,
            "fit_reason": "Boxy cut fights your usual silhouettes.",
            "value_reason": "High cost-per-wear for one occasion.",
            "gap_reason": "You already own three similar tops.",
        }

    async def chat(self, messages, *, model=None, system=None, max_tokens=1024, cache_system=False):
        return json.dumps(self._chat)

    async def analyze_image(self, image_bytes, prompt, *, media_type="image/jpeg"):
        return json.dumps(self._image)


def _use_shop_ai(**kwargs):
    app.dependency_overrides[get_ai_provider] = lambda: _ShopAI(**kwargs)


def _png() -> tuple[str, io.BytesIO, str]:
    return ("look.png", io.BytesIO(b"\x89PNG fake image bytes"), "image/png")


# --- 7a feed ---------------------------------------------------------------


def test_feed_syncs_catalog_and_flags_measurements(authed_client):
    r = authed_client.get("/api/v1/shop/feed")
    assert r.status_code == 200, r.text
    body = r.json()
    assert len(body["products"]) == 12  # mock catalog
    assert body["measurements_complete"] is False


def test_feed_orders_thin_categories_first(authed_client, db):
    for i in range(6):
        make_wardrobe_item(db, authed_client.test_user, name=f"Top {i}", category="tops")
    r = authed_client.get("/api/v1/shop/feed")
    products = r.json()["products"]
    # Categories the user owns plenty of sink to the end of the feed.
    assert products[-1]["category"] == "tops"
    assert products[0]["category"] != "tops"


# --- 7b advisor --------------------------------------------------------------


def test_advisor_ask_returns_reply_and_matched_products(authed_client):
    _use_shop_ai()
    r = authed_client.post(
        "/api/v1/shop/advisor/ask", json={"question": "What do I wear to a summer wedding?"}
    )
    assert r.status_code == 200, r.text
    convo = r.json()
    assert convo["title"].startswith("What do I wear")
    assert len(convo["messages"]) == 2
    reply = convo["messages"][1]
    assert reply["content"] == "Linen layers will beat the heat."
    sugs = reply["suggestions"]
    assert {s["category"] for s in sugs} == {"tops", "shoes"}
    assert all(s["product_id"] for s in sugs)  # matched to catalog products

    # Follow-up lands in the same conversation.
    r = authed_client.post(
        "/api/v1/shop/advisor/ask",
        json={"question": "And for the evening?", "conversation_id": convo["id"]},
    )
    assert len(r.json()["messages"]) == 4

    history = authed_client.get("/api/v1/shop/advisor/history").json()
    assert len(history["conversations"]) == 1


def test_advisor_weekly_limit_429_with_plans(authed_client):
    _use_shop_ai()
    for _ in range(10):
        r = authed_client.post(
            "/api/v1/shop/advisor/ask", json={"question": "hi"}
        )
        assert r.status_code == 200
    r = authed_client.post("/api/v1/shop/advisor/ask", json={"question": "one more"})
    assert r.status_code == 429
    detail = r.json()["detail"]
    assert detail["resource"] == "advisor"
    assert detail["plans"]


# --- 7c buy / don't buy -------------------------------------------------------


def test_buy_check_verdict_and_history(authed_client):
    _use_shop_ai()
    r = authed_client.post(
        "/api/v1/shop/buy-check",
        files={"file": _png()},
        data={"product_name": "Boxy Linen Top"},
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["verdict"] == "dont_buy"
    assert body["score"] == 34
    assert "silhouettes" in body["fit_reason"]

    history = authed_client.get("/api/v1/shop/buy-check/history").json()
    assert len(history["checks"]) == 1
    assert history["checks"][0]["product_name"] == "Boxy Linen Top"


def test_buy_check_weekly_limit_of_five(authed_client):
    _use_shop_ai()
    for _ in range(5):
        r = authed_client.post("/api/v1/shop/buy-check", files={"file": _png()})
        assert r.status_code == 200
    r = authed_client.post("/api/v1/shop/buy-check", files={"file": _png()})
    assert r.status_code == 429
    assert r.json()["detail"]["resource"] == "buy_dont_buy"


def test_buy_check_unparseable_ai_degrades_not_500(authed_client):
    app.dependency_overrides[get_ai_provider] = lambda: _BrokenAI()
    r = authed_client.post("/api/v1/shop/buy-check", files={"file": _png()})
    assert r.status_code == 200
    assert r.json()["verdict"] == "buy"  # neutral fallback
    assert r.json()["score"] == 50


class _BrokenAI(AIProvider):
    async def chat(self, messages, *, model=None, system=None, max_tokens=1024, cache_system=False):
        return "not json at all"

    async def analyze_image(self, image_bytes, prompt, *, media_type="image/jpeg"):
        return "not json at all"


# --- 7d gap analysis -----------------------------------------------------------


def test_gap_analysis_free_tier_is_teaser(authed_client):
    r = authed_client.get("/api/v1/shop/gap-analysis")
    assert r.status_code == 200
    body = r.json()
    assert len(body["gaps"]) == 1  # empty wardrobe has 4 gaps; free sees top 1
    assert body["is_teaser"] is True
    assert "3 more gaps" in body["pro_teaser"]


def test_gap_analysis_pro_gets_full_list_and_unlock_counts(authed_client, db):
    authed_client.post("/api/v1/subscription/upgrade", json={"plan": "pro_monthly"})
    for i in range(2):
        make_wardrobe_item(db, authed_client.test_user, name=f"Top {i}", category="tops")
    for i in range(2):
        make_wardrobe_item(db, authed_client.test_user, name=f"Shoe {i}", category="shoes")

    body = authed_client.get("/api/v1/shop/gap-analysis").json()
    assert body["is_teaser"] is False
    by_cat = {g["category"]: g for g in body["gaps"]}
    # bottoms: combines with tops (2) * shoes (2) = 4 outfits unlocked.
    assert by_cat["bottoms"]["outfits_unlocked"] == 4
    assert by_cat["bottoms"]["have"] == 0


# --- 7e wishlist -----------------------------------------------------------------


def test_wishlist_add_list_remove_with_price_drop(authed_client):
    products = authed_client.get("/api/v1/shop/feed").json()["products"]
    coat = next(p for p in products if p["name"] == "Camel Overcoat")

    r = authed_client.post("/api/v1/shop/wishlist", json={"product_id": coat["id"]})
    assert r.status_code == 201, r.text
    items = r.json()["items"]
    assert len(items) == 1
    entry = items[0]
    # mock_009 has a live price below catalog -> a drop.
    assert entry["added_price_cents"] == 29000
    assert entry["current_price_cents"] == 23200
    assert entry["price_drop_cents"] == 5800

    r = authed_client.delete(f"/api/v1/shop/wishlist/{coat['id']}")
    assert r.status_code == 204
    assert authed_client.get("/api/v1/shop/wishlist").json()["items"] == []
    r = authed_client.delete(f"/api/v1/shop/wishlist/{coat['id']}")
    assert r.status_code == 404


def test_wishlist_add_unknown_product_404(authed_client):
    r = authed_client.post(
        "/api/v1/shop/wishlist",
        json={"product_id": "00000000-0000-0000-0000-000000000000"},
    )
    assert r.status_code == 404
