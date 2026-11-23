"""Phase 6c — outfit generation, mix-and-match, log + history.

Architecture:

  * Two modes, never mixed (`wardrobe_mode`): while the user's starter
    wardrobe is active, outfits come only from its pieces (the whole catalog
    for their genders, to shop) and Today styles one look; otherwise only
    from the user's own pieces, up to `DAILY_OUTFIT_TARGET` looks. A starter
    wardrobe without shoes (menswear) styles complete outfits without them
    (`_shoeless`, `_NO_SHOES_NOTE`).
  * Every piece is classified with the occasions it suits
    (item_occasion_service); the stylist is offered only the pieces that
    suit the occasion.
  * Today styles the day's plan (Plan a day). No plan, no outfits — the
    client asks the user to plan the day. With one, `style_today` makes one
    AI call that returns 0 to the mode's maximum looks for the plan, each a
    distinct base (top + bottom, or dress); with none it says what's missing.
    The result is kept per plan (`DayStylingRun`), so Today asks once.
  * What a complete outfit is, the AI decides: the occasion rulebook
    (`app/data/occasion_rules.yaml`) goes into the prompt as a stylist's
    guide, not a checklist. The rulebook still shapes the heuristic outfit
    used when the AI's reply can't be parsed, and its `never_together`
    pairs are enforced.
  * `generate_one` is the pipeline for one outfit (regenerate,
    force-generate): candidate pieces → structured proposal → validate ids
    → persist. A look that repeats another of today's base pieces gets one
    retry.
  * `regenerate` calls the same pipeline but excludes the prior outfit's items
    so the AI returns something visibly different.
  * Mix-and-match swap is a deterministic compatibility recompute — no AI call,
    so swap latency stays under 100ms per CTO doc 2.
  * Log writes to outfit_history + streak_tracking and selects toast metadata.

Tenant isolation: every read scopes by `user_id`; mix-and-match validates new
item ids belong to the user before swapping.

Error model:

  * `OutfitError("not_found", ...)`            -> route → 404
  * `OutfitError("no_wardrobe", ...)`          -> route → 400 (no items at all)
  * `OutfitError("insufficient_items", ...)`   -> route → 400 (under 2 pieces)
  * `OutfitError("no_plan", ...)`              -> route → 400 (today unplanned)
  * `OutfitError("ai_call_failed", ...)`       -> route → 502 (Claude blew up)
  * `OutfitError("parse_failed", ...)`         -> route → 502
  * `OutfitError("invalid_swap", ...)`         -> route → 400
  * `OutfitError("shop_the_look", ...)`        -> route → 409 (log refused)
"""
from __future__ import annotations

import asyncio
import itertools
import json
import re
from collections import Counter
from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone
from json import JSONDecodeError
from typing import Iterable, Iterator, Optional, Sequence
from uuid import UUID

import structlog
from pydantic import ValidationError
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.localtime import as_user_day, user_day_start_utc, user_today
from app.data import occasion_rules
from app.services import day_plan_service, item_occasion_service, starter_wardrobe_service
from app.services import measurements_service
from app.services import stylist_prompt, trend_service
from app.db.models import (
    DayStylingRun,
    Outfit,
    OutfitHistory,
    StreakTracking,
    User,
    UserMeasurements,
    WardrobeItem,
)
from app.schemas.outfit import (
    GenerationMethod,
    HistoryEntry,
    HistoryFilter,
    HistoryStreak,
    LogOutfitToast,
    MixSwap,
    Occasion,
    OutfitHistoryResponse,
    OutfitItem,
    OutfitReasoningResponse,
    ReasoningItem,
    StructuredOutfitProposal,
    ToastVariant,
    WeatherContext,
    outfit_items_to_payload,
    payload_to_outfit_items,
)
from app.services.providers.ai.base import AIProvider, AIProviderError
from app.services.providers.weather.base import (
    WeatherProvider,
    WeatherProviderError,
    WeatherSnapshot,
)

_log = structlog.get_logger("outfit")

# The occasions marked `daily` in occasion_rules.yaml (the app's occasion list
# still flags them).
DEFAULT_OCCASIONS: tuple[Occasion, ...] = occasion_rules.daily_occasions()

# Items per outfit. Selection skews toward 4 (top + bottom + shoes + outerwear/
# accessory) but the AI may return 2-5 depending on category mix.
_MIN_ITEMS_PER_OUTFIT = 2
_MAX_ITEMS_PER_OUTFIT = 6

# Most looks Today styles for the day's plan from the user's own wardrobe
# (the AI returns fewer when the pieces can't make that many distinct,
# suitable outfits). A starter wardrobe gets one.
DAILY_OUTFIT_TARGET = 3
STARTER_OUTFIT_TARGET = 1

# Which pieces outfits are made of (`wardrobe_mode`).
MODE_STARTER = "starter"
MODE_WARDROBE = "wardrobe"

# The pieces that make one look different from another: two looks with the
# same top + bottom (or dress) are the same outfit, whatever the shoes.
_BASE_ROLES = frozenset({"top", "bottom", "dress"})

# Streak/toast thresholds straight from CTO doc 2 §"TOAST PRIORITY LOGIC".
_MILESTONE_TOTALS: tuple[int, ...] = (5, 10, 25, 50, 100)
_STREAK_THRESHOLD = 3
_LOW_COMPAT_THRESHOLD = 60
_HIGH_COMPAT_THRESHOLD = 75

_JSON_OBJECT_RE = re.compile(r"\{.*\}", re.DOTALL)

# Safety cap on the wardrobe list in the prompt (~40 tokens an item). Real
# wardrobes sit well under it; past it, favourites and the least recently
# worn pieces go first.
_MAX_PROMPT_ITEMS = 150

# Toronto fallback for the dashboard weather lookup when the user has no
# stored coords. This is an MVP placeholder — Phase 7 hardening adds real
# geocoding once `users.location` graduates from a free-text string.
_DEFAULT_LAT = 43.65
_DEFAULT_LON = -79.38


class OutfitError(Exception):
    """Domain-level outfit failure. Routes translate by `code`."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code


@dataclass(frozen=True)
class DayStyling:
    """What one outfit is styled for: the stylist occasion, plus — for
    Today's outfits — the day plan it came from (Plan a day's occasion key,
    dress level and note)."""

    occasion: Occasion
    day_occasion: Optional[str] = None
    dress_level: Optional[str] = None
    note: Optional[str] = None


def _now() -> datetime:
    return datetime.now(timezone.utc)


# ---------------------------------------------------------------------------
# Wardrobe candidate selection
# ---------------------------------------------------------------------------


def wardrobe_mode(db: Session, *, user: User) -> str:
    """`starter` while the user's starter wardrobe is active (until they own
    `AUTO_DEACTIVATE_REAL_ITEMS` pieces, or turn it off), else `wardrobe`."""
    assignment = starter_wardrobe_service.get_assignment(db, user_id=user.id)
    return MODE_STARTER if assignment is not None and assignment.is_active else MODE_WARDROBE


def max_looks(mode: str) -> int:
    return STARTER_OUTFIT_TARGET if mode == MODE_STARTER else DAILY_OUTFIT_TARGET


def _user_wardrobe(
    db: Session, *, user_id: UUID, mode: str = MODE_WARDROBE
) -> list[WardrobeItem]:
    """The pieces outfits are built from in [mode]: the user's own items, or
    only their starter wardrobe's — never both."""
    return list(
        db.scalars(
            select(WardrobeItem)
            .where(
                WardrobeItem.user_id == user_id,
                WardrobeItem.is_starter_wardrobe.is_(mode == MODE_STARTER),
            )
            .order_by(WardrobeItem.is_favorite.desc(), WardrobeItem.created_at.desc())
        ).all()
    )


def _wardrobe_sig(items: Sequence[WardrobeItem]) -> str:
    """Changes whenever a piece is added, removed or edited."""
    newest = max((i.updated_at for i in items if i.updated_at), default=None)
    return f"{len(items)}:{newest.isoformat() if newest else '-'}"


def _to_outfit_item(row: WardrobeItem, *, why: Optional[str] = None) -> OutfitItem:
    # Starter items are AWIN products the user doesn't own: carry the buy link.
    product = row.product if row.is_starter_wardrobe else None
    return OutfitItem(
        item_id=row.id,
        name=row.name,
        category=row.category,
        subcategory=row.subcategory,
        primary_image_url=row.primary_image_url,
        cutout_url=row.cutout_url,
        cutout_box=row.cutout_box,
        color_name=row.color_name,
        formality=row.formality,
        why_it_works=why,
        is_starter_wardrobe=row.is_starter_wardrobe,
        product_id=product.id if product else None,
        product_url=product.product_url if product else None,
        price_cents=product.price_cents if product else None,
        currency=product.currency if product else None,
        retailer=product.retailer if product else None,
    )


def _fits_formality(item: WardrobeItem, rule: occasion_rules.Rule) -> bool:
    return not rule.formality or item.formality is None or item.formality in rule.formality


def _role(item: WardrobeItem | OutfitItem) -> Optional[str]:
    return occasion_rules.ROLE_BY_CATEGORY.get(item.category)


def _base_of(items: Iterable[WardrobeItem | OutfitItem]) -> frozenset[UUID]:
    """A look's identity: the ids of its base pieces (top, bottom, dress)."""
    return frozenset(
        (i.id if isinstance(i, WardrobeItem) else i.item_id)
        for i in items
        if _role(i) in _BASE_ROLES
    )


def _complete_looks(
    items: Sequence[WardrobeItem], rule: occasion_rules.Rule
) -> Iterator[list[WardrobeItem]]:
    """Every distinct complete look the items can make for the rule, one per
    base combination (top x bottom, or dress), in the rule's shape order;
    non-base roles (shoes) take their first piece. Pieces of the occasion's
    formality come first, so the earliest looks are the most fitting."""
    ordered = sorted(items, key=lambda i: not _fits_formality(i, rule))
    by_role: dict[str, list[WardrobeItem]] = {}
    for it in ordered:
        role = _role(it)
        if role:
            by_role.setdefault(role, []).append(it)
    seen: set[frozenset[UUID]] = set()
    for shape in rule.complete_when:
        if not all(by_role.get(r) for r in shape):
            continue
        base_roles = [r for r in shape if r in _BASE_ROLES]
        rest = [by_role[r][0] for r in shape if r not in _BASE_ROLES]
        for combo in itertools.product(*(by_role[r] for r in base_roles)):
            key = _base_of(combo)
            if key in seen:
                continue
            seen.add(key)
            yield [*combo, *rest]


# ---------------------------------------------------------------------------
# AI prompt + parsing
# ---------------------------------------------------------------------------


_SYSTEM_PROMPT = (
    "You are Zoura, the user's personal stylist. You dress them from their own "
    "wardrobe and make the calls a good stylist would: which pieces go "
    "together, what flatters this person, and what suits the day. You build "
    "only from the user's own items listed below, wherever they suit the "
    "occasion, but never include one just because it's there. You never "
    "invent items. "
    "Every outfit you return is complete and wearable as it is: you decide "
    "what complete means for the occasion and these pieces (the request's "
    "occasion notes are a stylist's guide, not a checklist), and you never "
    "return an outfit with something essential missing. Accessories and a "
    "layer are optional: include a piece only if it makes the look better, "
    "and never include one you'd then tell the user to swap. "
    "You write in a warm, confident, second-person voice, like a stylist "
    "talking to their client (\"the boots toughen up the dress…\")."
)


_OUTFIT_FIELDS = (
    '"item_ids": ["3", "7", ...]   // 2-6 id= values: exactly the pieces worn '
    'in this outfit, never one your reasoning says you left out,\n'
    '"reasoning_short": "1-2 sentence hook for the card",\n'
    '"reasoning_full": "3-4 sentences that explain your styling decisions '
    'and mention every piece in item_ids: '
    'why these pieces work together, how the look flatters the wearer, and '
    'why it suits the occasion and weather. Refer to pieces by name.",\n'
    '"per_item_rationales": {"<item_id>": "why this piece fits"},\n'
    '"compatibility_score": 0-100 integer,\n'
    '"factors": ["Color harmony", "Occasion appropriateness", ...]\n'
)

# One outfit per reply (generate_one).
_RESPONSE_FORMAT = (
    "Respond with ONLY a JSON object — no prose, no markdown, no code "
    "fences. Schema:\n"
    "{\n"
    + "".join(f"  {line}\n" for line in _OUTFIT_FIELDS.rstrip("\n").split("\n"))
    + "}\n"
)

# Today's styling: several looks (or none) in one reply.
_LOOKS_RESPONSE_FORMAT = (
    "Respond with ONLY a JSON object — no prose, no markdown, no code "
    "fences. Schema:\n"
    "{\n"
    '  "outfits": [   // as many as the request allows and the pieces can '
    "make well, best first; [] when they can't make even one\n"
    "    {\n"
    + "".join(f"      {line}\n" for line in _OUTFIT_FIELDS.rstrip("\n").split("\n"))
    + "    }\n"
    "  ],\n"
    '  "missing": ["shoes", ...]   // only when "outfits" is empty: the pieces '
    "(from top, bottom, dress, outerwear, shoes, accessory) the wardrobe would "
    "need for one complete outfit for the occasion\n"
    "}\n"
)


def _build_system_context(
    *,
    items: Sequence[WardrobeItem],
    style_goals: Optional[list[str]],
    body_analysis: Optional[dict] = None,
    fit: Optional[dict] = None,
    shopping_style: Optional[str] = None,
    age_range: Optional[str] = None,
    style_profile: Optional[dict] = None,
    trends: str = "",
    response_format: str = _RESPONSE_FORMAT,
) -> str:
    """The stable, cacheable prefix (Tier 1.3): persona, stylist expertise,
    the week's trend brief (`trend_service.prompt_block`), response format,
    who the wearer is, and the wardrobe slice. Volatile
    content (date, occasion, weather) lives in the user message — caching is
    a byte-exact prefix match, so anything that varies must come after this
    block."""
    item_lines = []
    for ref, it in zip(_item_refs(items), items):
        descriptors = [
            it.category,
            it.subcategory or "",
            it.color_name or "",
            it.formality or "",
            it.pattern or "",
            it.material or "",
            "/".join(it.season) if it.season else "",
            f"last worn {it.last_worn:%Y-%m-%d}" if it.last_worn else "",
        ]
        descriptor_str = " | ".join(d for d in descriptors if d)
        item_lines.append(f'- id={ref} name="{it.name}" [{descriptor_str}]')

    # §5.5.1 — `fit` is the consent-gated derived fit summary (coarse
    # categories, never raw cm; the caller resolves it via
    # measurements_service.fit_profile_for_user).
    about = stylist_prompt.about_the_user(
        shopping_style=shopping_style,
        age_range=age_range,
        style_goals=style_goals,
        style_profile=style_profile,
        body_analysis=body_analysis,
        fit=fit,
    )
    return (
        f"{_SYSTEM_PROMPT}\n\n{stylist_prompt.STYLIST_EXPERTISE}\n"
        + (f"{trends}\n" if trends else "")
        + f"{response_format}\n"
        f"About the wearer:\n{about}\n"
        f"Available items ({len(items)}):\n" + "\n".join(item_lines)
    )


def _build_user_prompt(
    *,
    occasion: Occasion,
    weather: Optional[WeatherSnapshot],
    today: Optional[date] = None,
    rule: Optional[occasion_rules.Rule] = None,
    styling: Optional[DayStyling] = None,
    other_sections: Sequence[tuple[str, list[str]]] = (),
    note: str = "",
    looks: Optional[int] = None,
) -> str:
    """The per-request part: occasion + its rulebook entry, the day's plan
    (dress level + the user's note), date, weather, and what today's other
    looks already wear. With [looks], it asks for up to that many outfits
    (Today's styling) instead of one."""
    weather_block = "Weather: not available."
    if weather is not None:
        weather_block = (
            f"Weather: {weather.temp_c:.0f}°C ({weather.condition}), "
            f"feels like {weather.feels_like_c:.0f}°C."
        )
    if looks is None:
        prompt = f"Build ONE outfit for the occasion: {occasion}.\n"
    elif looks == 1:
        prompt = (
            f"Build the best outfit for the occasion: {occasion}. If these "
            "pieces can't make a complete outfit that suits it, return none "
            "and say what's missing.\n"
        )
    else:
        prompt = (
            f"Build up to {looks} outfits for the occasion: {occasion}. Each "
            "must be complete and suit the occasion, and each must use a "
            "different top and bottom (or a different dress) from the others; "
            "outerwear, shoes and accessories can repeat. Return fewer when "
            "the pieces can't make that many distinct, suitable outfits, and "
            "none when they can't make even one (then say what's missing) — "
            "never pad with a weak or incomplete look.\n"
        )
    if rule is not None:
        prompt += occasion_rules.prompt_block(occasion, rule) + "\n"
    if styling is not None and styling.day_occasion:
        prompt += f"The user planned today as: {styling.day_occasion.replace('_', ' ')}"
        if styling.dress_level:
            prompt += (
                f", dressed {styling.dress_level.replace('_', ' ')} — "
                "match that dress level"
            )
        prompt += ".\n"
        if styling.note:
            prompt += f'Their note about the day: "{styling.note}"\n'
    if today is not None:
        prompt += f"Today is {today:%A} {today.day} {today:%B %Y}.\n"
    prompt += weather_block
    if other_sections:
        worn = "; ".join(f"{label}: {', '.join(names)}" for label, names in other_sections)
        prompt += (
            f"\n\nToday's other outfits already use — {worn}. This one must not "
            "repeat the same top and bottom (or the same dress) as any of them; "
            "outerwear, shoes and accessories can repeat."
        )
    if note:
        prompt += f"\n\n{note}"
    return prompt


def _item_refs(items: Sequence[WardrobeItem]) -> list[str]:
    """Short prompt ids for wardrobe items ("1", "2", ...). A UUID costs more
    tokens than the item's whole description; refs map back in _resolve_refs."""
    return [str(n) for n in range(1, len(items) + 1)]


def _resolve_refs(payload: object, refs: dict[str, UUID]) -> object:
    """Swap the AI's short refs for real ids in `item_ids` and the
    `per_item_rationales` keys. Refs the prompt never offered are dropped
    (the AI invented them); too few left fails validation -> fallback."""
    if not isinstance(payload, dict):
        return payload
    raw_ids = payload.get("item_ids")
    if isinstance(raw_ids, list):
        resolved = []
        for ref in raw_ids:
            item_id = refs.get(str(ref).strip())
            if item_id is None:
                _log.info("outfit.ai_invented_item", ref=str(ref))
                continue
            resolved.append(str(item_id))
        payload["item_ids"] = resolved
    rationales = payload.get("per_item_rationales")
    if isinstance(rationales, dict):
        payload["per_item_rationales"] = {
            str(refs[str(k).strip()]): v
            for k, v in rationales.items()
            if str(k).strip() in refs
        }
    return payload


def _json_payload(text: str) -> object:
    candidate = text.strip()
    try:
        return json.loads(candidate)
    except JSONDecodeError:
        match = _JSON_OBJECT_RE.search(candidate)
        if match is None:
            raise OutfitError("parse_failed", "AI response did not contain a JSON object")
        try:
            return json.loads(match.group(0))
        except JSONDecodeError as exc:
            raise OutfitError("parse_failed", f"AI response had malformed JSON: {exc}") from exc


_ROLES = frozenset(occasion_rules.ROLE_BY_CATEGORY.values())


def _parse_looks(
    text: str, refs: dict[str, UUID], occasion: Occasion
) -> tuple[list[StructuredOutfitProposal], list[str]]:
    """Today's styling reply → (valid outfits, missing roles). An outfit
    that fails validation is dropped; a reply whose outfits all fail (or
    with no `outfits` list) is a parse failure, not a "none"."""
    payload = _json_payload(text)
    raw_looks = payload.get("outfits") if isinstance(payload, dict) else None
    if not isinstance(raw_looks, list):
        raise OutfitError("parse_failed", "AI response had no outfits list")
    proposals: list[StructuredOutfitProposal] = []
    for raw in raw_looks:
        if not isinstance(raw, dict):
            continue
        raw["occasion"] = occasion
        try:
            proposals.append(StructuredOutfitProposal.model_validate(_resolve_refs(raw, refs)))
        except ValidationError as exc:
            _log.info("outfit.look_invalid", errors=len(exc.errors()))
    if raw_looks and not proposals:
        raise OutfitError("parse_failed", "None of the AI's outfits were valid")
    missing = payload.get("missing") if isinstance(payload, dict) else None
    roles = [r for r in (missing if isinstance(missing, list) else []) if r in _ROLES]
    return proposals, list(dict.fromkeys(roles))


def _parse_proposal(
    text: str, refs: dict[str, UUID], occasion: Occasion
) -> StructuredOutfitProposal:
    payload = _json_payload(text)
    if isinstance(payload, dict):
        # We know the occasion; the AI isn't asked to echo it back.
        payload["occasion"] = occasion
    try:
        return StructuredOutfitProposal.model_validate(_resolve_refs(payload, refs))
    except ValidationError as exc:
        raise OutfitError(
            "parse_failed", f"AI response failed schema validation: {exc.errors()}"
        ) from exc


# ---------------------------------------------------------------------------
# Compatibility heuristic
# ---------------------------------------------------------------------------


def _compatibility_score(items: Sequence[WardrobeItem | OutfitItem]) -> int:
    """Heuristic 0-100. Small, deterministic, easy to test.

    Components (weights sum to 100):
      40 — formality cohesion (all items share a formality bucket)
      30 — category coverage (has top + bottom or dress; shoes; outerwear bonus)
      20 — color variety (penalises 4 items in the same color)
      10 — base score
    """
    if not items:
        return 0

    formalities = [getattr(i, "formality", None) for i in items]
    nontrivial = [f for f in formalities if f]
    if not nontrivial:
        formality_score = 30
    else:
        most_common = Counter(nontrivial).most_common(1)[0][1]
        formality_score = int(40 * (most_common / len(nontrivial)))

    categories = {getattr(i, "category", None) for i in items}
    has_top_or_dress = bool(categories & {"tops", "dresses"})
    has_bottom_or_dress = bool(categories & {"bottoms", "dresses"})
    has_shoes = "shoes" in categories
    coverage = 0
    if has_top_or_dress:
        coverage += 12
    if has_bottom_or_dress:
        coverage += 12
    if has_shoes:
        coverage += 6
    coverage = min(coverage, 30)

    colors = [getattr(i, "color_name", None) for i in items if getattr(i, "color_name", None)]
    if not colors:
        color_score = 10
    else:
        unique = len(set(colors))
        # Variety target: 2-3 distinct colors for 4 items.
        if unique == 1:
            color_score = 8
        elif unique == 2:
            color_score = 18
        elif unique == 3:
            color_score = 20
        else:
            color_score = 16

    total = 10 + formality_score + coverage + color_score
    return max(0, min(100, total))


def _compatibility_label(score: int) -> str:
    if score >= _HIGH_COMPAT_THRESHOLD:
        return "High compatibility"
    if score >= _LOW_COMPAT_THRESHOLD:
        return "Solid compatibility"
    return "Could be better"


# ---------------------------------------------------------------------------
# Generation pipeline
# ---------------------------------------------------------------------------


async def _maybe_weather(
    weather: WeatherProvider, *, lat: Optional[float], lon: Optional[float]
) -> Optional[WeatherSnapshot]:
    """Best-effort. If the lookup fails we degrade gracefully — outfit gen
    works without weather; the prompt just omits the block."""
    target_lat = lat if lat is not None else _DEFAULT_LAT
    target_lon = lon if lon is not None else _DEFAULT_LON
    try:
        return await weather.current(target_lat, target_lon)
    except WeatherProviderError as exc:
        _log.warning("outfit.weather_unavailable", code=exc.code, error=str(exc))
        return None


async def current_weather(
    weather: WeatherProvider, *, lat: Optional[float], lon: Optional[float]
) -> Optional[WeatherContext]:
    """Current conditions for the dashboard chip; None when unavailable."""
    return _to_weather_context(await _maybe_weather(weather, lat=lat, lon=lon))


def _to_weather_context(snap: Optional[WeatherSnapshot]) -> Optional[WeatherContext]:
    if snap is None:
        return None
    return WeatherContext(
        temp_c=snap.temp_c,
        feels_like_c=snap.feels_like_c,
        condition=snap.condition,
        humidity_pct=snap.humidity_pct,
        wind_kph=snap.wind_kph,
    )


async def _stylist_reply(
    ai: AIProvider,
    *,
    occasion: Occasion,
    items: Sequence[WardrobeItem],
    weather: Optional[WeatherSnapshot],
    style_goals: Optional[list[str]],
    body_analysis: Optional[dict] = None,
    fit: Optional[dict] = None,
    shopping_style: Optional[str] = None,
    age_range: Optional[str] = None,
    style_profile: Optional[dict] = None,
    today: Optional[date] = None,
    trends: str = "",
    rule: Optional[occasion_rules.Rule] = None,
    styling: Optional[DayStyling] = None,
    other_sections: Sequence[tuple[str, list[str]]] = (),
    note: str = "",
    looks: Optional[int] = None,
) -> str:
    """The stylist's raw reply: one outfit, or with [looks] Today's
    styling of up to that many."""
    system = _build_system_context(
        items=items,
        style_goals=style_goals,
        body_analysis=body_analysis,
        fit=fit,
        shopping_style=shopping_style,
        age_range=age_range,
        style_profile=style_profile,
        trends=trends,
        response_format=_RESPONSE_FORMAT if looks is None else _LOOKS_RESPONSE_FORMAT,
    )
    prompt = _build_user_prompt(
        occasion=occasion,
        weather=weather,
        today=today,
        rule=rule,
        styling=styling,
        other_sections=other_sections,
        note=note,
        looks=looks,
    )
    try:
        return await ai.chat(
            [{"role": "user", "content": prompt}],
            system=system,
            # Headroom for Sonnet 5.5's adaptive thinking, which counts toward
            # max_tokens; the JSON reply itself is ~500 tokens an outfit.
            # Only generated tokens are billed.
            max_tokens=4096 if looks is None else 4096 + 800 * looks,
            cache_system=True,
        )
    except AIProviderError as exc:
        _log.warning("outfit.ai_call_failed", code=exc.code, error=str(exc))
        raise OutfitError("ai_call_failed", str(exc)) from exc


def _item_ref_map(items: Sequence[WardrobeItem]) -> dict[str, UUID]:
    return dict(zip(_item_refs(items), (i.id for i in items)))


def _materialize_items(
    proposal: StructuredOutfitProposal,
    *,
    user_items_by_id: dict[UUID, WardrobeItem],
) -> list[OutfitItem]:
    """Turn the AI's id list into the snapshot we persist. Drops ids the AI
    invented — happens occasionally in mock / unstable model responses and
    should not abort the outfit."""
    materialized: list[OutfitItem] = []
    rationales = proposal.per_item_rationales or {}
    for item_id in proposal.item_ids:
        row = user_items_by_id.get(item_id)
        if row is None:
            _log.info("outfit.ai_invented_item", item_id=str(item_id))
            continue
        materialized.append(_to_outfit_item(row, why=rationales.get(str(item_id))))
    return materialized


def _drop_clashes(items: list[OutfitItem]) -> list[OutfitItem]:
    """Enforce the rulebook's `never_together` pairs (a dress with trousers):
    the second role of a clashing pair gives way. The prompt says so too —
    this catches the AI when it slips."""
    for _, loser in occasion_rules.clashes(occasion_rules.roles_of(i.category for i in items)):
        before = len(items)
        items = [i for i in items if occasion_rules.ROLE_BY_CATEGORY.get(i.category) != loser]
        _log.info("outfit.clash_dropped", role=loser, dropped=before - len(items))
    return items


def _fallback_proposal(
    occasion: Occasion,
    items: Sequence[WardrobeItem],
    rule: occasion_rules.Rule,
    *,
    avoid: Iterable[frozenset[UUID]] = (),
) -> StructuredOutfitProposal:
    """Used when the AI returned a response we couldn't parse (or twice left
    the outfit incomplete or repeating another look) but we still want to
    give the user *something*: a rule-shaped look from `_heuristic_pick`,
    with a bland reasoning paragraph."""
    pick = _heuristic_pick(items, rule, avoid=avoid)
    return StructuredOutfitProposal(
        occasion=occasion,
        item_ids=[i.id for i in pick],
        reasoning_short=f"A grounded {occasion_rules.label(occasion).lower()} look from your wardrobe.",
        reasoning_full=(
            "We've combined basics from your wardrobe to put together "
            f"a balanced {occasion_rules.label(occasion).lower()} outfit. "
            "Open the reasoning detail to see why each piece works together."
        ),
        per_item_rationales={},
        compatibility_score=_compatibility_score(pick),
        factors=["Color harmony", "Occasion appropriateness"],
    )


def _heuristic_pick(
    items: Sequence[WardrobeItem],
    rule: occasion_rules.Rule,
    *,
    avoid: Iterable[frozenset[UUID]] = (),
) -> list[WardrobeItem]:
    """The first complete look (`_complete_looks`) whose base pieces no look
    in `avoid` already uses; with none left, the first complete look. When
    the items can't complete the rule at all: one piece per role of the
    nearest shape (callers list the best candidates first), topped up to the
    proposal's minimum."""
    avoid = set(avoid)
    first_look: Optional[list[WardrobeItem]] = None
    for look in _complete_looks(items, rule):
        if _base_of(look) not in avoid:
            return look
        if first_look is None:
            first_look = look
    if first_look is not None:
        return first_look

    first: dict[str, WardrobeItem] = {}
    for it in items:
        role = _role(it)
        if role:
            first.setdefault(role, it)
    shape = max(rule.complete_when, key=lambda s: sum(r in first for r in s))
    pick: list[WardrobeItem] = [first[r] for r in shape if r in first]
    for it in items:
        if len(pick) >= _MIN_ITEMS_PER_OUTFIT:
            break
        if it not in pick:
            pick.append(it)
    return pick


def _prompt_items(pool: list[WardrobeItem]) -> list[WardrobeItem]:
    """The wardrobe as the stylist sees it, capped at `_MAX_PROMPT_ITEMS`
    (favourites and least recently worn first) as a safety net for very
    large wardrobes."""
    if len(pool) <= _MAX_PROMPT_ITEMS:
        return pool
    ranked = sorted(pool, key=lambda i: (not i.is_favorite, i.last_worn or date.min))
    return ranked[:_MAX_PROMPT_ITEMS]


_NO_SHOES_NOTE = (
    "These pieces are from a shop's starter collection, which has no shoes: "
    "style complete outfits without shoes, and never list shoes as missing."
)


def _shoeless(rule: occasion_rules.Rule) -> occasion_rules.Rule:
    """[rule] with shoes left out of what makes an outfit complete — for a
    starter wardrobe whose catalog has none (boohooMAN's feed carries no
    shoes), so the stylist, the heuristic look and the 'missing' list don't
    hold an outfit back for want of them."""
    shapes = [[r for r in shape if r != "shoes"] for shape in rule.complete_when]
    return rule.model_copy(update={"complete_when": [s for s in shapes if s] or [["top", "bottom"]]})


def _starter_without_shoes(mode: str, items: Sequence[WardrobeItem]) -> bool:
    return mode == MODE_STARTER and "shoes" not in occasion_rules.roles_of(
        i.category for i in items
    )


_REPEAT_NOTE = (
    "A previous attempt repeated the top and bottom (or the dress) of one of "
    "today's other outfits. Build the outfit again with a different top, "
    "bottom or dress."
)


# ---------------------------------------------------------------------------
# The wearer, as every stylist call sees them
# ---------------------------------------------------------------------------


def _wearer(db: Session, *, user: User) -> dict:
    """Who the outfits are for — the onboarding answers (shopping style, age
    range, style goals and profile), body analysis, the consent-gated fit
    summary — and the week's trend brief, as `_stylist_reply` arguments."""
    return {
        "style_goals": user.style_goals,
        "body_analysis": user.profile.body_analysis if user.profile else None,
        # Consent-gated (§5.5.1): None unless use_measurements_for_fit.
        "fit": measurements_service.fit_profile_for_user(db, user=user),
        "shopping_style": user.shopping_style,
        "age_range": user.age_range,
        "style_profile": user.style_profile,
        "trends": trend_service.prompt_block(
            trend_service.briefs_for(db, shopping_style=user.shopping_style)
        ),
    }


def _new_outfit(
    *,
    user: User,
    styling: DayStyling,
    mode: str,
    slot: Optional[int],
    proposal: StructuredOutfitProposal,
    chosen: list[OutfitItem],
    weather_payload: Optional[dict],
) -> Outfit:
    return Outfit(
        user_id=user.id,
        occasion=styling.occasion,
        day_occasion=styling.day_occasion,
        dress_level=styling.dress_level,
        slot=slot,
        items=outfit_items_to_payload(chosen),
        image_url=None,
        ai_reasoning_short=proposal.reasoning_short,
        ai_reasoning_full=proposal.reasoning_full,
        # Recomputed on the pieces kept (the AI's number can diverge once
        # invented ids are dropped).
        compatibility_score=_compatibility_score(chosen),
        weather_context=weather_payload,
        using_starter_wardrobe=mode == MODE_STARTER,
        generation_method="anthropic_v1",
        is_logged=False,
        worn_count=0,
    )


def _weather_payload(snap: Optional[WeatherSnapshot]) -> Optional[dict]:
    ctx = _to_weather_context(snap)
    return ctx.model_dump(mode="json") if ctx else None


# ---------------------------------------------------------------------------
# Today: the day's plan → up to max_looks(mode) looks
# ---------------------------------------------------------------------------


def today_styling(db: Session, *, user: User) -> Optional[DayStyling]:
    """What Today styles: the user's plan for today (Plan a day / Plan your
    week), or None when today isn't planned."""
    day = day_plan_service.resolve_day(db, user=user, day=user_today(user, now_utc=_now()))
    if not day.has_plan:
        return None
    return DayStyling(
        occasion=day_plan_service.OUTFIT_OCCASION[day.occasion],  # type: ignore[arg-type]
        day_occasion=day.occasion,
        dress_level=day.dress_level,
        note=day.note,
    )


def _outfits_generated_today(db: Session, *, user: User) -> int:
    # "Today" = the user's app day, which starts 05:00 local (Tier 1.2).
    start = user_day_start_utc(user, now_utc=_now())
    return int(
        db.scalar(
            select(func.count(Outfit.id)).where(
                Outfit.user_id == user.id, Outfit.created_at >= start
            )
        )
        or 0
    )


def _today_outfits(db: Session, *, user: User) -> list[Outfit]:
    start = user_day_start_utc(user, now_utc=_now())
    return list(
        db.scalars(
            select(Outfit)
            .where(Outfit.user_id == user.id, Outfit.created_at >= start)
            .order_by(Outfit.created_at.desc())
        ).all()
    )


def _plan_outfits(
    db: Session, *, user: User, styling: DayStyling, mode: str
) -> dict[int, Outfit]:
    """The newest outfit per slot made today for this plan in [mode].
    `regenerate` adds a row for the same slot rather than replacing one (the
    prior generation stays addressable in history), and a plan or mode
    change leaves the old outfits behind — neither shows."""
    starter = mode == MODE_STARTER
    newest: dict[int, Outfit] = {}
    for o in _today_outfits(db, user=user):  # newest first
        if (
            o.slot is not None
            and o.day_occasion == styling.day_occasion
            and o.dress_level == styling.dress_level
            and o.using_starter_wardrobe == starter
        ):
            newest.setdefault(o.slot, o)
    return newest


def _shown(by_slot: dict[int, Outfit], mode: str) -> list[Outfit]:
    return [by_slot[s] for s in sorted(by_slot) if s < max_looks(mode)]


def todays_outfits(db: Session, *, user: User) -> list[Outfit]:
    """The outfits the dashboard shows today, in slot order (none without a
    plan)."""
    styling = today_styling(db, user=user)
    if styling is None:
        return []
    mode = wardrobe_mode(db, user=user)
    return _shown(_plan_outfits(db, user=user, styling=styling, mode=mode), mode)


def _last_run(
    db: Session, *, user: User, styling: DayStyling, mode: str
) -> Optional[DayStylingRun]:
    return db.scalars(
        select(DayStylingRun)
        .where(
            DayStylingRun.user_id == user.id,
            DayStylingRun.plan_date == user_today(user, now_utc=_now()),
            DayStylingRun.day_occasion == styling.day_occasion,
            DayStylingRun.dress_level.is_not_distinct_from(styling.dress_level),
            DayStylingRun.mode == mode,
        )
        .order_by(DayStylingRun.created_at.desc())
        .limit(1)
    ).first()


def _missing_for(rule: occasion_rules.Rule, items: Sequence[WardrobeItem]) -> list[str]:
    """The rulebook's guess at what [items] lack for a complete look — for
    when there's too little to ask the stylist about."""
    return occasion_rules.gap(rule, occasion_rules.roles_of(i.category for i in items))[0]


@dataclass(frozen=True)
class TodayOutfits:
    """The dashboard's outfit section."""

    styling: Optional[DayStyling]  # None: today isn't planned
    mode: str  # starter | wardrobe
    outfits: list[Outfit]
    needs_styling: bool  # the client should ask for the looks (style_today)
    wardrobe_ready: bool  # False: the 'add items' empty state
    missing_roles: list[str]  # what would complete a look, when not ready


def today_outfits_state(db: Session, *, user: User) -> TodayOutfits:
    """What Today shows right now — read-only, no AI call."""
    mode = wardrobe_mode(db, user=user)
    items = _user_wardrobe(db, user_id=user.id, mode=mode)
    too_few = len(items) < _MIN_ITEMS_PER_OUTFIT
    styling = today_styling(db, user=user)
    if styling is None:
        # Nothing to style yet; with enough pieces the client asks the user
        # to plan the day.
        casual = occasion_rules.rule_for("casual", user.shopping_style)
        if _starter_without_shoes(mode, items):
            casual = _shoeless(casual)
        missing = _missing_for(casual, items) if too_few else []
        return TodayOutfits(None, mode, [], False, not too_few, missing)

    outfits = _shown(_plan_outfits(db, user=user, styling=styling, mode=mode), mode)
    if outfits:
        return TodayOutfits(styling, mode, outfits, False, True, [])
    rule = occasion_rules.rule_for(styling.occasion, user.shopping_style)
    if _starter_without_shoes(mode, items):
        rule = _shoeless(rule)
    if too_few:
        return TodayOutfits(styling, mode, [], False, False, _missing_for(rule, items))
    run = _last_run(db, user=user, styling=styling, mode=mode)
    if run is not None and run.looks == 0 and run.wardrobe_sig == _wardrobe_sig(items):
        # The stylist found nothing for this plan, and nothing has changed.
        return TodayOutfits(styling, mode, [], False, False, list(run.missing or []))
    return TodayOutfits(styling, mode, [], True, True, [])


@dataclass(frozen=True)
class TodayLooks:
    outfits: list[Outfit]  # in slot order; empty = nothing suitable
    missing_roles: list[str]  # with no outfits: what would complete one


async def style_today(
    *,
    db: Session,
    user: User,
    ai: AIProvider,
    weather: WeatherProvider,
    lat: Optional[float] = None,
    lon: Optional[float] = None,
) -> TodayLooks:
    """Today's looks for the day's plan, from ONE stylist call: up to
    `max_looks(mode)` outfits from the pieces that suit the occasion (none
    when they can't make one — then what's missing). Idempotent: once
    styled, returns what's there (no AI call, so a double-fire from the
    client is cheap), and a "none" stands until the wardrobe changes. Part
    of the free daily set: callers must NOT charge weekly usage for it."""
    state = today_outfits_state(db, user=user)
    if state.styling is None:
        raise OutfitError("no_plan", "Plan today first — pick what's on to get outfits for it.")
    if not state.needs_styling:
        return TodayLooks(state.outfits, state.missing_roles)
    styling, mode = state.styling, state.mode
    occasion = styling.occasion
    rule = occasion_rules.rule_for(occasion, user.shopping_style)
    items = _user_wardrobe(db, user_id=user.id, mode=mode)
    await item_occasion_service.ensure_classified(db, ai=ai, items=items)
    candidates = _prompt_items(item_occasion_service.applicable(items, occasion))
    limit = max_looks(mode)
    no_shoes = _starter_without_shoes(mode, items)
    if no_shoes:
        rule = _shoeless(rule)

    proposals: list[StructuredOutfitProposal] = []
    missing: list[str] = []
    snap: Optional[WeatherSnapshot] = None
    if len(candidates) >= _MIN_ITEMS_PER_OUTFIT:
        snap = await _maybe_weather(weather, lat=lat, lon=lon)
        try:
            text = await _stylist_reply(
                ai,
                occasion=occasion,
                items=candidates,
                weather=snap,
                today=user_today(user, now_utc=_now()),
                rule=rule,
                styling=styling,
                note=_NO_SHOES_NOTE if no_shoes else "",
                looks=limit,
                **_wearer(db, user=user),
            )
            proposals, missing = _parse_looks(text, _item_ref_map(candidates), occasion)
            if no_shoes:
                missing = [r for r in missing if r != "shoes"]
        except OutfitError as exc:
            if exc.code != "parse_failed" or next(_complete_looks(candidates, rule), None) is None:
                raise
            # An unreadable reply: a rule-shaped look rather than nothing.
            _log.warning("outfit.looks_parse_fallback", reason=str(exc))
            proposals = [_fallback_proposal(occasion, candidates, rule)]

    items_by_id = {i.id: i for i in items}
    looks: list[tuple[StructuredOutfitProposal, list[OutfitItem]]] = []
    seen: set[frozenset[UUID]] = set()
    for proposal in proposals:
        chosen = _drop_clashes(_materialize_items(proposal, user_items_by_id=items_by_id))
        chosen = chosen[:_MAX_ITEMS_PER_OUTFIT]
        base = _base_of(chosen)
        if len(chosen) < _MIN_ITEMS_PER_OUTFIT or base in seen:
            _log.info("outfit.look_dropped", pieces=len(chosen), repeat=base in seen)
            continue
        seen.add(base)
        looks.append((proposal, chosen))
        if len(looks) == limit:
            break
    if not looks and not missing:
        missing = _missing_for(rule, candidates)

    weather_payload = _weather_payload(snap)
    outfits = [
        _new_outfit(
            user=user,
            styling=styling,
            mode=mode,
            slot=slot,
            proposal=proposal,
            chosen=chosen,
            weather_payload=weather_payload,
        )
        for slot, (proposal, chosen) in enumerate(looks)
    ]
    db.add_all(outfits)
    db.add(
        DayStylingRun(
            user_id=user.id,
            plan_date=user_today(user, now_utc=_now()),
            day_occasion=styling.day_occasion,
            dress_level=styling.dress_level,
            mode=mode,
            looks=len(outfits),
            missing=None if outfits else missing,
            wardrobe_sig=_wardrobe_sig(items),
        )
    )
    db.commit()
    for o in outfits:
        db.refresh(o)
    _log.info(
        "outfit.styled_today",
        user_id=str(user.id),
        mode=mode,
        occasion=occasion,
        day_occasion=styling.day_occasion,
        offered=len(candidates),
        of=len(items),
        looks=len(outfits),
        missing=missing if not outfits else None,
    )
    return TodayLooks(outfits, [] if outfits else missing)


def _other_looks(
    db: Session, *, user: User, styling: DayStyling, mode: str, slot: Optional[int]
) -> list[Outfit]:
    """Today's outfits for the plan's *other* slots — the looks this one
    mustn't repeat."""
    if slot is None:
        return []
    by_slot = _plan_outfits(db, user=user, styling=styling, mode=mode)
    return [by_slot[s] for s in sorted(by_slot) if s != slot]


# ---------------------------------------------------------------------------
# Generation
# ---------------------------------------------------------------------------


async def generate_one(
    *,
    db: Session,
    user: User,
    ai: AIProvider,
    weather: WeatherProvider,
    styling: DayStyling,
    slot: Optional[int] = None,
    excluded_item_ids: Iterable[UUID] = (),
    lat: Optional[float] = None,
    lon: Optional[float] = None,
) -> Outfit:
    """Generate + persist one outfit for `styling` from the current mode's
    pieces (`wardrobe_mode`) that suit the occasion. With a `slot` it's one
    of Today's looks for the day's plan, kept distinct from the plan's
    other slots."""
    mode = wardrobe_mode(db, user=user)
    all_items = _user_wardrobe(db, user_id=user.id, mode=mode)
    if not all_items:
        raise OutfitError("no_wardrobe", "Add a few of your own pieces to get outfits.")
    occasion = styling.occasion
    rule = occasion_rules.rule_for(occasion, user.shopping_style)
    no_shoes = _starter_without_shoes(mode, all_items)
    if no_shoes:
        rule = _shoeless(rule)
    await item_occasion_service.ensure_classified(db, ai=ai, items=all_items)
    suited = item_occasion_service.applicable(all_items, occasion)
    if len(suited) < _MIN_ITEMS_PER_OUTFIT:
        suited = all_items
    excluded_set = set(excluded_item_ids)
    pool = [i for i in suited if i.id not in excluded_set]
    if next(_complete_looks(pool, rule), None) is None:
        # Leaving out the prior look's pieces (regenerate) left nothing like
        # a complete look; style from every suitable piece instead.
        pool = suited
    if len(pool) < _MIN_ITEMS_PER_OUTFIT:
        # Can't form a valid outfit (the proposal schema requires
        # >= _MIN_ITEMS_PER_OUTFIT). Surface a clean 400 rather than letting
        # the fallback build an invalid proposal and 500.
        raise OutfitError(
            "insufficient_items",
            f"Add at least {_MIN_ITEMS_PER_OUTFIT} wardrobe items to generate an outfit.",
        )

    others = _other_looks(db, user=user, styling=styling, mode=mode, slot=slot)
    avoid = {_base_of(payload_to_outfit_items(o.items)) for o in others}
    other_sections = [
        (f"Look {o.slot + 1}", [i.name for i in payload_to_outfit_items(o.items)])
        for o in others
    ]
    snap = await _maybe_weather(weather, lat=lat, lon=lon)
    today = user_today(user, now_utc=_now())
    candidates = _prompt_items(pool)
    items_by_id = {i.id: i for i in all_items}
    wearer = _wearer(db, user=user)

    def materialize(proposal: StructuredOutfitProposal) -> list[OutfitItem]:
        return _drop_clashes(_materialize_items(proposal, user_items_by_id=items_by_id))

    def fallback() -> StructuredOutfitProposal:
        return _fallback_proposal(occasion, pool, rule, avoid=avoid)

    async def ask(note: str = "") -> StructuredOutfitProposal:
        text = await _stylist_reply(
            ai,
            occasion=occasion,
            items=candidates,
            weather=snap,
            today=today,
            rule=rule,
            styling=styling,
            other_sections=other_sections,
            note="\n\n".join(n for n in (_NO_SHOES_NOTE if no_shoes else "", note) if n),
            **wearer,
        )
        return _parse_proposal(text, _item_ref_map(candidates), occasion)

    try:
        proposal = await ask()
        chosen = materialize(proposal)
        if _base_of(chosen) in avoid:
            # One more try, told what to fix; a second repeat gets the
            # heuristic outfit (avoiding the other looks).
            _log.info("outfit.retry", occasion=occasion, slot=slot)
            proposal = await ask(note=_REPEAT_NOTE)
            chosen = materialize(proposal)
            if _base_of(chosen) in avoid:
                _log.warning("outfit.retry_fallback", occasion=occasion, slot=slot)
                proposal = fallback()
                chosen = materialize(proposal)
    except OutfitError as exc:
        if exc.code != "parse_failed":
            raise
        # Parse failures are recoverable: ship a heuristic outfit so the
        # dashboard never lands the user on an empty state.
        _log.warning("outfit.parse_fallback", reason=str(exc))
        proposal = fallback()
        chosen = materialize(proposal)

    if len(chosen) < _MIN_ITEMS_PER_OUTFIT:
        # AI hallucinated too many ids; fall back to heuristic + bland reasoning.
        _log.info("outfit.too_few_real_items", returned=len(chosen))
        proposal = fallback()
        chosen = materialize(proposal)

    chosen = chosen[:_MAX_ITEMS_PER_OUTFIT]
    outfit = _new_outfit(
        user=user,
        styling=styling,
        mode=mode,
        slot=slot,
        proposal=proposal,
        chosen=chosen,
        weather_payload=_weather_payload(snap),
    )
    db.add(outfit)
    db.commit()
    db.refresh(outfit)
    _log.info(
        "outfit.generated",
        user_id=str(user.id),
        outfit_id=str(outfit.id),
        mode=mode,
        occasion=occasion,
        day_occasion=styling.day_occasion,
        slot=slot,
        items=len(chosen),
        score=outfit.compatibility_score,
    )
    return outfit


async def generate_for_user(
    *,
    db: Session,
    user: User,
    ai: AIProvider,
    weather: WeatherProvider,
    occasions: Sequence[Occasion] = DEFAULT_OCCASIONS,
    lat: Optional[float] = None,
    lon: Optional[float] = None,
) -> list[Outfit]:
    """Force-generate one outfit per occasion, outside Today's plan (no
    slot, so they don't show on the dashboard). Sequential, not gathered."""
    outfits: list[Outfit] = []
    for occ in occasions:
        outfits.append(
            await generate_one(
                db=db,
                user=user,
                ai=ai,
                weather=weather,
                styling=DayStyling(occasion=occ),
                lat=lat,
                lon=lon,
            )
        )
    return outfits


# ---------------------------------------------------------------------------
# Mix and match
# ---------------------------------------------------------------------------


def _get_outfit_owned(db: Session, *, user: User, outfit_id: UUID) -> Outfit:
    outfit = db.scalar(
        select(Outfit).where(Outfit.id == outfit_id, Outfit.user_id == user.id)
    )
    if outfit is None:
        raise OutfitError("not_found", "Outfit not found")
    return outfit


def toggle_favorite(db: Session, *, user: User, outfit_id: UUID) -> Outfit:
    """Flip the outfit's favorite flag (mirrors wardrobe item favoriting).
    Raises `OutfitError("not_found")` if the outfit isn't the caller's."""
    outfit = _get_outfit_owned(db, user=user, outfit_id=outfit_id)
    outfit.is_favorite = not outfit.is_favorite
    outfit.favorited_at = _now() if outfit.is_favorite else None
    db.commit()
    db.refresh(outfit)
    _log.info(
        "outfit.favorited",
        user_id=str(user.id),
        outfit_id=str(outfit.id),
        is_favorite=outfit.is_favorite,
    )
    return outfit


def mix_and_match(
    db: Session,
    *,
    user: User,
    outfit_id: UUID,
    swaps: Sequence[MixSwap],
) -> tuple[Outfit, int]:
    """Apply a list of (old, new) item swaps. Validates new ids belong to the
    user's wardrobe. Recomputes compatibility deterministically — no AI call."""
    outfit = _get_outfit_owned(db, user=user, outfit_id=outfit_id)
    current_items = payload_to_outfit_items(outfit.items)

    # Validate new ids are owned by this user.
    new_ids = {s.new_item_id for s in swaps}
    new_rows = list(
        db.scalars(
            select(WardrobeItem).where(
                WardrobeItem.user_id == user.id, WardrobeItem.id.in_(new_ids)
            )
        ).all()
    )
    found_new = {r.id for r in new_rows}
    missing = new_ids - found_new
    if missing:
        raise OutfitError(
            "invalid_swap",
            f"New item id(s) not in your wardrobe: {sorted(str(i) for i in missing)}",
        )
    new_by_id = {r.id: r for r in new_rows}

    # Apply swaps, preserving order. Each old_item_id must currently be in the
    # outfit; otherwise the client's view is stale.
    swap_map = {s.old_item_id: s.new_item_id for s in swaps}
    updated: list[OutfitItem] = []
    seen_olds: set[UUID] = set()
    for it in current_items:
        if it.item_id in swap_map:
            new_id = swap_map[it.item_id]
            row = new_by_id[new_id]
            updated.append(_to_outfit_item(row))
            seen_olds.add(it.item_id)
        else:
            updated.append(it)
    missing_olds = set(swap_map.keys()) - seen_olds
    if missing_olds:
        raise OutfitError(
            "invalid_swap",
            f"Old item id(s) not in this outfit: {sorted(str(i) for i in missing_olds)}",
        )

    # Recompute compatibility from the final lineup (shop pieces included).
    score = _compatibility_score(updated)

    outfit.items = outfit_items_to_payload(updated)
    outfit.compatibility_score = score
    outfit.generation_method = "manual_mix"
    db.commit()
    db.refresh(outfit)
    _log.info(
        "outfit.mix_and_match",
        user_id=str(user.id),
        outfit_id=str(outfit.id),
        swaps=len(swaps),
        score=score,
    )
    return outfit, score


# ---------------------------------------------------------------------------
# Regenerate
# ---------------------------------------------------------------------------


async def regenerate(
    *,
    db: Session,
    user: User,
    ai: AIProvider,
    weather: WeatherProvider,
    outfit_id: UUID,
) -> Outfit:
    """A fresh AI-generated version of an outfit, excluding the prior
    outfit's items so the result is visibly different. Same plan and slot:
    on Today it takes the prior card's place."""
    prior = _get_outfit_owned(db, user=user, outfit_id=outfit_id)
    prior_items = payload_to_outfit_items(prior.items)
    excluded = {i.item_id for i in prior_items}
    current = today_styling(db, user=user)
    same_plan = current is not None and (current.day_occasion, current.dress_level) == (
        prior.day_occasion,
        prior.dress_level,
    )
    styling = DayStyling(
        occasion=prior.occasion,  # type: ignore[arg-type]
        day_occasion=prior.day_occasion,
        dress_level=prior.dress_level,
        note=current.note if same_plan and current else None,
    )
    # Only one of today's cards keeps its slot; regenerating an older outfit
    # (from history, or from before a mode change) mustn't take over a slot
    # on today's dashboard.
    on_today = (
        same_plan
        and prior.created_at >= user_day_start_utc(user, now_utc=_now())
        and prior.using_starter_wardrobe == (wardrobe_mode(db, user=user) == MODE_STARTER)
    )
    fresh = await generate_one(
        db=db,
        user=user,
        ai=ai,
        weather=weather,
        styling=styling,
        slot=prior.slot if on_today else None,
        excluded_item_ids=excluded,
    )
    _log.info(
        "outfit.regenerated",
        user_id=str(user.id),
        prior_id=str(prior.id),
        new_id=str(fresh.id),
    )
    return fresh


# ---------------------------------------------------------------------------
# Reasoning view
# ---------------------------------------------------------------------------


def get_reasoning(
    db: Session, *, user: User, outfit_id: UUID
) -> OutfitReasoningResponse:
    outfit = _get_outfit_owned(db, user=user, outfit_id=outfit_id)
    items = payload_to_outfit_items(outfit.items)
    reasoning_items = [
        ReasoningItem(
            item_id=i.item_id,
            name=i.name,
            why_it_works=i.why_it_works,
            image_url=i.primary_image_url,
            category=i.category,
            color_name=i.color_name,
        )
        for i in items
    ]
    score = outfit.compatibility_score or 0
    return OutfitReasoningResponse(
        outfit_id=outfit.id,
        full_text=outfit.ai_reasoning_full,
        items=reasoning_items,
        compatibility_score=outfit.compatibility_score,
        compatibility_label=_compatibility_label(score),
        factors=["Color harmony", "Occasion appropriateness", "Wardrobe rotation"],
    )


# ---------------------------------------------------------------------------
# Log + streak + toast selection
# ---------------------------------------------------------------------------


def _get_or_create_streak(db: Session, *, user_id: UUID) -> StreakTracking:
    row = db.scalar(select(StreakTracking).where(StreakTracking.user_id == user_id))
    if row is not None:
        return row
    row = StreakTracking(
        user_id=user_id,
        current_streak=0,
        longest_streak=0,
        total_outfits_logged=0,
    )
    db.add(row)
    db.flush()
    return row


def _advance_streak(streak: StreakTracking, *, today: date) -> None:
    if streak.last_logged_date is None:
        streak.current_streak = 1
        streak.streak_started_at = today
    else:
        delta = (today - streak.last_logged_date).days
        if delta == 0:
            return  # idempotent: already logged today
        if delta == 1:
            streak.current_streak += 1
        else:
            streak.current_streak = 1
            streak.streak_started_at = today
    streak.last_logged_date = today
    if streak.current_streak > streak.longest_streak:
        streak.longest_streak = streak.current_streak


def _select_toast(*, total_logged: int, current_streak: int) -> LogOutfitToast:
    """Mirrors CTO doc 2 §"TOAST PRIORITY LOGIC"."""
    variant: ToastVariant
    message: str
    duration_ms: int
    background: str
    haptic: str

    if total_logged in _MILESTONE_TOTALS:
        variant = "milestone"
        if total_logged >= 100:
            message = f"{total_logged} outfits logged! 👑 Style master achieved!"
        elif total_logged >= 50:
            message = f"{total_logged} outfits logged! 💪 Halfway to 100!"
        elif total_logged >= 25:
            message = f"{total_logged} outfits logged! ✨ You're a Zoura pro now."
        elif total_logged >= 10:
            message = f"{total_logged} outfits logged! 👔 You're getting the hang of this."
        else:
            message = f"{total_logged} outfits logged! 🎉"
        duration_ms = 3000
        background = "#8B9E6E"
        haptic = "success"
    elif current_streak >= _STREAK_THRESHOLD:
        variant = "streak"
        message = f"{current_streak}-day streak! 🔥 Keep it going!"
        duration_ms = 4000
        background = "#C8901C"
        haptic = "warning"
    else:
        variant = "default"
        message = "Outfit logged!"
        duration_ms = 2000
        background = "#6B4530"
        haptic = "light"

    return LogOutfitToast(
        type=variant,
        message=message,
        duration_ms=duration_ms,
        background=background,
        haptic=haptic,
    )


def log_outfit(
    db: Session, *, user: User, outfit_id: UUID
) -> tuple[Outfit, LogOutfitToast, StreakTracking]:
    outfit = _get_outfit_owned(db, user=user, outfit_id=outfit_id)
    if any(i.product_url for i in payload_to_outfit_items(outfit.items)):
        raise OutfitError(
            "shop_the_look",
            "This outfit has pieces you don't own yet — shop the look instead.",
        )
    streak = _get_or_create_streak(db, user_id=user.id)
    # Streak days are the user's app days (05:00-local rollover, Tier 1.2):
    # a 1 AM log counts toward the evening before, and consecutive local
    # evenings stay consecutive even when UTC has already rolled over.
    today = user_today(user, now_utc=_now())

    already_today = (
        streak.last_logged_date == today
        and outfit.is_logged
        and outfit.logged_at is not None
        and as_user_day(user, outfit.logged_at) == today
    )

    now = _now()
    if not already_today:
        _advance_streak(streak, today=today)
        streak.total_outfits_logged += 1
        outfit.is_logged = True
        outfit.logged_at = now
        outfit.worn_count += 1
        history = OutfitHistory(
            user_id=user.id,
            outfit_id=outfit.id,
            logged_at=now,
            shared=False,
        )
        db.add(history)
        # Wearing an outfit wears its pieces: feed the item-level wear log
        # that the Profile intelligence stats read. Starter pieces aren't the
        # user's clothes, so they don't count.
        from app.services import wardrobe_service

        wardrobe_service.record_outfit_wear(
            db,
            user=user,
            item_ids=[
                i.item_id
                for i in payload_to_outfit_items(outfit.items)
                if not i.is_starter_wardrobe
            ],
            worn_date=today,
        )
    db.commit()
    db.refresh(outfit)
    db.refresh(streak)

    toast = _select_toast(
        total_logged=streak.total_outfits_logged,
        current_streak=streak.current_streak,
    )
    _log.info(
        "outfit.logged",
        user_id=str(user.id),
        outfit_id=str(outfit.id),
        already_today=already_today,
        toast=toast.type,
        streak=streak.current_streak,
        total=streak.total_outfits_logged,
    )
    return outfit, toast, streak


# ---------------------------------------------------------------------------
# History
# ---------------------------------------------------------------------------


def _filter_window(filter_: HistoryFilter, *, user: User) -> Optional[date]:
    today = user_today(user, now_utc=_now())
    if filter_ == "this_week":
        start = today - timedelta(days=today.weekday())
        return start
    if filter_ == "this_month":
        return today.replace(day=1)
    if filter_ == "last_3_months":
        return today - timedelta(days=90)
    return None


def get_history(
    db: Session, *, user: User, filter_: HistoryFilter = "all"
) -> OutfitHistoryResponse:
    base = (
        select(OutfitHistory, Outfit)
        .join(Outfit, OutfitHistory.outfit_id == Outfit.id)
        .where(OutfitHistory.user_id == user.id)
        .order_by(OutfitHistory.logged_at.desc())
    )
    window_start = _filter_window(filter_, user=user)
    if window_start is not None:
        cutoff = datetime.combine(window_start, datetime.min.time(), tzinfo=timezone.utc)
        base = base.where(OutfitHistory.logged_at >= cutoff)
    # §3.1 pagination cap — newest year of daily logs; older entries fall off
    # rather than growing the response forever.
    rows = list(db.execute(base.limit(365)).all())
    entries: list[HistoryEntry] = []
    for hist, outfit in rows:
        items = payload_to_outfit_items(outfit.items)
        entries.append(
            HistoryEntry(
                outfit_id=outfit.id,
                logged_at=hist.logged_at,
                occasion=outfit.occasion,  # type: ignore[arg-type]
                items_count=len(items),
                worn_count=outfit.worn_count,
                image_url=outfit.image_url,
                items=items,
            )
        )

    streak = _get_or_create_streak(db, user_id=user.id)
    db.commit()
    today = user_today(user, now_utc=_now())
    is_active = bool(
        streak.last_logged_date is not None
        and (today - streak.last_logged_date).days <= 1
        and streak.current_streak > 0
    )
    return OutfitHistoryResponse(
        outfits=entries,
        total_count=len(entries),
        current_streak=HistoryStreak(
            days=streak.current_streak,
            started_at=streak.streak_started_at,
            is_active=is_active,
        ),
        filter=filter_,
    )


# ---------------------------------------------------------------------------
# Banners (today dashboard)
# ---------------------------------------------------------------------------


def _profile_incomplete(db: Session, *, user_id: UUID) -> bool:
    """CTO doc 2 Screen 5 — show the resume banner while measurements aren't
    complete. `is_complete` is a plain column, so no decryption is needed.
    (Previously keyed off onboarding_completed, which missed the banner's whole
    audience: users who finished onboarding but skipped measurements.)"""
    return not db.scalar(
        select(UserMeasurements.is_complete).where(
            UserMeasurements.user_id == user_id
        )
    )


def _starter_wardrobe_banner(db: Session, *, user_id: UUID) -> bool:
    """CTO doc 2 §Starter Wardrobe banner rules: active starter assignment,
    fewer than 5 real items, and not dismissed within the last 7 days."""
    from app.services import banner_service

    assignment = starter_wardrobe_service.get_assignment(db, user_id=user_id)
    if assignment is None or not assignment.is_active:
        return False
    if starter_wardrobe_service.real_item_count(db, user_id=user_id) >= 5:
        return False
    return not banner_service.is_dismissed(
        db, user_id=user_id, banner="starter_wardrobe"
    )
