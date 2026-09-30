"""Phase 6c — outfit generation, mix-and-match, log + history.

Architecture:

  * `generate_for_user` orchestrates the full pipeline for one occasion:
    pick candidate items → ask Claude for a structured proposal →
    validate item ids belong to the user → persist `outfits` row.
  * Today dashboard reuses `generate_for_user` for each of the three occasions.
  * `regenerate` calls the same pipeline but excludes the prior outfit's items
    so the AI returns something visibly different.
  * AWIN products (11e): the user's wardrobe always leads. Products are offered
    to the AI only to fill roles the wardrobe can't cover for the occasion and
    weather (an empty wardrobe gets whole outfits from them), and — on
    regenerate — as up to `_MAX_CREATIVE_SHOP_ITEMS` "something new" pieces.
    The caps are enforced in code, not trusted to the AI. Products the user
    doesn't own mark the outfit "shop the look", which can't be logged.
  * Mix-and-match swap is a deterministic compatibility recompute — no AI call,
    so swap latency stays under 100ms per CTO doc 2.
  * Log writes to outfit_history + streak_tracking and selects toast metadata.

Tenant isolation: every read scopes by `user_id`; mix-and-match validates new
item ids belong to the user before swapping.

Error model:

  * `OutfitError("not_found", ...)`            -> route → 404
  * `OutfitError("no_wardrobe", ...)`          -> route → 400 (no items at all)
  * `OutfitError("ai_call_failed", ...)`       -> route → 502 (Claude blew up)
  * `OutfitError("parse_failed", ...)`         -> route → 502
  * `OutfitError("invalid_swap", ...)`         -> route → 400
  * `OutfitError("shop_the_look", ...)`        -> route → 409 (log refused)
"""
from __future__ import annotations

import asyncio
import json
import random
import re
from collections import Counter
from datetime import date, datetime, timedelta, timezone
from json import JSONDecodeError
from typing import Iterable, Optional, Sequence
from uuid import UUID

import structlog
from pydantic import ValidationError
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.localtime import as_user_day, user_day_start_utc, user_today
from app.services import catalog_service
from app.services import measurements_service
from app.services import stylist_prompt, trend_service
from app.db.models import (
    Outfit,
    OutfitHistory,
    Product,
    StreakTracking,
    User,
    UserMeasurements,
    WardrobeItem,
)
from app.schemas.outfit import (
    GenerateOutfitsRequest,
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

# CTO doc 2 default occasion list for /today/dashboard.
DEFAULT_OCCASIONS: tuple[Occasion, ...] = ("work", "casual", "date_night")

# Items per outfit. Selection skews toward 4 (top + bottom + shoes + outerwear/
# accessory) but the AI may return 2-5 depending on category mix.
_MIN_ITEMS_PER_OUTFIT = 2
_MAX_ITEMS_PER_OUTFIT = 6

# Soft target so the dashboard can show "X of 3 generated today". Real free-tier
# limits land in 6d.
DAILY_OUTFIT_TARGET = 3

# Streak/toast thresholds straight from CTO doc 2 §"TOAST PRIORITY LOGIC".
_MILESTONE_TOTALS: tuple[int, ...] = (5, 10, 25, 50, 100)
_STREAK_THRESHOLD = 3
_LOW_COMPAT_THRESHOLD = 60
_HIGH_COMPAT_THRESHOLD = 75

_JSON_OBJECT_RE = re.compile(r"\{.*\}", re.DOTALL)

# AWIN products in outfits.
_MAX_CREATIVE_SHOP_ITEMS = 2
_SHOP_CANDIDATES_PER_ROLE = 4
_COLD_FEELS_LIKE_C = 12.0  # below: outerwear is part of the outfit
_HOT_FEELS_LIKE_C = 22.0  # at/above: no heavy pieces
# Wardrobe slice sent to the AI (see _select_candidates): at most this many
# items per category, so the prompt stays flat however large the wardrobe grows.
_CANDIDATES_PER_CATEGORY = {
    "tops": 8,
    "bottoms": 6,
    "dresses": 5,
    "shoes": 4,
    "outerwear": 3,
    "accessories": 4,
    "bags": 2,
    "jewelry": 3,
}
_DEFAULT_CANDIDATES_PER_CATEGORY = 4
# Items worn within this many days (today included) are held back for variety.
_RECENT_WEAR_DAYS = 2
# Main pieces in today's other Today sections are held back so each section
# gets its own core look; shoes, bags, jewelry and accessories may repeat
# (most people own a few pairs of shoes, and reusing them reads as normal).
_DISTINCT_PER_SECTION = {"tops", "bottoms", "dresses", "outerwear"}
_COLD_SEASONS = {"fall", "winter"}
_WARM_SEASONS = {"spring", "summer"}
_ROLE_BY_WARDROBE_CATEGORY = {
    **catalog_service.ROLE_BY_CATEGORY,
    "bags": "accessory",
    "jewelry": "accessory",
}

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


def _now() -> datetime:
    return datetime.now(timezone.utc)


# ---------------------------------------------------------------------------
# Wardrobe candidate selection
# ---------------------------------------------------------------------------


def _user_wardrobe(db: Session, *, user_id: UUID) -> list[WardrobeItem]:
    return list(
        db.scalars(
            select(WardrobeItem)
            .where(WardrobeItem.user_id == user_id)
            .order_by(WardrobeItem.is_favorite.desc(), WardrobeItem.created_at.desc())
        ).all()
    )


def _filter_for_occasion(
    items: Sequence[WardrobeItem], occasion: Occasion
) -> list[WardrobeItem]:
    """Light heuristic preselect — keeps the AI prompt small and grounded.

    The AI still does final coordination; this just filters out clear mismatches
    (e.g. tuxedo trousers for `gym`). When nothing matches, we fall back to the
    full set so the AI always has something to work with.
    """
    if occasion == "work":
        match = lambda f: f in (None, "smart_casual", "formal", "casual")  # noqa: E731
    elif occasion == "gym":
        match = lambda f: f in (None, "casual")  # noqa: E731
    elif occasion == "date_night":
        match = lambda f: f in (None, "smart_casual", "formal")  # noqa: E731
    elif occasion == "casual":
        match = lambda f: f in (None, "casual", "smart_casual")  # noqa: E731
    else:
        match = lambda _f: True  # noqa: E731

    selected = [i for i in items if match(i.formality)]
    return selected if selected else list(items)


def _to_outfit_item(row: WardrobeItem, *, why: Optional[str] = None) -> OutfitItem:
    # Starter items are AWIN products the user doesn't own: carry the buy link.
    product = row.product if row.is_starter_wardrobe else None
    return OutfitItem(
        item_id=row.id,
        name=row.name,
        category=row.category,
        primary_image_url=row.primary_image_url,
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


def _product_to_outfit_item(p: Product, *, why: Optional[str] = None) -> OutfitItem:
    return OutfitItem(
        item_id=p.id,
        name=catalog_service.display_name(p),
        category=catalog_service.CATEGORY_BY_ROLE.get(p.role or "", p.category),
        primary_image_url=p.image_url,
        color_name=p.color_name,
        formality=p.formality,
        why_it_works=why,
        product_id=p.id,
        product_url=p.product_url,
        price_cents=p.price_cents,
        currency=p.currency,
        retailer=p.retailer,
    )


# ---------------------------------------------------------------------------
# AWIN products: gap fill + creative picks
# ---------------------------------------------------------------------------


def _shop_plan(
    candidates: Sequence[WardrobeItem],
    *,
    shopping_style: Optional[str],
    weather: Optional[WeatherSnapshot],
    creative: bool,
) -> tuple[list[str], int]:
    """(roles to offer shop products for, max shop pieces in the outfit).

    Gap mode: only roles the occasion's wardrobe candidates can't cover —
    top + bottom (or a dress, outside menswear), plus outerwear when it's
    cold. An empty wardrobe for the occasion gets a whole outfit, shoes and an
    accessory included. Creative mode (regenerate) also offers every role for
    up to `_MAX_CREATIVE_SHOP_ITEMS` new pieces on top of any gap fill."""
    mens = shopping_style == "mens"
    roles = {_ROLE_BY_WARDROBE_CATEGORY.get(i.category) for i in candidates}
    cold = weather is not None and weather.feels_like_c < _COLD_FEELS_LIKE_C

    if not candidates:
        offer = ["top", "bottom"] + ([] if mens else ["dress", "shoes"]) + ["accessory"]
        if cold:
            offer.append("outerwear")
        return offer, _MAX_ITEMS_PER_OUTFIT

    offer: list[str] = []
    cap = 0
    if not (("top" in roles and "bottom" in roles) or "dress" in roles):
        missing = [r for r in ("top", "bottom") if r not in roles]
        offer += missing
        cap += len(missing)
        if not mens:
            offer.append("dress")  # alternative to the missing top/bottom
    if cold and "outerwear" not in roles:
        offer.append("outerwear")
        cap += 1
    if creative:
        for role in ("top", "bottom", "outerwear", "accessory") + (() if mens else ("dress", "shoes")):
            if role not in offer:
                offer.append(role)
        cap = max(cap, _MAX_CREATIVE_SHOP_ITEMS)
    return offer, cap


def _suits_weather(p: Product, feels_like_c: Optional[float]) -> bool:
    if feels_like_c is None:
        return True
    if feels_like_c >= _HOT_FEELS_LIKE_C:
        return p.warmth != "heavy"
    if feels_like_c < _COLD_FEELS_LIKE_C and p.role == "outerwear":
        return p.warmth != "light"
    return True


def _shop_candidates(
    products: Sequence[Product],
    *,
    roles: Sequence[str],
    occasion: Occasion,
    weather: Optional[WeatherSnapshot],
    exclude: set[UUID],
) -> list[Product]:
    """Up to `_SHOP_CANDIDATES_PER_ROLE` random products per role, preferring
    ones tagged for the occasion and suited to the temperature (each filter is
    dropped when it would leave the role empty). Random so regenerate shows
    different products."""
    feels = weather.feels_like_c if weather is not None else None
    picked: list[Product] = []
    for role in roles:
        pool = [p for p in products if p.role == role and p.id not in exclude]
        for keep in (
            lambda p: occasion in (p.occasions or []),
            lambda p: _suits_weather(p, feels),
        ):
            narrowed = [p for p in pool if keep(p)]
            if narrowed:
                pool = narrowed
        picked += random.sample(pool, min(_SHOP_CANDIDATES_PER_ROLE, len(pool)))
    return picked


# ---------------------------------------------------------------------------
# AI prompt + parsing
# ---------------------------------------------------------------------------


_SYSTEM_PROMPT = (
    "You are Zoura, the user's personal stylist. You dress them from their own "
    "wardrobe and make the calls a good stylist would: which pieces go "
    "together, what flatters this person, and what suits the day. You always "
    "ground the outfit in the user's own items; shop products are only offered "
    "separately, per request, with their own limit. You never invent items. "
    "You write in a warm, confident, second-person voice, like a stylist "
    "talking to their client (\"the boots toughen up the dress…\")."
)


_RESPONSE_FORMAT = (
    "Respond with ONLY a JSON object — no prose, no markdown, no code "
    "fences. Schema:\n"
    "{\n"
    '  "occasion": "<echo the requested occasion exactly>",\n'
    '  "item_ids": ["3", "7", ...]   // 2-6 id= values of the items you chose,\n'
    '  "reasoning_short": "1-2 sentence hook for the card",\n'
    '  "reasoning_full": "3-4 sentences that explain your styling decisions: '
    'why these pieces work together, how the look flatters the wearer, and '
    'why it suits the occasion and weather. Refer to pieces by name.",\n'
    '  "per_item_rationales": {"<item_id>": "why this piece fits"},\n'
    '  "compatibility_score": 0-100 integer,\n'
    '  "factors": ["Color harmony", "Occasion appropriateness", ...]\n'
    "}\n"
)


def _build_system_context(
    *,
    items: Sequence[WardrobeItem],
    style_goals: Optional[list[str]],
    using_starter_wardrobe: bool,
    body_analysis: Optional[dict] = None,
    fit: Optional[dict] = None,
    shopping_style: Optional[str] = None,
    age_range: Optional[str] = None,
    style_profile: Optional[dict] = None,
    trends: str = "",
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
            "starter" if it.is_starter_wardrobe else "",
        ]
        descriptor_str = " | ".join(d for d in descriptors if d)
        item_lines.append(f'- id={ref} name="{it.name}" [{descriptor_str}]')

    starter_note = ""
    if using_starter_wardrobe:
        starter_note = (
            "Note: this user is on a starter wardrobe (curated bootstrap kit). "
            "Encourage them in your reasoning to add their own items.\n"
        )

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
        + f"{_RESPONSE_FORMAT}\n"
        f"About the wearer:\n{about}{starter_note}\n"
        f"Available items ({len(items)}):\n" + "\n".join(item_lines)
    )


def _build_user_prompt(
    *,
    occasion: Occasion,
    weather: Optional[WeatherSnapshot],
    shop: Sequence[Product] = (),
    shop_cap: int = 0,
    creative: bool = False,
    today: Optional[date] = None,
) -> str:
    weather_block = "Weather: not available."
    if weather is not None:
        weather_block = (
            f"Weather: {weather.temp_c:.0f}°C ({weather.condition}), "
            f"feels like {weather.feels_like_c:.0f}°C."
        )
    prompt = f"Build ONE outfit for the occasion: {occasion}.\n"
    if today is not None:
        prompt += f"Today is {today:%A} {today.day} {today:%B %Y}.\n"
    prompt += weather_block
    if shop and shop_cap:
        why = (
            "to add something new the user doesn't own yet"
            if creative
            else "only for pieces the user's own items can't cover"
        )
        lines = "\n".join(
            f'- id={ref} name="{catalog_service.display_name(p)}" '
            f"[{p.role} | {p.color_name or ''} | {p.formality or ''} | {p.warmth or ''} | shop]"
            for ref, p in zip(_shop_refs(shop), shop)
        )
        prompt += (
            f"\n\nShop products (not owned). Use at most {shop_cap}, {why}; "
            f"prefer the user's items whenever they work:\n{lines}"
        )
    return prompt


def _item_refs(items: Sequence[WardrobeItem]) -> list[str]:
    """Short prompt ids for wardrobe items ("1", "2", ...). A UUID costs more
    tokens than the item's whole description; refs map back in _resolve_refs."""
    return [str(n) for n in range(1, len(items) + 1)]


def _shop_refs(shop: Sequence[Product]) -> list[str]:
    """Short prompt ids for shop products ("S1", "S2", ...)."""
    return [f"S{n}" for n in range(1, len(shop) + 1)]


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


def _parse_proposal(text: str, refs: dict[str, UUID]) -> StructuredOutfitProposal:
    candidate = text.strip()
    try:
        payload = json.loads(candidate)
    except JSONDecodeError:
        match = _JSON_OBJECT_RE.search(candidate)
        if match is None:
            raise OutfitError("parse_failed", "AI response did not contain a JSON object")
        try:
            payload = json.loads(match.group(0))
        except JSONDecodeError as exc:
            raise OutfitError("parse_failed", f"AI response had malformed JSON: {exc}") from exc
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


async def _ask_ai_for_outfit(
    ai: AIProvider,
    *,
    occasion: Occasion,
    items: Sequence[WardrobeItem],
    weather: Optional[WeatherSnapshot],
    style_goals: Optional[list[str]],
    using_starter_wardrobe: bool,
    body_analysis: Optional[dict] = None,
    fit: Optional[dict] = None,
    shop: Sequence[Product] = (),
    shop_cap: int = 0,
    creative: bool = False,
    shopping_style: Optional[str] = None,
    age_range: Optional[str] = None,
    style_profile: Optional[dict] = None,
    today: Optional[date] = None,
    trends: str = "",
) -> StructuredOutfitProposal:
    system = _build_system_context(
        items=items,
        style_goals=style_goals,
        using_starter_wardrobe=using_starter_wardrobe,
        body_analysis=body_analysis,
        fit=fit,
        shopping_style=shopping_style,
        age_range=age_range,
        style_profile=style_profile,
        trends=trends,
    )
    prompt = _build_user_prompt(
        occasion=occasion,
        weather=weather,
        shop=shop,
        shop_cap=shop_cap,
        creative=creative,
        today=today,
    )
    try:
        text = await ai.chat(
            [{"role": "user", "content": prompt}],
            system=system,
            # Headroom for Sonnet 5.5's adaptive thinking, which counts toward
            # max_tokens; the JSON reply itself is ~500 tokens. Only generated
            # tokens are billed.
            max_tokens=4096,
            cache_system=True,
        )
    except AIProviderError as exc:
        _log.warning("outfit.ai_call_failed", code=exc.code, error=str(exc))
        raise OutfitError("ai_call_failed", str(exc)) from exc

    refs = {
        **dict(zip(_item_refs(items), (i.id for i in items))),
        **dict(zip(_shop_refs(shop), (p.id for p in shop))),
    }
    return _parse_proposal(text, refs)


def _materialize_items(
    proposal: StructuredOutfitProposal,
    *,
    user_items_by_id: dict[UUID, WardrobeItem],
    shop_by_id: Optional[dict[UUID, Product]] = None,
    shop_cap: int = 0,
) -> list[OutfitItem]:
    """Turn the AI's id list into the snapshot we persist. Drops ids the AI
    invented (i.e. in neither map) — happens occasionally in mock / unstable
    model responses and should not abort the outfit — and shop products past
    `shop_cap`."""
    materialized: list[OutfitItem] = []
    rationales = proposal.per_item_rationales or {}
    shop_by_id = shop_by_id or {}
    shop_used = 0
    for item_id in proposal.item_ids:
        why = rationales.get(str(item_id))
        row = user_items_by_id.get(item_id)
        if row is not None:
            materialized.append(_to_outfit_item(row, why=why))
            continue
        product = shop_by_id.get(item_id)
        if product is None:
            _log.info("outfit.ai_invented_item", item_id=str(item_id))
            continue
        if shop_used >= shop_cap:
            _log.info("outfit.shop_cap_dropped", item_id=str(item_id), cap=shop_cap)
            continue
        shop_used += 1
        materialized.append(_product_to_outfit_item(product, why=why))
    return materialized


def _without_bottoms_under_a_dress(items: list[OutfitItem]) -> list[OutfitItem]:
    """A dress is a complete base; trousers, jeans or a skirt with it read as a
    mistake. The prompt says so — this enforces it when the AI slips."""
    if not any(i.category == "dresses" for i in items):
        return items
    kept = [i for i in items if i.category != "bottoms"]
    if len(kept) != len(items):
        _log.info("outfit.bottoms_with_dress_dropped", dropped=len(items) - len(kept))
    return kept


def _fallback_proposal(
    occasion: Occasion,
    items: Sequence[WardrobeItem | Product],
) -> StructuredOutfitProposal:
    """Used when the AI returned a response we couldn't parse but we still want
    to give the user *something*. Picks a plausible 3-4 item set and writes a
    bland reasoning paragraph. Only callers who explicitly opt in (the
    dashboard) should use this; per-call /generate routes raise instead."""
    pick = _heuristic_pick(items)
    return StructuredOutfitProposal(
        occasion=occasion,
        item_ids=[i.id for i in pick],
        reasoning_short=f"A grounded {occasion.replace('_', ' ')} look from your wardrobe.",
        reasoning_full=(
            "We've combined neutral basics from your wardrobe to put together "
            f"a balanced {occasion.replace('_', ' ')} outfit. "
            "Open the reasoning detail to see why each piece works together."
        ),
        per_item_rationales={},
        compatibility_score=_compatibility_score(pick),
        factors=["Color harmony", "Occasion appropriateness"],
    )


def _heuristic_pick(items: Sequence[WardrobeItem | Product]) -> list[WardrobeItem | Product]:
    """Best-effort 4-item pick: a base (top + bottom, or a dress — never both),
    then shoes and outerwear/accessory. Falls back to whatever's available if
    the wardrobe is missing categories. Callers list wardrobe items before
    shop products, so owned pieces win."""
    by_cat: dict[str, list[WardrobeItem | Product]] = {}
    for it in items:
        by_cat.setdefault(it.category, []).append(it)
    base = ("tops", "bottoms")
    if not all(by_cat.get(c) for c in base) and by_cat.get("dresses"):
        base = ("dresses",)
    pick: list[WardrobeItem | Product] = []
    picked_ids: set[UUID] = set()
    for cat in (*base, "shoes", "outerwear", "accessories"):
        bucket = by_cat.get(cat) or []
        if bucket:
            pick.append(bucket[0])
            picked_ids.add(bucket[0].id)
        if len(pick) >= 4:
            break
    # Category picking can yield <2 items (e.g. everything in one category), which
    # would fail the proposal's min_length. Top up from the rest when we can.
    if len(pick) < _MIN_ITEMS_PER_OUTFIT:
        for it in items:
            if it.id in picked_ids:
                continue
            pick.append(it)
            picked_ids.add(it.id)
            if len(pick) >= _MIN_ITEMS_PER_OUTFIT:
                break
    if not pick:
        pick = list(items[:_MAX_ITEMS_PER_OUTFIT])
    return pick


def _blend_pool(pool: list[WardrobeItem]) -> list[WardrobeItem]:
    """CTO doc 2 transition thresholds — bias candidates as real items grow:
    0 real -> starter only; 1-4 -> all real + up to 10 starter; 5-9 -> all
    real + up to 4 starter; 10+ -> real only. No starter items = no-op."""
    starter = [i for i in pool if i.is_starter_wardrobe]
    if not starter:
        return pool
    real = [i for i in pool if not i.is_starter_wardrobe]
    n = len(real)
    if n == 0:
        return starter
    if n >= 10:
        return real
    cap = 10 if n <= 4 else 4
    if len(starter) > cap:
        starter = random.sample(starter, cap)
    return real + starter


def _items_in_other_sections(db: Session, *, user: User, occasion: Occasion) -> frozenset[UUID]:
    """Item ids in the outfits today's dashboard shows for the *other*
    occasions (latest generation each), so a new outfit can avoid them."""
    return frozenset(
        it.item_id
        for outfit in _latest_per_occasion(_today_outfits(db, user=user))
        if outfit.occasion != occasion
        for it in payload_to_outfit_items(outfit.items)
    )


def _item_suits_weather(item: WardrobeItem, feels_like_c: Optional[float]) -> bool:
    """Season tags vs the temperature. Untagged items suit any weather."""
    if feels_like_c is None or not item.season:
        return True
    if feels_like_c < _COLD_FEELS_LIKE_C:
        return bool(_COLD_SEASONS.intersection(item.season))
    if feels_like_c >= _HOT_FEELS_LIKE_C:
        return bool(_WARM_SEASONS.intersection(item.season))
    return True


def _select_candidates(
    pool: list[WardrobeItem],
    *,
    occasion: Occasion,
    weather: Optional[WeatherSnapshot],
    today: date,
    used_elsewhere: frozenset[UUID] = frozenset(),
) -> list[WardrobeItem]:
    """The wardrobe slice the AI chooses from — narrowed in code so the prompt
    stays small and the AI never has to ask for more.

    Starter blend and occasion filter first. In hot weather outerwear is left
    out. Then per category: prefer season-appropriate items, hold back main
    pieces (`_DISTINCT_PER_SECTION`) already in today's other sections
    (`used_elsewhere`), and skip anything worn in the last `_RECENT_WEAR_DAYS`
    days — each filter is dropped when it would empty the category, so a
    small wardrobe still shares pieces. Finally rank the user's own
    least-recently-worn pieces first (favorites break ties) and keep at most
    `_CANDIDATES_PER_CATEGORY` per category."""
    items = _filter_for_occasion(_blend_pool(pool), occasion)
    feels = weather.feels_like_c if weather is not None else None
    if feels is not None and feels >= _HOT_FEELS_LIKE_C:
        no_outerwear = [i for i in items if i.category != "outerwear"]
        if len(no_outerwear) >= _MIN_ITEMS_PER_OUTFIT:
            items = no_outerwear

    worn_cutoff = today - timedelta(days=_RECENT_WEAR_DAYS - 1)
    by_category: dict[str, list[WardrobeItem]] = {}
    for it in items:
        by_category.setdefault(it.category, []).append(it)

    selected: list[WardrobeItem] = []
    for category, bucket in by_category.items():
        hold_back = category in _DISTINCT_PER_SECTION
        for keep in (
            lambda i: _item_suits_weather(i, feels),
            lambda i: not hold_back or i.id not in used_elsewhere,
            lambda i: i.last_worn is None or i.last_worn < worn_cutoff,
        ):
            narrowed = [i for i in bucket if keep(i)]
            if narrowed:
                bucket = narrowed
        bucket = sorted(
            bucket,
            key=lambda i: (
                bool(i.is_starter_wardrobe),
                i.last_worn or date.min,
                not i.is_favorite,
            ),
        )
        cap = _CANDIDATES_PER_CATEGORY.get(category, _DEFAULT_CANDIDATES_PER_CATEGORY)
        selected += bucket[:cap]
    return selected


async def generate_one(
    *,
    db: Session,
    user: User,
    ai: AIProvider,
    weather: WeatherProvider,
    occasion: Occasion,
    excluded_item_ids: Iterable[UUID] = (),
    creative: bool = False,
    lat: Optional[float] = None,
    lon: Optional[float] = None,
) -> Outfit:
    """Generate + persist one outfit for one occasion. `creative` (regenerate)
    lets up to `_MAX_CREATIVE_SHOP_ITEMS` shop products in even when the
    wardrobe covers the look."""
    all_items = _user_wardrobe(db, user_id=user.id)
    in_wardrobe = {i.product_id for i in all_items if i.product_id}
    products = [
        p for p in catalog_service.tagged_products(db, user=user) if p.id not in in_wardrobe
    ]
    if not all_items and not products:
        raise OutfitError(
            "no_wardrobe",
            "User has no wardrobe items yet — assign a starter wardrobe or add items.",
        )
    excluded_set = set(excluded_item_ids)
    pool = [i for i in all_items if i.id not in excluded_set]
    if not pool:
        # All items excluded (e.g. tiny wardrobe + regenerate); fall back to
        # the full wardrobe so we still produce something.
        pool = all_items

    snap = await _maybe_weather(weather, lat=lat, lon=lon)
    today = user_today(user, now_utc=_now())
    candidates = (
        _select_candidates(
            pool,
            occasion=occasion,
            weather=snap,
            today=today,
            used_elsewhere=_items_in_other_sections(db, user=user, occasion=occasion),
        )
        if pool
        else []
    )
    shop_roles, shop_cap = _shop_plan(
        candidates, shopping_style=user.shopping_style, weather=snap, creative=creative
    )
    shop = _shop_candidates(
        products, roles=shop_roles, occasion=occasion, weather=snap, exclude=excluded_set
    )
    if not shop:
        shop_cap = 0
    if len(candidates) + min(len(shop), shop_cap) < _MIN_ITEMS_PER_OUTFIT:
        # Can't form a valid outfit (the proposal schema requires
        # >= _MIN_ITEMS_PER_OUTFIT). Surface a clean 400 rather than letting
        # the fallback build an invalid proposal and 500.
        raise OutfitError(
            "insufficient_items",
            f"Add at least {_MIN_ITEMS_PER_OUTFIT} wardrobe items to generate an outfit.",
        )
    using_starter = any(i.is_starter_wardrobe for i in candidates)
    items_by_id = {i.id: i for i in all_items}
    shop_by_id = {p.id: p for p in shop}

    def materialize(proposal: StructuredOutfitProposal) -> list[OutfitItem]:
        return _without_bottoms_under_a_dress(
            _materialize_items(
                proposal, user_items_by_id=items_by_id, shop_by_id=shop_by_id, shop_cap=shop_cap
            )
        )

    # Owned pieces first so the heuristic fallback prefers them.
    fallback_pool: list[WardrobeItem | Product] = [*candidates, *shop]
    try:
        proposal = await _ask_ai_for_outfit(
            ai,
            occasion=occasion,
            items=candidates,
            weather=snap,
            style_goals=user.style_goals,
            using_starter_wardrobe=using_starter,
            body_analysis=user.profile.body_analysis if user.profile else None,
            # Consent-gated (§5.5.1): None unless use_measurements_for_fit.
            fit=measurements_service.fit_profile_for_user(db, user=user),
            shop=shop if shop_cap else (),
            shop_cap=shop_cap,
            creative=creative,
            shopping_style=user.shopping_style,
            age_range=user.age_range,
            style_profile=user.style_profile,
            today=today,
            trends=trend_service.prompt_block(
                trend_service.briefs_for(db, shopping_style=user.shopping_style)
            ),
        )
        chosen = materialize(proposal)
    except OutfitError as exc:
        if exc.code != "parse_failed":
            raise
        # Parse failures are recoverable: ship a heuristic outfit so the
        # dashboard never lands the user on an empty state.
        _log.warning("outfit.parse_fallback", reason=str(exc))
        proposal = _fallback_proposal(occasion, fallback_pool)
        chosen = materialize(proposal)

    if len(chosen) < _MIN_ITEMS_PER_OUTFIT:
        # AI hallucinated too many ids; fall back to heuristic + bland reasoning.
        _log.info("outfit.too_few_real_items", returned=len(chosen))
        proposal = _fallback_proposal(occasion, fallback_pool)
        chosen = materialize(proposal)

    if len(chosen) > _MAX_ITEMS_PER_OUTFIT:
        chosen = chosen[:_MAX_ITEMS_PER_OUTFIT]

    # Recompute compatibility on the actual items we kept (the AI's number can
    # diverge once we drop hallucinated ids or capped shop pieces).
    score = _compatibility_score(chosen)

    weather_ctx = _to_weather_context(snap)
    weather_payload = weather_ctx.model_dump(mode="json") if weather_ctx else None

    outfit = Outfit(
        user_id=user.id,
        occasion=occasion,
        items=outfit_items_to_payload(chosen),
        image_url=None,
        ai_reasoning_short=proposal.reasoning_short,
        ai_reasoning_full=proposal.reasoning_full,
        compatibility_score=score,
        weather_context=weather_payload,
        using_starter_wardrobe=using_starter,
        generation_method="anthropic_v1",
        is_logged=False,
        worn_count=0,
    )
    db.add(outfit)
    db.commit()
    db.refresh(outfit)
    _log.info(
        "outfit.generated",
        user_id=str(user.id),
        outfit_id=str(outfit.id),
        occasion=occasion,
        items=len(chosen),
        shop_items=sum(1 for c in chosen if c.product_url and not c.is_starter_wardrobe),
        creative=creative,
        score=score,
        using_starter=using_starter,
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
    """Sequential generation per occasion (not gather): each outfit is
    persisted before the next is built, so `generate_one` can hold back the
    main pieces already used in today's earlier sections."""
    outfits: list[Outfit] = []
    for occ in occasions:
        outfit = await generate_one(
            db=db,
            user=user,
            ai=ai,
            weather=weather,
            occasion=occ,
            lat=lat,
            lon=lon,
        )
        outfits.append(outfit)
    return outfits


# ---------------------------------------------------------------------------
# Today dashboard
# ---------------------------------------------------------------------------


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


def _latest_per_occasion(outfits: list[Outfit]) -> list[Outfit]:
    """The newest outfit for each occasion, in canonical occasion order.

    `_today_outfits` is newest-first and can hold more than one generation for
    the same occasion, because `regenerate` adds a row rather than replacing
    one (the prior generation stays addressable in history). Slicing that list
    directly would show the same occasion twice and push a different occasion
    off the dashboard entirely.
    """
    newest: dict[str, Outfit] = {}
    for outfit in outfits:  # newest first
        newest.setdefault(outfit.occasion, outfit)
    order = {occ: i for i, occ in enumerate(DEFAULT_OCCASIONS)}
    return sorted(
        newest.values(),
        key=lambda o: order.get(o.occasion, len(order)),
    )


def todays_outfits(db: Session, *, user: User) -> list[Outfit]:
    """The outfits the dashboard should show today: the newest generation for
    each occasion, in canonical order, capped at the daily target.

    The dedupe matters — `regenerate` appends a new row rather than replacing
    the old one, so a regenerated occasion would otherwise appear twice and
    push a different occasion off the dashboard.
    """
    return _latest_per_occasion(_today_outfits(db, user=user))[:DAILY_OUTFIT_TARGET]


def wardrobe_ready(db: Session, *, user: User) -> bool:
    """True when an outfit can be formed: enough wardrobe items, or tagged
    shop products to fill the gaps. The dashboard uses this to choose between
    the 'add items' empty state and the generating/skeleton state."""
    if len(_user_wardrobe(db, user_id=user.id)) >= _MIN_ITEMS_PER_OUTFIT:
        return True
    return bool(catalog_service.tagged_products(db, user=user))


def pending_occasions(db: Session, *, user: User) -> list[Occasion]:
    """Default occasions that still lack a today-outfit, in canonical order.

    Drives the dashboard's per-occasion skeletons. Empty when the wardrobe isn't
    ready (nothing can be generated) or every default occasion already has one."""
    if not wardrobe_ready(db, user=user):
        return []
    have = {o.occasion for o in _today_outfits(db, user=user)}
    return [occ for occ in DEFAULT_OCCASIONS if occ not in have]


async def ensure_one(
    *,
    db: Session,
    user: User,
    ai: AIProvider,
    weather: WeatherProvider,
    occasion: Occasion,
    lat: Optional[float] = None,
    lon: Optional[float] = None,
) -> Outfit:
    """Idempotent single-occasion generation for the dashboard's incremental fill.

    Returns the existing today-outfit for `occasion` if one is already present
    (no AI call, so a double-fire from the client is cheap), otherwise generates
    and persists a fresh one via `generate_one`. This is the *free* daily-fill
    path — callers must NOT charge weekly usage for it, matching the prior
    inline-dashboard-generation behaviour.
    """
    for existing in _today_outfits(db, user=user):
        if existing.occasion == occasion:
            return existing
    return await generate_one(
        db=db,
        user=user,
        ai=ai,
        weather=weather,
        occasion=occasion,
        lat=lat,
        lon=lon,
    )


async def load_dashboard_outfits(
    *,
    db: Session,
    user: User,
    ai: AIProvider,
    weather: WeatherProvider,
    request: Optional[GenerateOutfitsRequest] = None,
) -> tuple[list[Outfit], bool]:
    """Returns (outfits, were_just_generated)."""
    # One card per occasion: older same-day generations sit silent in history.
    existing = _latest_per_occasion(_today_outfits(db, user=user))
    if len(existing) >= DAILY_OUTFIT_TARGET:
        return existing[:DAILY_OUTFIT_TARGET], False

    # Nothing to build from (no wardrobe and no tagged products in the user's
    # genders) — return whatever exists (usually nothing) so the dashboard
    # renders its "add a few items" empty state instead of raising.
    # (Force-generate via generate_for_user still raises a clean OutfitError.)
    if not wardrobe_ready(db, user=user):
        return existing, False

    occasions = (
        list(request.occasions) if request and request.occasions else list(DEFAULT_OCCASIONS)
    )
    # Top up if some outfits already exist (e.g. a single regenerate from
    # earlier). Generate enough to reach the daily target.
    needed = DAILY_OUTFIT_TARGET - len(existing)
    occasions = occasions[:needed]
    fresh = await generate_for_user(
        db=db,
        user=user,
        ai=ai,
        weather=weather,
        occasions=occasions,
        lat=request.lat if request else None,
        lon=request.lon if request else None,
    )
    return fresh + existing, True


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
    """Replaces the existing outfit row with a fresh AI-generated version,
    excluding the prior outfit's items so the result is visibly different.
    Creative: may mix in up to 2 shop products the user doesn't own."""
    prior = _get_outfit_owned(db, user=user, outfit_id=outfit_id)
    prior_items = payload_to_outfit_items(prior.items)
    excluded = {i.item_id for i in prior_items}
    fresh = await generate_one(
        db=db,
        user=user,
        ai=ai,
        weather=weather,
        occasion=prior.occasion,  # type: ignore[arg-type]
        excluded_item_ids=excluded,
        creative=True,
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
    from app.services import banner_service, starter_wardrobe_service

    assignment = starter_wardrobe_service.get_assignment(db, user_id=user_id)
    if assignment is None or not assignment.is_active:
        return False
    if starter_wardrobe_service.real_item_count(db, user_id=user_id) >= 5:
        return False
    return not banner_service.is_dismissed(
        db, user_id=user_id, banner="starter_wardrobe"
    )
