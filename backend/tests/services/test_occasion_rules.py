"""The occasion rulebook (app/data/occasion_rules.yaml) and how outfit
generation applies it.

REGRESSION_CASES is where reported bugs land: when an outfit was judged
wrong, fix the rulebook and add the case here, so it stays fixed.
"""
from __future__ import annotations

import json
import re

import pytest
from pydantic import ValidationError

from app.data import occasion_rules as rules
from app.schemas.outfit import payload_to_outfit_items
from app.services import outfit_service
from tests.factories import make_wardrobe_item
from tests.services.test_outfit_shop_fill import _PickAll, _Weather

ALL_ROLES = {"top", "bottom", "dress", "outerwear", "shoes", "accessory"}


def is_complete(occasion: str, audience: str | None, roles: set[str]) -> bool:
    rule = rules.rule_for(occasion, audience)
    return not rules.missing_roles(rule, roles, ALL_ROLES) and not rules.clashes(roles)


# (occasion, shopping style, outfit roles, complete?, why)
REGRESSION_CASES = [
    ("date_night", "mens", {"bottom", "accessory"}, False,
     "trousers + a star belt was shown as a date-night outfit (no top, no shoes)"),
    ("date_night", "mens", {"top", "bottom", "shoes"}, True, "the basic date-night look"),
    ("date_night", "mens", {"dress", "shoes"}, False, "menswear date night is separates"),
    ("date_night", "womens", {"dress", "shoes"}, True, "a dress with boots is complete"),
    ("date_night", "womens", {"dress", "bottom", "shoes"}, False,
     "a dress was paired with jeans"),
    ("beach", "mens", {"bottom"}, True, "swim shorts alone are fine at the beach"),
    ("beach", "womens", {"dress"}, True, "a sundress on its own"),
    ("beach", "womens", {"bottom"}, False, "womenswear beach needs a top with shorts"),
    ("gym", None, {"top", "bottom"}, False, "gym needs trainers"),
    ("wedding_guest", "mens", {"top", "bottom", "outerwear", "shoes"}, True, "suit or blazer"),
    ("wedding_guest", "mens", {"top", "bottom", "shoes"}, True, "warm-weather wedding"),
    ("work", "mens", {"top", "bottom"}, False, "no shoes"),
    ("work", None, {"dress", "shoes"}, True, "a dress is a work outfit"),
]


@pytest.mark.parametrize(
    "occasion,audience,roles,complete,why",
    REGRESSION_CASES,
    ids=[f"{c[0]}-{c[1]}-{'+'.join(sorted(c[2]))}" for c in REGRESSION_CASES],
)
def test_regression_cases(occasion, audience, roles, complete, why):
    assert is_complete(occasion, audience, roles) is complete, why


# ---------------------------------------------------------------------------
# The file itself
# ---------------------------------------------------------------------------


def test_every_occasion_has_a_label_and_the_daily_three_are_first():
    keys = rules.occasion_keys()
    assert keys[:3] == ["work", "casual", "date_night"]
    assert rules.daily_occasions() == ("work", "casual", "date_night")
    assert {"gym", "beach", "wedding_guest", "night_out", "interview", "travel", "other"} <= set(keys)
    # Labels are the keys title-cased, so the app can label any occasion.
    assert all(rules.label(k) == k.replace("_", " ").title() for k in keys)


def test_audience_overrides_replace_only_what_they_list():
    base = rules.rule_for("wedding_guest", None)
    womens = rules.rule_for("wedding_guest", "womens")
    assert womens.complete_when == base.complete_when  # not overridden
    assert "white, ivory or cream (the bride's colours)" in womens.avoid
    assert rules.rule_for("wedding_guest", "both") == base  # "both" -> base rule


def test_a_bad_rule_file_is_rejected():
    with pytest.raises(ValidationError):
        rules.RulesFile.model_validate(
            {"occasions": {"x": {"label": "X", "rule": {"complete_when": [["hat"]]}}}}
        )
    with pytest.raises(ValidationError):  # typo'd key
        rules.RulesFile.model_validate(
            {"occasions": {"x": {"label": "X", "rule": {"complete_whn": [["top"]]}}}}
        )


def test_missing_roles_picks_the_nearest_completable_shape():
    rule = rules.rule_for("date_night", "womens")
    assert rules.missing_roles(rule, {"top"}, ALL_ROLES) == ["bottom", "shoes"]
    assert rules.missing_roles(rule, {"dress"}, ALL_ROLES) == ["shoes"]
    # Only a dress-shaped completion is on offer.
    assert rules.missing_roles(rule, {"top"}, {"dress", "shoes"}) == ["dress", "shoes"]
    # Nothing on offer brings it closer: nothing to ask for.
    assert rules.missing_roles(rule, {"top"}, {"top"}) == []
    # No shoes anywhere, but a top is on offer: still ask for the top.
    wedding = rules.rule_for("wedding_guest", "mens")
    assert rules.missing_roles(
        wedding, {"bottom", "outerwear"}, {"top", "bottom", "outerwear", "accessory"}
    ) == ["top"]


def test_gap_offers_every_nearest_shape():
    rule = rules.rule_for("date_night", "womens")
    assert rules.gap(rule, {"top"}) == (["bottom", "shoes", "dress"], 2)
    assert rules.gap(rule, {"top", "bottom", "shoes"}) == ([], 0)


def test_prompt_block_reads_like_the_rulebook():
    block = rules.prompt_block("beach", rules.rule_for("beach", "mens"))
    assert block.startswith("Occasion: Beach.")
    assert "A complete outfit for it is: bottom." in block
    assert "Swim or linen shorts on their own are fine" in block


# ---------------------------------------------------------------------------
# Generation applies the rulebook
# ---------------------------------------------------------------------------


class _Scripted(_PickAll):
    """Answers each call with the next list of item names; records prompts."""

    def __init__(self, *picks: list[str]) -> None:
        super().__init__()
        self.picks = list(picks)
        self.prompts: list[str] = []

    async def chat(self, messages, *, model=None, system=None, max_tokens=1024, cache_system=False):
        self.prompts.append(messages[-1]["content"])
        refs = {name: ref for ref, name in re.findall(r'id=(\d+) name="([^"]+)"', system or "")}
        return json.dumps({
            "occasion": "casual",
            "item_ids": [refs[n] for n in self.picks.pop(0)],
            "reasoning_short": "s",
            "reasoning_full": "f",
            "compatibility_score": 80,
        })


def _wardrobe(db, user):
    for category, name in (("tops", "Tee"), ("bottoms", "Shorts"), ("shoes", "Sandals"),
                           ("accessories", "Belt")):
        make_wardrobe_item(db, user, name=name, category=category)


async def _generate(db, user, ai, occasion):
    outfit = await outfit_service.generate_one(
        db=db, user=user, ai=ai, weather=_Weather(24.0), occasion=occasion
    )
    return {i.name for i in payload_to_outfit_items(outfit.items)}


async def test_prompt_carries_the_occasions_rule(db, make_user):
    user = make_user()
    _wardrobe(db, user)
    ai = _Scripted(["Tee", "Shorts", "Sandals"])
    await _generate(db, user, ai, "casual")
    assert "Occasion: Casual.\nA complete outfit for it is: top + bottom + shoes" in ai.prompts[0]


async def test_incomplete_outfit_is_retried_with_what_the_rule_needs(db, make_user):
    user = make_user()
    _wardrobe(db, user)
    ai = _Scripted(["Shorts", "Belt"], ["Tee", "Shorts", "Sandals"])
    assert await _generate(db, user, ai, "casual") == {"Tee", "Shorts", "Sandals"}
    assert "A previous attempt left out: top and shoes." in ai.prompts[1]


async def test_still_incomplete_gets_a_rule_shaped_fallback(db, make_user):
    user = make_user()
    _wardrobe(db, user)
    ai = _Scripted(["Shorts", "Belt"], ["Shorts", "Belt"])
    assert await _generate(db, user, ai, "casual") == {"Tee", "Shorts", "Sandals"}


def test_fallback_fills_the_nearest_shape_when_none_fits():
    from app.db.models import WardrobeItem
    import uuid

    def item(category, name):
        return WardrobeItem(id=uuid.uuid4(), user_id=uuid.uuid4(), name=name,
                            category=category, is_starter_wardrobe=False)

    # Menswear wedding with no shoes: top + trousers + blazer, not two random pieces.
    items = [item("bottoms", "Trousers"), item("outerwear", "Blazer"), item("tops", "Shirt"),
             item("accessories", "Belt")]
    rule = rules.rule_for("wedding_guest", "mens")
    names = {i.name for i in outfit_service._heuristic_pick(items, rule)}
    assert names == {"Shirt", "Trousers", "Blazer"}


async def test_menswear_beach_shorts_alone_need_no_retry(db, make_user):
    user = make_user()
    user.shopping_style = "mens"
    db.commit()
    _wardrobe(db, user)
    make_wardrobe_item(db, user, name="Linen Shorts", category="bottoms")
    ai = _Scripted(["Shorts", "Tee"])
    assert await _generate(db, user, ai, "beach") == {"Shorts", "Tee"}
    assert len(ai.prompts) == 1


def test_unknown_occasion_is_rejected(authed_client):
    r = authed_client.post("/api/v1/today/outfits", json={"occasion": "moon_landing"})
    assert r.status_code == 422
    assert "unknown occasion" in r.text


def test_today_frame_lists_every_occasion(authed_client):
    frame = authed_client.get("/api/v1/today/dashboard").json()
    occasions = frame["occasions"]
    assert [o["key"] for o in occasions] == rules.occasion_keys()
    assert {o["key"] for o in occasions if o["daily"]} == {"work", "casual", "date_night"}
    assert {"key": "wedding_guest", "label": "Wedding Guest", "daily": False} in occasions
