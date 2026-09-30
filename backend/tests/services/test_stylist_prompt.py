"""The personal-stylist prompt: expertise + who the wearer is + what each item
actually is, today's date, and code guards against a dress worn with jeans."""
from __future__ import annotations

import json
import re
import uuid
from datetime import date

from app.db.models import WardrobeItem
from app.schemas.outfit import OutfitItem, payload_to_outfit_items
from app.schemas.wardrobe import AIDetection
from app.data import occasion_rules
from app.services import outfit_service, stylist_prompt
from tests.factories import make_wardrobe_item
from tests.services.test_outfit_shop_fill import _PickAll, _Weather


def _item(category: str, name: str, **kw) -> WardrobeItem:
    return WardrobeItem(
        id=uuid.uuid4(), user_id=uuid.uuid4(), name=name, category=category,
        formality="casual", is_starter_wardrobe=False, **kw,
    )


def test_system_prompt_is_a_personal_stylist_who_knows_the_wearer():
    system = outfit_service._build_system_context(
        items=[
            _item(
                "shoes", "Black Boots", subcategory="ankle boots", color_name="black",
                material="leather", season=["fall", "winter"],
            )
        ],
        style_goals=["look polished"],
        using_starter_wardrobe=False,
        shopping_style="womens",
        age_range="45-54",
        style_profile={"body_shape": "pear", "undertone": "warm", "occupation": "Nurse"},
    )
    assert "personal stylist" in system
    assert stylist_prompt.STYLIST_EXPERTISE in system
    assert "Never put trousers, jeans or a skirt with a dress" in system
    assert "Shops for: womenswear." in system
    assert "Age range: 45-54." in system
    assert "body shape: pear." in system
    assert "undertone: warm." in system
    assert "Nurse" not in system  # occupation stays out
    assert (
        'id=1 name="Black Boots" '
        "[shoes | ankle boots | black | casual | leather | fall/winter]"
    ) in system


def test_undisclosed_age_is_left_out():
    about = stylist_prompt.about_the_user(age_range="prefer_not_to_say")
    assert "Age range" not in about


def test_user_prompt_carries_todays_date():
    prompt = outfit_service._build_user_prompt(
        occasion="casual", weather=None, today=date(2026, 10, 1)
    )
    assert prompt.startswith("Build ONE outfit for the occasion: casual.")
    assert "Today is Thursday 1 October 2026." in prompt


def test_advisor_shares_the_stylist_brief(authed_client, db):
    from tests.api.routes.test_shop import _ShopAI, _use_shop_ai

    user = authed_client.test_user
    user.age_range = "35-44"
    db.commit()
    _use_shop_ai()
    authed_client.post("/api/v1/shop/advisor/ask", json={"question": "Dinner look?"})
    system = _ShopAI.calls[-1]["system"]
    assert stylist_prompt.STYLIST_EXPERTISE in system
    assert "Age range: 35-44." in system


# ---------------------------------------------------------------------------
# Dress guards
# ---------------------------------------------------------------------------


def test_fallback_never_pairs_a_dress_with_separates():
    items = [_item("dresses", "Dress"), _item("tops", "Tee"), _item("bottoms", "Jeans"),
             _item("shoes", "Boots")]
    rule = occasion_rules.rule_for("casual", "womens")
    names = {i.name for i in outfit_service._heuristic_pick(items, rule)}
    assert names == {"Tee", "Jeans", "Boots"}


def test_fallback_uses_the_dress_when_separates_are_incomplete():
    items = [_item("dresses", "Dress"), _item("tops", "Tee"), _item("shoes", "Boots")]
    rule = occasion_rules.rule_for("casual", "womens")
    names = {i.name for i in outfit_service._heuristic_pick(items, rule)}
    assert names == {"Dress", "Boots"}


def test_bottoms_are_dropped_from_a_dress_outfit():
    def oi(category: str, name: str) -> OutfitItem:
        return OutfitItem(item_id=uuid.uuid4(), name=name, category=category)

    kept = outfit_service._drop_clashes(
        [oi("dresses", "Dress"), oi("bottoms", "Jeans"), oi("shoes", "Boots")]
    )
    assert [i.name for i in kept] == ["Dress", "Boots"]


class _DressWithJeans(_PickAll):
    """An AI slip: dress + jeans + boots."""

    async def chat(self, messages, *, model=None, system=None, max_tokens=1024, cache_system=False):
        refs = dict(
            (name, ref) for ref, name in re.findall(r'id=(\d+) name="([^"]+)"', system or "")
        )
        return json.dumps(
            {
                "occasion": "casual",
                "item_ids": [refs["Dress"], refs["Jeans"], refs["Boots"]],
                "reasoning_short": "s",
                "reasoning_full": "f",
                "compatibility_score": 80,
            }
        )


async def test_generated_dress_outfit_never_keeps_jeans(db, make_user):
    user = make_user()
    for category, name in (("dresses", "Dress"), ("bottoms", "Jeans"), ("shoes", "Boots")):
        make_wardrobe_item(db, user, name=name, category=category)
    outfit = await outfit_service.generate_one(
        db=db, user=user, ai=_DressWithJeans(), weather=_Weather(15.0), occasion="casual"
    )
    assert {i.name for i in payload_to_outfit_items(outfit.items)} == {"Dress", "Boots"}


# ---------------------------------------------------------------------------
# Scanner garment type
# ---------------------------------------------------------------------------


def test_detection_subcategory_is_tidied_not_fatal():
    base = dict(category="shoes", color="black", pattern="solid", formality="casual",
                confidence=90)
    assert AIDetection(**base, subcategory="  Ankle Boots ").subcategory == "ankle boots"
    assert len(AIDetection(**base, subcategory="x" * 80).subcategory) == 50
    assert AIDetection(**base, subcategory=["boots"]).subcategory is None
    assert AIDetection(**base).subcategory is None
