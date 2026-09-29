"""catalog_service — feed diff into `products` (add / update / deactivate,
re-tag only on text changes, advertiser gender map) and one-at-a-time AI
tagging (round-robin order, validation fallbacks, outage handling)."""
from __future__ import annotations

import json
from dataclasses import replace

import pytest
from sqlalchemy import select

from app.db.models import Product
from app.services import catalog_service
from app.services.providers.affiliate.base import AffiliateProduct, AffiliateProvider
from app.services.providers.ai.base import AIProvider, AIProviderError


def _p(ext: str, **kw) -> AffiliateProduct:
    base = AffiliateProduct(
        external_id=ext, name=f"Item {ext}", brand="boohoo", category="tops",
        price_cents=2000, currency="USD", image_url=f"https://i/{ext}.jpg",
        product_url=f"https://p/{ext}", retailer="boohoo", advertiser_id="60703",
    )
    return replace(base, **kw)


class _Feed(AffiliateProvider):
    def __init__(self, *products: AffiliateProduct) -> None:
        self.products = list(products)

    def catalog(self):
        return list(self.products)

    def current_price_cents(self, external_id):
        return None


class _TagAI(AIProvider):
    def __init__(self, reply: dict | str | None = None, fail: bool = False) -> None:
        self.reply = reply if reply is not None else {
            "gender": "women", "role": "top", "warmth": "light",
            "formality": "casual", "occasions": ["casual", "brunch"], "color_name": "White",
        }
        self.fail = fail
        self.calls: list[str] = []

    async def chat(self, messages, *, model=None, system=None, max_tokens=1024, cache_system=False):
        self.calls.append(messages[-1]["content"])
        if self.fail:
            raise AIProviderError("overloaded", "busy")
        return self.reply if isinstance(self.reply, str) else json.dumps(self.reply)

    async def analyze_image(self, *a, **kw):
        raise NotImplementedError


def _rows(db) -> dict[str, Product]:
    db.expire_all()
    return {p.external_id: p for p in db.scalars(select(Product)).all()}


def test_sync_adds_updates_and_deactivates(db):
    feed = _Feed(_p("a"), _p("b"))
    assert catalog_service.sync_catalog(db, affiliate=feed).added == 2

    feed.products = [_p("b", price_cents=1500), _p("c")]
    result = catalog_service.sync_catalog(db, affiliate=feed)
    assert (result.added, result.updated, result.deactivated) == (1, 1, 1)
    rows = _rows(db)
    assert rows["a"].is_active is False  # kept for wardrobe/wishlist links
    assert rows["b"].price_cents == 1500 and rows["c"].is_active

    feed.products = [_p("a"), _p("b", price_cents=1500), _p("c")]
    catalog_service.sync_catalog(db, affiliate=feed)
    assert _rows(db)["a"].is_active is True  # back in the feed


def test_rename_retags_but_price_change_does_not(db):
    feed = _Feed(_p("a"))
    catalog_service.sync_catalog(db, affiliate=feed)
    row = _rows(db)["a"]
    row.tagged_at = row.created_at
    db.commit()

    feed.products = [_p("a", price_cents=999)]
    catalog_service.sync_catalog(db, affiliate=feed)
    assert _rows(db)["a"].tagged_at is not None

    feed.products = [_p("a", name="Item a (new season)")]
    catalog_service.sync_catalog(db, affiliate=feed)
    assert _rows(db)["a"].tagged_at is None


def test_advertiser_gender_map_sets_gender_at_sync(db):
    feed = _Feed(_p("m", advertiser_id="60701"), _p("w", advertiser_id="60703"), _p("x", advertiser_id="1"))
    catalog_service.sync_catalog(
        db, affiliate=feed, advertiser_genders={"60701": "men", "60703": "women"}
    )
    rows = _rows(db)
    assert (rows["m"].gender, rows["w"].gender, rows["x"].gender) == ("men", "women", None)


def test_failed_feed_load_leaves_the_table_alone(db):
    catalog_service.sync_catalog(db, affiliate=_Feed(_p("a")))

    class _Down(_Feed):
        def catalog(self):
            raise RuntimeError("feed down")

    with pytest.raises(RuntimeError):
        catalog_service.sync_catalog(db, affiliate=_Down())
    assert _rows(db)["a"].is_active is True


async def test_tag_next_tags_one_product_with_validated_tags(db):
    catalog_service.sync_catalog(
        db, affiliate=_Feed(_p("a"), _p("b")), advertiser_genders={"60703": "women"}
    )
    ai = _TagAI()
    row = await catalog_service.tag_next(db, ai=ai, model="claude-haiku-4-5-20251001")
    assert len(ai.calls) == 1 and "Item" in ai.calls[0]
    assert (row.role, row.warmth, row.formality, row.color_name) == ("top", "light", "casual", "White")
    assert row.occasions == ["casual"]  # "brunch" is off-vocabulary
    assert row.gender == "women" and row.tagged_at is not None
    assert sum(1 for p in _rows(db).values() if p.tagged_at) == 1


async def test_tagging_round_robins_across_categories(db):
    feed = _Feed(*[_p(f"t{i}") for i in range(3)], _p("s", category="shoes"), _p("d", category="dresses"))
    catalog_service.sync_catalog(db, affiliate=feed)
    first_three = [(await catalog_service.tag_next(db, ai=_TagAI())).category for _ in range(3)]
    assert sorted(first_three) == ["dresses", "shoes", "tops"]


async def test_unparseable_reply_tags_from_the_feed_category(db):
    catalog_service.sync_catalog(db, affiliate=_Feed(_p("s", category="shoes")))
    row = await catalog_service.tag_next(db, ai=_TagAI(reply="sorry, no idea"))
    assert (row.role, row.warmth, row.formality, row.gender) == ("shoes", "mid", "casual", "unisex")
    assert row.occasions == ["casual"]


async def test_ai_cannot_turn_shoes_into_apparel(db):
    catalog_service.sync_catalog(db, affiliate=_Feed(_p("s", category="shoes")))
    row = await catalog_service.tag_next(db, ai=_TagAI(reply={"role": "dress"}))
    assert row.role == "shoes"


async def test_ai_outage_leaves_the_product_untagged(db):
    catalog_service.sync_catalog(db, affiliate=_Feed(_p("a")))
    with pytest.raises(AIProviderError):
        await catalog_service.tag_next(db, ai=_TagAI(fail=True))
    assert _rows(db)["a"].tagged_at is None


async def test_nothing_to_tag_returns_none(db):
    assert await catalog_service.tag_next(db, ai=_TagAI()) is None
