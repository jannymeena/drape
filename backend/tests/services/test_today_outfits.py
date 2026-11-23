"""Today's outfits: styled for the day's plan in one stylist call — up to 3
distinct looks from the user's own pieces, or one from the starter wardrobe
while it's active (never a mix), offering only pieces that suit the
occasion. The stylist decides what's complete and how many looks there are;
with none, Today remembers what's missing until the wardrobe changes."""
from __future__ import annotations

import json
import re

import pytest

from app.core.localtime import user_today
from app.schemas.outfit import payload_to_outfit_items
from app.schemas.wardrobe import WardrobeItemUpdate
from app.services import (
    day_plan_service,
    outfit_service,
    starter_wardrobe_service,
    wardrobe_service,
)
from app.services.outfit_service import OutfitError
from app.services.providers.ai.base import AIProvider
from app.services.providers.weather.base import WeatherProvider, WeatherSnapshot
from tests.factories import make_catalog, make_outfit, make_wardrobe_item

_LINE_RE = re.compile(r'id=(\d+) name="([^"]*)" \[(\w+)')


class _Stylist(AIProvider):
    """Today's stylist. Answers with the scripted looks (lists of piece
    names) and `missing`; unscripted, one look per offered top — each with
    the next bottom and the first shoes — up to the number asked for.
    Records every prompt and system context."""

    def __init__(self, *looks: list[str], missing: list[str] | None = None) -> None:
        self.looks = list(looks) if looks or missing is not None else None
        self.missing = missing or []
        self.prompts: list[str] = []
        self.systems: list[str] = []

    async def chat(self, messages, *, model=None, system=None, max_tokens=1024, cache_system=False):
        prompt = messages[-1]["content"]
        self.prompts.append(prompt)
        self.systems.append(system or "")
        lines = _LINE_RE.findall(system or "")
        refs = {name: ref for ref, name, _ in lines}
        looks = self.looks
        if looks is None:
            by_cat: dict[str, list[str]] = {}
            for _, name, category in lines:
                by_cat.setdefault(category, []).append(name)
            asked = re.search(r"Build up to (\d) outfits", prompt)
            n = int(asked.group(1)) if asked else 1
            tops, bottoms = by_cat.get("tops", []), by_cat.get("bottoms", [])
            shoes = by_cat.get("shoes", [])[:1]
            looks = [
                [top, bottoms[i % len(bottoms)], *shoes]
                for i, top in enumerate(tops[:n])
                if bottoms
            ]
        return json.dumps(
            {
                "outfits": [
                    {
                        "item_ids": [refs[name] for name in look],
                        "reasoning_short": "Sharp.",
                        "reasoning_full": "Sharp and simple.",
                        "compatibility_score": 80,
                    }
                    for look in looks
                ],
                "missing": self.missing,
            }
        )

    async def analyze_image(self, image_bytes, prompt, *, media_type="image/jpeg", model=None, max_tokens=1024):
        raise NotImplementedError


class _FirstPerCategory(AIProvider):
    """One outfit (regenerate): the first offered piece of each category,
    every time — the same look twice unless told otherwise."""

    def __init__(self) -> None:
        self.prompts: list[str] = []

    async def chat(self, messages, *, model=None, system=None, max_tokens=1024, cache_system=False):
        self.prompts.append(messages[-1]["content"])
        first: dict[str, str] = {}
        for ref, _, category in _LINE_RE.findall(system or ""):
            first.setdefault(category, ref)
        return json.dumps(
            {
                "item_ids": list(first.values()),
                "reasoning_short": "Sharp.",
                "reasoning_full": "Sharp and simple.",
                "compatibility_score": 80,
            }
        )

    async def analyze_image(self, image_bytes, prompt, *, media_type="image/jpeg", model=None, max_tokens=1024):
        raise NotImplementedError


class _Garbled(_Stylist):
    async def chat(self, messages, **kwargs):
        self.prompts.append(messages[-1]["content"])
        return "I'd love to help! Here are some thoughts…"


class _Weather(WeatherProvider):
    async def current(self, lat, lon):
        return WeatherSnapshot(
            temp_c=15.0, feels_like_c=15.0, condition="clear", humidity_pct=50, wind_kph=5.0
        )


def _plan_today(db, user, occasion="work_day", dress_level="business", note=None):
    day_plan_service.save(
        db, user=user, day=user_today(user), occasion=occasion, dress_level=dress_level, note=note
    )


def _wardrobe(db, user, *, tops=1, bottoms=1, shoes=1):
    for n in range(tops):
        make_wardrobe_item(db, user, name=f"Top {n}", category="tops", formality="smart_casual")
    for n in range(bottoms):
        make_wardrobe_item(db, user, name=f"Bottom {n}", category="bottoms", formality="smart_casual")
    for n in range(shoes):
        make_wardrobe_item(db, user, name=f"Shoes {n}", category="shoes", formality="smart_casual")


async def _style(db, user, ai=None):
    return await outfit_service.style_today(
        db=db, user=user, ai=ai or _Stylist(), weather=_Weather()
    )


def _names(outfit):
    return {i.name for i in payload_to_outfit_items(outfit.items)}


def _base(outfit):
    return {i.name for i in payload_to_outfit_items(outfit.items) if i.category != "shoes"}


# ---------------------------------------------------------------------------
# Wardrobe mode: up to three looks, one call
# ---------------------------------------------------------------------------


async def test_up_to_three_looks_in_one_call(db, make_user):
    user = make_user()
    _plan_today(db, user)
    _wardrobe(db, user, tops=4, bottoms=3)
    ai = _Stylist()
    looks = await _style(db, user, ai)
    assert [o.slot for o in looks.outfits] == [0, 1, 2]
    assert len(ai.prompts) == 1
    assert "Build up to 3 outfits" in ai.prompts[0]
    assert len({frozenset(_base(o)) for o in looks.outfits}) == 3
    assert all(not o.using_starter_wardrobe for o in looks.outfits)


async def test_the_stylist_decides_how_many(db, make_user):
    user = make_user()
    _plan_today(db, user)
    _wardrobe(db, user, tops=3, bottoms=3)
    looks = await _style(db, user, _Stylist(["Top 0", "Bottom 0", "Shoes 0"]))
    assert [_names(o) for o in looks.outfits] == [{"Top 0", "Bottom 0", "Shoes 0"}]
    state = outfit_service.today_outfits_state(db, user=user)
    assert [o.id for o in state.outfits] == [looks.outfits[0].id]
    assert state.needs_styling is False


async def test_repeats_and_extras_are_dropped(db, make_user):
    user = make_user()
    _plan_today(db, user)
    _wardrobe(db, user, tops=4, bottoms=1)
    ai = _Stylist(
        ["Top 0", "Bottom 0", "Shoes 0"],
        ["Top 0", "Bottom 0"],  # same top + bottom as the first
        ["Top 1", "Bottom 0"],
        ["Top 2", "Bottom 0"],
        ["Top 3", "Bottom 0"],  # past three
    )
    looks = await _style(db, user, ai)
    assert [_base(o) for o in looks.outfits] == [
        {"Top 0", "Bottom 0"},
        {"Top 1", "Bottom 0"},
        {"Top 2", "Bottom 0"},
    ]


async def test_none_suitable_is_remembered_until_the_wardrobe_changes(db, make_user):
    user = make_user()
    _plan_today(db, user)
    _wardrobe(db, user, tops=2, bottoms=1, shoes=0)
    ai = _Stylist(missing=["shoes", "nonsense"])
    looks = await _style(db, user, ai)
    assert looks.outfits == [] and looks.missing_roles == ["shoes"]

    state = outfit_service.today_outfits_state(db, user=user)
    assert (state.needs_styling, state.wardrobe_ready, state.missing_roles) == (
        False,
        False,
        ["shoes"],
    )
    again = await _style(db, user, ai)
    assert again.missing_roles == ["shoes"] and len(ai.prompts) == 1

    make_wardrobe_item(db, user, name="Loafers", category="shoes")
    assert outfit_service.today_outfits_state(db, user=user).needs_styling is True


async def test_too_few_pieces_never_reach_the_stylist(db, make_user):
    user = make_user()
    _plan_today(db, user)
    _wardrobe(db, user, tops=1, bottoms=0, shoes=0)
    state = outfit_service.today_outfits_state(db, user=user)
    assert state.wardrobe_ready is False and state.needs_styling is False
    assert "bottom" in state.missing_roles


async def test_only_pieces_that_suit_the_occasion_are_offered(db, make_user):
    user = make_user()
    _plan_today(db, user)  # work
    _wardrobe(db, user)
    gym = make_wardrobe_item(db, user, name="Running Tee", category="tops")
    gym.occasions = ["gym", "casual"]
    shirt = make_wardrobe_item(db, user, name="Oxford Shirt", category="tops")
    shirt.occasions = ["work", "interview"]
    db.commit()
    ai = _Stylist()
    await _style(db, user, ai)
    assert 'name="Oxford Shirt"' in ai.systems[0]
    assert 'name="Running Tee"' not in ai.systems[0]
    assert 'name="Top 0"' in ai.systems[0]  # unclassified: offered


# ---------------------------------------------------------------------------
# Starter mode: one look, starter pieces only
# ---------------------------------------------------------------------------


async def test_starter_mode_styles_one_look_from_starter_pieces_only(db, make_user):
    user = make_user()
    make_catalog(db)
    starter_wardrobe_service.assign(db, user=user)
    _wardrobe(db, user)  # their own pieces don't join
    _plan_today(db, user, occasion="day_off", dress_level="casual")
    state = outfit_service.today_outfits_state(db, user=user)
    assert state.mode == "starter" and state.needs_styling is True

    ai = _Stylist()
    looks = await _style(db, user, ai)
    assert "Build the best outfit" in ai.prompts[0]
    assert 'name="Top 0"' not in ai.systems[0]
    [outfit] = looks.outfits
    assert outfit.using_starter_wardrobe is True
    items = payload_to_outfit_items(outfit.items)
    assert all(i.is_starter_wardrobe and i.product_url for i in items)


async def test_turning_starter_off_switches_to_own_pieces(db, make_user):
    user = make_user()
    make_catalog(db)
    starter_wardrobe_service.assign(db, user=user)
    _plan_today(db, user, occasion="day_off", dress_level="casual")
    _wardrobe(db, user, tops=2, bottoms=2)
    await _style(db, user)
    starter_wardrobe_service.deactivate(db, user=user)

    state = outfit_service.today_outfits_state(db, user=user)
    assert state.mode == "wardrobe"
    assert state.outfits == [] and state.needs_styling is True
    looks = await _style(db, user)
    assert len(looks.outfits) == 2
    assert all(not o.using_starter_wardrobe for o in looks.outfits)


# ---------------------------------------------------------------------------
# The plan
# ---------------------------------------------------------------------------


def test_without_a_plan_nothing_is_styled(db, make_user):
    user = make_user()
    _wardrobe(db, user, tops=2, bottoms=2)
    state = outfit_service.today_outfits_state(db, user=user)
    assert state.styling is None
    assert state.needs_styling is False and state.outfits == []
    assert state.wardrobe_ready is True  # the client asks for a plan


async def test_without_a_plan_styling_is_refused(db, make_user):
    user = make_user()
    _wardrobe(db, user)
    with pytest.raises(OutfitError) as exc:
        await _style(db, user)
    assert exc.value.code == "no_plan"


async def test_the_plan_and_profile_drive_the_prompt(db, make_user):
    user = make_user()
    user.shopping_style = "womens"
    user.age_range = "25-34"
    db.commit()
    _plan_today(db, user, occasion="date_dinner", dress_level="formal", note="Rooftop bar")
    _wardrobe(db, user)
    ai = _Stylist()
    [outfit] = (await _style(db, user, ai)).outfits
    assert outfit.occasion == "date_night"
    assert (outfit.day_occasion, outfit.dress_level, outfit.slot) == ("date_dinner", "formal", 0)
    assert "planned today as: date dinner, dressed formal" in ai.prompts[0]
    assert '"Rooftop bar"' in ai.prompts[0]
    assert "25-34" in ai.systems[0]


async def test_styling_is_idempotent(db, make_user):
    user = make_user()
    _plan_today(db, user)
    _wardrobe(db, user, tops=2, bottoms=2)
    ai = _Stylist()
    first = await _style(db, user, ai)
    again = await _style(db, user, ai)
    assert [o.id for o in again.outfits] == [o.id for o in first.outfits]
    assert len(ai.prompts) == 1


async def test_a_plan_change_hides_the_old_plans_looks(db, make_user):
    user = make_user()
    _plan_today(db, user)
    _wardrobe(db, user)
    await _style(db, user)
    assert len(outfit_service.todays_outfits(db, user=user)) == 1
    _plan_today(db, user, occasion="day_off", dress_level="casual")
    state = outfit_service.today_outfits_state(db, user=user)
    assert state.outfits == [] and state.needs_styling is True


async def test_an_unreadable_reply_gets_a_rule_shaped_look(db, make_user):
    user = make_user()
    _plan_today(db, user)
    _wardrobe(db, user)
    looks = await _style(db, user, _Garbled())
    assert [_names(o) for o in looks.outfits] == [{"Top 0", "Bottom 0", "Shoes 0"}]


# ---------------------------------------------------------------------------
# Regenerate
# ---------------------------------------------------------------------------


async def test_regenerate_keeps_the_slot_and_replaces_the_card(db, make_user):
    user = make_user()
    _plan_today(db, user)
    _wardrobe(db, user, tops=2, bottoms=2)
    first, second = (await _style(db, user)).outfits
    fresh = await outfit_service.regenerate(
        db=db, user=user, ai=_FirstPerCategory(), weather=_Weather(), outfit_id=first.id
    )
    assert (fresh.slot, fresh.day_occasion) == (0, "work_day")
    assert [o.id for o in outfit_service.todays_outfits(db, user=user)] == [fresh.id, second.id]


async def test_regenerate_never_repeats_another_look(db, make_user):
    """The AI keeps returning slot 0's look for slot 1: told it repeats,
    then, repeating again, given an unused top + bottom."""
    user = make_user()
    _plan_today(db, user)
    _wardrobe(db, user, tops=2, bottoms=2)
    first, second = (await _style(db, user)).outfits
    ai = _FirstPerCategory()
    fresh = await outfit_service.regenerate(
        db=db, user=user, ai=ai, weather=_Weather(), outfit_id=second.id
    )
    assert "Look 1: " in ai.prompts[0]
    assert len(ai.prompts) == 2 and "repeated the top and bottom" in ai.prompts[1]
    assert fresh.slot == 1 and _base(fresh) != _base(first)


def test_shop_the_look_outfit_cannot_be_logged(db, make_user):
    """Starter looks hold shop pieces; logging them is refused."""
    user = make_user()
    item = make_wardrobe_item(db, user, name="Top", category="tops")
    outfit = make_outfit(db, user, items=[item])
    outfit.items = [{**outfit.items[0], "product_url": "https://shop.example/p"}]
    db.commit()
    with pytest.raises(OutfitError) as exc:
        outfit_service.log_outfit(db, user=user, outfit_id=outfit.id)
    assert exc.value.code == "shop_the_look"


# ---------------------------------------------------------------------------
# Occasion classification
# ---------------------------------------------------------------------------


class _Classifier(_Stylist):
    """Classifies pieces by name; styles like `_Stylist`."""

    def __init__(self, by_name: dict[str, list[str]], *, fail: bool = False) -> None:
        super().__init__()
        self.by_name = by_name
        self.fail = fail
        self.classify_calls = 0
        self.models: list[str | None] = []

    async def chat(self, messages, *, model=None, system=None, max_tokens=1024, cache_system=False):
        if not (system or "").startswith("You classify wardrobe pieces"):
            return await super().chat(messages, system=system)
        self.classify_calls += 1
        self.models.append(model)
        if self.fail:
            from app.services.providers.ai.base import AIProviderError

            raise AIProviderError("upstream_down", "down")
        reply = {}
        for ref, name in re.findall(r'^(\d+): "([^"]+)"', messages[-1]["content"], re.M):
            if name in self.by_name:
                reply[ref] = self.by_name[name]
        return json.dumps(reply)


@pytest.mark.classify_occasions
async def test_pieces_are_classified_once_before_styling(db, make_user):
    user = make_user()
    _plan_today(db, user)  # work
    _wardrobe(db, user)
    tee = make_wardrobe_item(db, user, name="Slogan Tee", category="tops")
    ai = _Classifier(
        {
            "Top 0": ["work", "interview"],
            "Bottom 0": ["work", "moon_landing"],
            "Shoes 0": ["work"],
            "Slogan Tee": ["casual"],
        }
    )
    await _style(db, user, ai)
    db.refresh(tee)
    assert tee.occasions == ["casual"]
    assert ai.classify_calls == 1 and ai.models[0]  # the cheap tagging model
    assert 'name="Slogan Tee"' not in ai.systems[-1]
    bottom = next(
        i for i in outfit_service._user_wardrobe(db, user_id=user.id) if i.name == "Bottom 0"
    )
    assert bottom.occasions == ["work"]  # off-vocabulary dropped

    # Editing what a piece is asks again; other edits don't.
    wardrobe_service.update_item(
        db, user=user, item_id=tee.id, payload=WardrobeItemUpdate(is_favorite=True)
    )
    assert tee.occasions == ["casual"]
    wardrobe_service.update_item(
        db, user=user, item_id=tee.id, payload=WardrobeItemUpdate(formality="smart_casual")
    )
    assert tee.occasions is None


@pytest.mark.classify_occasions
async def test_a_classifier_outage_hides_nothing(db, make_user):
    user = make_user()
    _plan_today(db, user)
    _wardrobe(db, user)
    ai = _Classifier({}, fail=True)
    looks = await _style(db, user, ai)
    assert len(looks.outfits) == 1
    assert all(i.occasions is None for i in outfit_service._user_wardrobe(db, user_id=user.id))
