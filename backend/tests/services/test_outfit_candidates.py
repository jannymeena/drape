"""The wardrobe as the stylist sees it: the whole wardrobe (starter blend
applied) with a safety cap, last-worn dates on each line, short prompt refs."""
from __future__ import annotations

import json
import uuid
from datetime import date

import pytest

from app.db.models import WardrobeItem
from app.services import outfit_service
from app.services.outfit_service import OutfitError


def _item(
    category: str = "tops",
    *,
    name: str = "Item",
    last_worn: date | None = None,
    is_favorite: bool = False,
) -> WardrobeItem:
    return WardrobeItem(
        id=uuid.uuid4(),
        user_id=uuid.uuid4(),
        name=name,
        category=category,
        formality="casual",
        last_worn=last_worn,
        is_favorite=is_favorite,
        is_starter_wardrobe=False,
    )


def test_the_whole_wardrobe_is_sent():
    items = [_item(name=f"Top {n}") for n in range(40)]
    assert outfit_service._prompt_items(items) == items


def test_very_large_wardrobes_are_capped_favourites_and_unworn_first(monkeypatch):
    monkeypatch.setattr(outfit_service, "_MAX_PROMPT_ITEMS", 3)
    worn = _item(name="worn", last_worn=date(2026, 9, 1))
    fav = _item(name="fav", is_favorite=True, last_worn=date(2026, 9, 29))
    never = _item(name="never")
    other = _item(name="other", last_worn=date(2026, 9, 20))
    picked = [i.name for i in outfit_service._prompt_items([worn, fav, never, other])]
    assert picked == ["fav", "never", "worn"]


def test_item_lines_carry_the_last_worn_date():
    system = outfit_service._build_system_context(
        items=[_item(name="Blue Shirt", last_worn=date(2026, 9, 28))],
        style_goals=None,
        using_starter_wardrobe=False,
    )
    assert 'name="Blue Shirt" [tops | casual | last worn 2026-09-28]' in system


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
    proposal = outfit_service._parse_proposal(reply, {"1": a, "2": b}, "work")
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
        outfit_service._parse_proposal(reply, {"1": uuid.uuid4()}, "work")
    assert exc.value.code == "parse_failed"


def test_the_occasion_is_ours_not_the_ais_echo():
    # The prompt shows labels ("Occasion: Date Night."); an echoed label must
    # not fail the reply.
    a, b = uuid.uuid4(), uuid.uuid4()
    reply = json.dumps({
        "occasion": "Date Night",
        "item_ids": ["1", "2"],
        "reasoning_short": "s",
        "reasoning_full": "f",
        "compatibility_score": 80,
    })
    assert outfit_service._parse_proposal(reply, {"1": a, "2": b}, "date_night").occasion == "date_night"
