"""AWIN products in outfit generation: wardrobe first, shop products only for
gaps (whole outfits for an empty wardrobe), creative picks on regenerate,
caps enforced in code, gender respected, and "shop the look" outfits refused
by log."""
from __future__ import annotations

import json
import re

import pytest

from app.services import outfit_service
from app.services.outfit_service import OutfitError
from app.services.providers.ai.base import AIProvider
from app.services.providers.weather.base import WeatherProvider, WeatherSnapshot
from app.schemas.outfit import payload_to_outfit_items
from tests.factories import make_catalog, make_wardrobe_item

_ID_RE = re.compile(r"id=(S?\d+)")


class _PickAll(AIProvider):
    """Returns every id it was offered — wardrobe (system) and shop (prompt) —
    so the code-side caps are what's under test."""

    def __init__(self) -> None:
        self.prompt = ""
        self.system = ""

    async def chat(self, messages, *, model=None, system=None, max_tokens=1024, cache_system=False):
        self.prompt = messages[-1]["content"]
        self.system = system or ""
        # Within the schema's 8-id limit: up to 4 owned + 4 shop.
        ids = _ID_RE.findall(system or "")[:4] + self.shop_ids[:4]
        return json.dumps(
            {
                "occasion": "work",
                "item_ids": ids,
                "reasoning_short": "Sharp.",
                "reasoning_full": "Sharp and simple.",
                "per_item_rationales": {},
                "compatibility_score": 80,
                "factors": [],
            }
        )

    async def analyze_image(self, image_bytes, prompt, *, media_type="image/jpeg", model=None, max_tokens=1024):
        raise NotImplementedError

    @property
    def shop_ids(self) -> list[str]:
        shop = self.prompt.split("Shop products", 1)
        return _ID_RE.findall(shop[1]) if len(shop) == 2 else []


class _Weather(WeatherProvider):
    def __init__(self, feels_like_c: float = 18.0) -> None:
        self.feels = feels_like_c

    async def current(self, lat, lon):
        return WeatherSnapshot(
            temp_c=self.feels, feels_like_c=self.feels, condition="clear",
            humidity_pct=50, wind_kph=5.0,
        )


async def _generate(db, user, *, feels=18.0, ai=None, **kw):
    ai = ai or _PickAll()
    outfit = await outfit_service.generate_one(
        db=db, user=user, ai=ai, weather=_Weather(feels), occasion="work", **kw
    )
    return outfit, payload_to_outfit_items(outfit.items), ai


def _full_wardrobe(db, user):
    for cat in ("tops", "bottoms", "shoes", "outerwear"):
        make_wardrobe_item(db, user, name=f"My {cat}", category=cat, formality="smart_casual")


async def test_wardrobe_that_covers_the_look_gets_no_shop_products(db, make_user):
    user = make_user()
    make_catalog(db)
    _full_wardrobe(db, user)
    outfit, items, ai = await _generate(db, user, feels=5.0)
    assert "Shop products" not in ai.prompt
    assert all(i.product_url is None for i in items)


async def test_missing_bottom_is_filled_by_one_shop_piece(db, make_user):
    user = make_user()
    make_catalog(db)
    make_wardrobe_item(db, user, name="My shirt", category="tops", formality="smart_casual")
    make_wardrobe_item(db, user, name="My shoes", category="shoes", formality="smart_casual")
    _, items, ai = await _generate(db, user)
    assert ai.shop_ids  # bottoms (and dresses, for womenswear) offered
    shop = [i for i in items if i.product_url]
    assert len(shop) == 1  # the AI returned several; the cap kept one
    assert shop[0].price_cents and shop[0].retailer
    assert {i.name for i in items if not i.product_url} == {"My shirt", "My shoes"}


async def test_cold_weather_adds_outerwear_and_missing_shoes_to_the_gap(db, make_user):
    user = make_user()
    make_catalog(db)
    make_wardrobe_item(db, user, name="My shirt", category="tops", formality="smart_casual")
    make_wardrobe_item(db, user, name="My jeans", category="bottoms", formality="smart_casual")
    _, items, ai = await _generate(db, user, feels=3.0)
    shop = [i for i in items if i.product_url]
    # No shoes of their own: a complete outfit needs a pair from the shop.
    assert sorted(i.category for i in shop) == ["outerwear", "shoes"]


async def test_empty_wardrobe_gets_a_whole_outfit_in_the_users_gender(db, make_user):
    user = make_user(shopping_style="mens")
    make_catalog(db)
    outfit, items, _ = await _generate(db, user)
    assert len(items) >= 2 and all(i.product_url for i in items)
    assert all(i.name.startswith("Men ") for i in items)
    assert "|" not in items[0].name
    assert not any(i.category in ("dresses", "shoes") for i in items)


async def test_regenerate_mixes_in_at_most_two_new_pieces(db, make_user):
    user = make_user()
    make_catalog(db)
    _full_wardrobe(db, user)
    _, items, ai = await _generate(db, user, feels=5.0, creative=True)
    assert "something new" in ai.prompt
    assert len([i for i in items if i.product_url]) == 2


async def test_untagged_products_are_never_offered(db, make_user):
    user = make_user()
    make_catalog(db, tagged=False)
    with pytest.raises(OutfitError) as exc:
        await _generate(db, user)
    assert exc.value.code == "no_wardrobe"


async def test_starter_items_carry_their_buy_link(db, make_user, client):
    user = make_user()
    make_catalog(db)
    from app.services import starter_wardrobe_service

    starter_wardrobe_service.assign(db, user=user)
    _, items, _ = await _generate(db, user)
    assert items and all(i.is_starter_wardrobe and i.product_url for i in items)


async def test_shop_the_look_outfit_cannot_be_logged(db, make_user):
    user = make_user()
    make_catalog(db)
    outfit, _, _ = await _generate(db, user)
    with pytest.raises(OutfitError) as exc:
        outfit_service.log_outfit(db, user=user, outfit_id=outfit.id)
    assert exc.value.code == "shop_the_look"


def test_dashboard_is_ready_with_catalog_but_no_wardrobe(db, make_user):
    user = make_user()
    assert outfit_service.wardrobe_ready(db, user=user) is False
    make_catalog(db)
    assert outfit_service.wardrobe_ready(db, user=user) is True
    assert outfit_service.pending_occasions(db, user=user) == ["work", "casual", "date_night"]



class _OnePerCategory(_PickAll):
    """Picks the first offered item of each category, like a stylist would."""

    _LINE_RE = re.compile(r'id=(\d+) name="[^"]*" \[(\w+)')

    async def chat(self, messages, *, model=None, system=None, max_tokens=1024, cache_system=False):
        self.prompt, self.system = messages[-1]["content"], system or ""
        first: dict[str, str] = {}
        for ref, category in self._LINE_RE.findall(system or ""):
            first.setdefault(category, ref)
        return json.dumps(
            {
                "occasion": "work",
                "item_ids": list(first.values()),
                "reasoning_short": "Sharp.",
                "reasoning_full": "Sharp and simple.",
                "compatibility_score": 80,
            }
        )


async def test_later_sections_are_told_what_earlier_ones_wear(db, make_user):
    """Today's sections are built one after another; each later prompt lists
    what the earlier ones use, so the stylist can avoid repeating them."""
    user = make_user()
    for n in (1, 2):
        make_wardrobe_item(db, user, name=f"Top {n}", category="tops")
        make_wardrobe_item(db, user, name=f"Bottom {n}", category="bottoms")
    make_wardrobe_item(db, user, name="Only shoes", category="shoes")

    await _generate(db, user, feels=15.0, ai=_OnePerCategory())
    ai = _OnePerCategory()
    await outfit_service.generate_one(
        db=db, user=user, ai=ai, weather=_Weather(15.0), occasion="casual"
    )
    assert "Today's other outfits already use — Work: " in ai.prompt
    assert "shoes and accessories can repeat" in ai.prompt
