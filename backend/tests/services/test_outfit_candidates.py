"""The wardrobe slice sent to the outfit AI: weather + recent-wear filters that
never empty a category, a per-category cap, and short prompt refs."""
from __future__ import annotations

import json
import uuid
from datetime import date, timedelta

import pytest

from app.db.models import WardrobeItem
from app.services import outfit_service
from app.services.outfit_service import OutfitError, _select_candidates
from app.services.providers.weather.base import WeatherSnapshot

TODAY = date(2026, 9, 30)


def _item(
    category: str = "tops",
    *,
    name: str = "Item",
    season: list[str] | None = None,
    last_worn: date | None = None,
    is_favorite: bool = False,
    is_starter: bool = False,
) -> WardrobeItem:
    return WardrobeItem(
        id=uuid.uuid4(),
        user_id=uuid.uuid4(),
        name=name,
        category=category,
        formality="casual",
        season=season,
        last_worn=last_worn,
        is_favorite=is_favorite,
        is_starter_wardrobe=is_starter,
    )


def _weather(feels_like_c: float) -> WeatherSnapshot:
    return WeatherSnapshot(
        temp_c=feels_like_c, feels_like_c=feels_like_c, condition="clear",
        humidity_pct=50, wind_kph=5.0,
    )


def _select(items, *, weather=None, occasion="casual"):
    return _select_candidates(items, occasion=occasion, weather=weather, today=TODAY)


def test_caps_each_category():
    tops = [_item("tops", name=f"Top {n}") for n in range(20)]
    shoes = [_item("shoes", name=f"Shoe {n}") for n in range(10)]
    picked = _select(tops + shoes)
    assert sum(1 for i in picked if i.category == "tops") == 8
    assert sum(1 for i in picked if i.category == "shoes") == 4


def test_least_recently_worn_first_with_favorites_breaking_ties():
    old = _item(name="old", last_worn=TODAY - timedelta(days=30))
    newer = _item(name="newer", last_worn=TODAY - timedelta(days=5))
    never = _item(name="never")
    never_fav = _item(name="never-fav", is_favorite=True)
    picked = [i.name for i in _select([newer, old, never, never_fav])]
    assert picked == ["never-fav", "never", "old", "newer"]


def test_own_items_rank_before_starter_items():
    starter = [_item(name=f"starter {n}", is_starter=True) for n in range(8)]
    own = _item(name="mine", last_worn=TODAY - timedelta(days=3))
    picked = _select([*starter, own])
    assert picked[0].name == "mine"


def test_recently_worn_items_are_held_back():
    worn_today = _item(name="today", last_worn=TODAY)
    worn_yesterday = _item(name="yesterday", last_worn=TODAY - timedelta(days=1))
    fresh = _item(name="fresh", last_worn=TODAY - timedelta(days=2))
    picked = [i.name for i in _select([worn_today, worn_yesterday, fresh])]
    assert picked == ["fresh"]


def test_recent_wear_filter_never_empties_a_category():
    only_shoes = _item("shoes", name="only shoes", last_worn=TODAY)
    picked = _select([only_shoes, _item("tops", name="top")])
    assert "only shoes" in [i.name for i in picked]


def test_cold_weather_prefers_cold_season_items():
    summer = _item(name="linen", season=["summer"])
    winter = _item(name="wool", season=["winter"])
    untagged = _item(name="tee")
    picked = [i.name for i in _select([summer, winter, untagged], weather=_weather(3))]
    assert "linen" not in picked
    assert set(picked) == {"wool", "tee"}


def test_season_filter_never_empties_a_category():
    only_summer_shoes = _item("shoes", name="sandals", season=["summer"])
    picked = [i.name for i in _select([only_summer_shoes, _item()], weather=_weather(3))]
    assert "sandals" in picked


def test_hot_weather_drops_outerwear():
    items = [_item("tops"), _item("bottoms"), _item("outerwear", name="coat")]
    picked = [i.name for i in _select(items, weather=_weather(28))]
    assert "coat" not in picked


def test_hot_weather_keeps_outerwear_when_nothing_else():
    items = [_item("outerwear", name="coat"), _item("outerwear", name="jacket")]
    assert len(_select(items, weather=_weather(28))) == 2


# ---------------------------------------------------------------------------
# Distinct sections: main pieces held back, shoes/accessories may repeat
# ---------------------------------------------------------------------------


def test_main_pieces_used_in_other_sections_are_held_back():
    used_top, free_top = _item("tops", name="used top"), _item("tops", name="free top")
    used_coat = _item("outerwear", name="used coat")
    free_coat = _item("outerwear", name="free coat")
    picked = _select_candidates(
        [used_top, free_top, used_coat, free_coat],
        occasion="casual",
        weather=None,
        today=TODAY,
        used_elsewhere=frozenset({used_top.id, used_coat.id}),
    )
    assert {i.name for i in picked} == {"free top", "free coat"}


def test_shoes_and_accessories_may_repeat_across_sections():
    shoes, bag = _item("shoes", name="shoes"), _item("bags", name="bag")
    ring = _item("jewelry", name="ring")
    scarf = _item("accessories", name="scarf")
    other_shoes = _item("shoes", name="other shoes")
    picked = _select_candidates(
        [shoes, other_shoes, bag, ring, scarf],
        occasion="casual",
        weather=None,
        today=TODAY,
        used_elsewhere=frozenset({shoes.id, bag.id, ring.id, scarf.id}),
    )
    assert {i.name for i in picked} == {"shoes", "other shoes", "bag", "ring", "scarf"}


def test_hold_back_never_empties_a_category():
    only_top = _item("tops", name="only top")
    picked = _select_candidates(
        [only_top, _item("bottoms")],
        occasion="casual",
        weather=None,
        today=TODAY,
        used_elsewhere=frozenset({only_top.id}),
    )
    assert "only top" in [i.name for i in picked]


def test_unused_piece_wins_over_recent_wear():
    # Sections differing matters more than skipping a piece worn yesterday.
    used = _item("tops", name="used elsewhere")
    worn_yesterday = _item("tops", name="worn yesterday", last_worn=TODAY - timedelta(days=1))
    picked = _select_candidates(
        [used, worn_yesterday],
        occasion="casual",
        weather=None,
        today=TODAY,
        used_elsewhere=frozenset({used.id}),
    )
    assert [i.name for i in picked] == ["worn yesterday"]


# ---------------------------------------------------------------------------
# Short prompt refs
# ---------------------------------------------------------------------------


def test_system_prompt_lists_items_by_short_ref():
    items = [_item(name="Blue Shirt"), _item(name="Grey Chinos")]
    system = outfit_service._build_system_context(
        items=items, style_goals=None, using_starter_wardrobe=False
    )
    assert 'id=1 name="Blue Shirt"' in system
    assert 'id=2 name="Grey Chinos"' in system
    assert str(items[0].id) not in system


def test_proposal_refs_map_back_to_item_ids():
    a, b = uuid.uuid4(), uuid.uuid4()
    reply = json.dumps({
        "occasion": "work",
        "item_ids": ["1", "2", "9"],  # "9" was never offered
        "reasoning_short": "s",
        "reasoning_full": "f",
        "per_item_rationales": {"1": "anchors it", "9": "invented"},
        "compatibility_score": 80,
    })
    proposal = outfit_service._parse_proposal(reply, {"1": a, "2": b})
    assert proposal.item_ids == [a, b]
    assert proposal.per_item_rationales == {str(a): "anchors it"}


def test_too_few_known_refs_is_a_parse_failure():
    reply = json.dumps({
        "occasion": "work",
        "item_ids": ["1", "7"],
        "reasoning_short": "s",
        "reasoning_full": "f",
        "compatibility_score": 80,
    })
    with pytest.raises(OutfitError) as exc:
        outfit_service._parse_proposal(reply, {"1": uuid.uuid4()})
    assert exc.value.code == "parse_failed"
