"""Phase 6c — outfit generation, mix-and-match, log + history.

Architecture:

  * `generate_for_user` orchestrates the full pipeline for one occasion:
    pick candidate items → ask Claude for a structured proposal →
    validate item ids belong to the user → persist `outfits` row.
  * Today dashboard reuses `generate_for_user` for each of the three occasions.
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
  * `OutfitError("ai_call_failed", ...)`       -> route → 502 (Claude blew up)
  * `OutfitError("parse_failed", ...)`         -> route → 502
  * `OutfitError("invalid_swap", ...)`         -> route → 400
"""
from __future__ import annotations

import asyncio
import json
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

from app.db.models import Outfit, OutfitHistory, StreakTracking, User, WardrobeItem
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


def _today() -> date:
    return _now().date()


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
    return OutfitItem(
        item_id=row.id,
        name=row.name,
        category=row.category,
        primary_image_url=row.primary_image_url,
        color_name=row.color_name,
        formality=row.formality,
        why_it_works=why,
        is_starter_wardrobe=row.is_starter_wardrobe,
    )


# ---------------------------------------------------------------------------
# AI prompt + parsing
# ---------------------------------------------------------------------------


_SYSTEM_PROMPT = (
    "You are Drape, an AI fashion stylist. You help users build outfits from "
    "their existing wardrobe. You always ground recommendations in items the "
    "user actually owns. You never invent items. You write in a warm, "
    "encouraging, second-person voice (\"this top works because…\")."
)


def _build_user_prompt(
    *,
    occasion: Occasion,
    items: Sequence[WardrobeItem],
    weather: Optional[WeatherSnapshot],
    style_goals: Optional[list[str]],
    using_starter_wardrobe: bool,
) -> str:
    item_lines = []
    for it in items:
        descriptors = [
            it.category,
            it.color_name or "",
            it.formality or "",
            it.pattern or "",
            "starter" if it.is_starter_wardrobe else "",
        ]
        descriptor_str = " | ".join(d for d in descriptors if d)
        item_lines.append(f'- id={it.id} name="{it.name}" [{descriptor_str}]')

    weather_block = "Weather: not available."
    if weather is not None:
        weather_block = (
            f"Weather: {weather.temp_c:.0f}°C ({weather.condition}), "
            f"feels like {weather.feels_like_c:.0f}°C."
        )

    goals_block = (
        f"Style goals: {', '.join(style_goals)}." if style_goals else "Style goals: none."
    )

    starter_note = ""
    if using_starter_wardrobe:
        starter_note = (
            "Note: this user is on a starter wardrobe (curated bootstrap kit). "
            "Encourage them in your reasoning to add their own items. "
        )

    return (
        f"Build ONE outfit for the occasion: {occasion}.\n\n"
        f"{weather_block}\n{goals_block}\n{starter_note}\n"
        f"Available items ({len(items)}):\n" + "\n".join(item_lines) + "\n\n"
        "Respond with ONLY a JSON object — no prose, no markdown, no code "
        "fences. Schema:\n"
        "{\n"
        f'  "occasion": "{occasion}",\n'
        '  "item_ids": ["uuid", "uuid", ...]   // 2-6 ids drawn from the list above,\n'
        '  "reasoning_short": "1-2 sentence hook for the card",\n'
        '  "reasoning_full": "3-4 sentences, references items by name, '
        'covers color harmony / occasion / weather",\n'
        '  "per_item_rationales": {"<item_id>": "why this piece fits"},\n'
        '  "compatibility_score": 0-100 integer,\n'
        '  "factors": ["Color harmony", "Occasion appropriateness", ...]\n'
        "}\n"
    )


def _parse_proposal(text: str) -> StructuredOutfitProposal:
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
        return StructuredOutfitProposal.model_validate(payload)
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
) -> StructuredOutfitProposal:
    prompt = _build_user_prompt(
        occasion=occasion,
        items=items,
        weather=weather,
        style_goals=style_goals,
        using_starter_wardrobe=using_starter_wardrobe,
    )
    try:
        text = await ai.chat(
            [{"role": "user", "content": prompt}],
            system=_SYSTEM_PROMPT,
            max_tokens=1200,
        )
    except AIProviderError as exc:
        _log.warning("outfit.ai_call_failed", code=exc.code, error=str(exc))
        raise OutfitError("ai_call_failed", str(exc)) from exc

    proposal = _parse_proposal(text)
    return proposal


def _materialize_items(
    proposal: StructuredOutfitProposal,
    *,
    user_items_by_id: dict[UUID, WardrobeItem],
) -> list[OutfitItem]:
    """Turn the AI's id list into the snapshot we persist. Drops ids the AI
    invented (i.e. not in user_items_by_id) — happens occasionally in mock /
    unstable model responses and should not abort the outfit."""
    materialized: list[OutfitItem] = []
    rationales = proposal.per_item_rationales or {}
    for item_id in proposal.item_ids:
        row = user_items_by_id.get(item_id)
        if row is None:
            _log.info("outfit.ai_invented_item", item_id=str(item_id))
            continue
        why = rationales.get(str(item_id))
        materialized.append(_to_outfit_item(row, why=why))
    return materialized


def _fallback_proposal(
    occasion: Occasion,
    items: Sequence[WardrobeItem],
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


def _heuristic_pick(items: Sequence[WardrobeItem]) -> list[WardrobeItem]:
    """Best-effort 4-item pick: 1 top, 1 bottom, 1 shoes, 1 outerwear/accessory.
    Falls back to whatever's available if the wardrobe is missing categories."""
    by_cat: dict[str, list[WardrobeItem]] = {}
    for it in items:
        by_cat.setdefault(it.category, []).append(it)
    pick: list[WardrobeItem] = []
    picked_ids: set[UUID] = set()
    for cat in ("tops", "dresses", "bottoms", "shoes", "outerwear", "accessories"):
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


async def generate_one(
    *,
    db: Session,
    user: User,
    ai: AIProvider,
    weather: WeatherProvider,
    occasion: Occasion,
    excluded_item_ids: Iterable[UUID] = (),
    lat: Optional[float] = None,
    lon: Optional[float] = None,
) -> Outfit:
    """Generate + persist one outfit for one occasion."""
    all_items = _user_wardrobe(db, user_id=user.id)
    if not all_items:
        raise OutfitError(
            "no_wardrobe",
            "User has no wardrobe items yet — assign a starter wardrobe or add items.",
        )
    if len(all_items) < _MIN_ITEMS_PER_OUTFIT:
        # A single-item wardrobe can't form a valid outfit (the proposal schema
        # requires >= _MIN_ITEMS_PER_OUTFIT). Surface a clean 400 rather than
        # letting the fallback build an invalid proposal and 500.
        raise OutfitError(
            "insufficient_items",
            f"Add at least {_MIN_ITEMS_PER_OUTFIT} wardrobe items to generate an outfit.",
        )
    excluded_set = set(excluded_item_ids)
    pool = [i for i in all_items if i.id not in excluded_set]
    if not pool:
        # All items excluded (e.g. tiny wardrobe + regenerate); fall back to
        # the full wardrobe so we still produce something.
        pool = all_items

    candidates = _filter_for_occasion(pool, occasion)
    using_starter = any(i.is_starter_wardrobe for i in candidates)

    snap = await _maybe_weather(weather, lat=lat, lon=lon)
    items_by_id = {i.id: i for i in all_items}

    try:
        proposal = await _ask_ai_for_outfit(
            ai,
            occasion=occasion,
            items=candidates,
            weather=snap,
            style_goals=user.style_goals,
            using_starter_wardrobe=using_starter,
        )
        chosen = _materialize_items(proposal, user_items_by_id=items_by_id)
    except OutfitError as exc:
        if exc.code != "parse_failed":
            raise
        # Parse failures are recoverable: ship a heuristic outfit so the
        # dashboard never lands the user on an empty state.
        _log.warning("outfit.parse_fallback", reason=str(exc))
        proposal = _fallback_proposal(occasion, candidates)
        chosen = _materialize_items(proposal, user_items_by_id=items_by_id)

    if len(chosen) < _MIN_ITEMS_PER_OUTFIT:
        # AI hallucinated too many ids; fall back to heuristic + bland reasoning.
        _log.info("outfit.too_few_real_items", returned=len(chosen))
        proposal = _fallback_proposal(occasion, candidates)
        chosen = _materialize_items(proposal, user_items_by_id=items_by_id)

    if len(chosen) > _MAX_ITEMS_PER_OUTFIT:
        chosen = chosen[:_MAX_ITEMS_PER_OUTFIT]

    # Recompute compatibility on the actual items we kept (the AI's number can
    # diverge once we drop hallucinated ids).
    item_rows = [items_by_id[c.item_id] for c in chosen]
    score = _compatibility_score(item_rows)

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
    """Sequential generation per occasion. Sequential (not gather) keeps the
    items used in outfit N out of outfit N+1 only when we explicitly want to
    diversify; CTO doc shows three different occasions per day so AI chooses
    independently per call."""
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


def _outfits_generated_today(db: Session, *, user_id: UUID) -> int:
    start = datetime.combine(_today(), datetime.min.time(), tzinfo=timezone.utc)
    return int(
        db.scalar(
            select(func.count(Outfit.id)).where(
                Outfit.user_id == user_id, Outfit.created_at >= start
            )
        )
        or 0
    )


def _today_outfits(db: Session, *, user_id: UUID) -> list[Outfit]:
    start = datetime.combine(_today(), datetime.min.time(), tzinfo=timezone.utc)
    return list(
        db.scalars(
            select(Outfit)
            .where(Outfit.user_id == user_id, Outfit.created_at >= start)
            .order_by(Outfit.created_at.desc())
        ).all()
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
    existing = _today_outfits(db, user_id=user.id)
    if len(existing) >= DAILY_OUTFIT_TARGET:
        # Newest 3 — older same-day generations sit silent in history.
        return existing[:DAILY_OUTFIT_TARGET], False

    # An outfit needs at least _MIN_ITEMS_PER_OUTFIT pieces. With fewer, there's
    # nothing to generate — return whatever exists (usually nothing) so the
    # dashboard renders its "add a few items" empty state instead of raising.
    # (Force-generate via generate_for_user still raises a clean OutfitError.)
    if len(_user_wardrobe(db, user_id=user.id)) < _MIN_ITEMS_PER_OUTFIT:
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

    # Recompute compatibility from the wardrobe rows of the final lineup.
    final_ids = [u.item_id for u in updated]
    final_rows_by_id = {
        r.id: r
        for r in db.scalars(
            select(WardrobeItem).where(
                WardrobeItem.user_id == user.id, WardrobeItem.id.in_(final_ids)
            )
        ).all()
    }
    final_rows = [final_rows_by_id[i] for i in final_ids if i in final_rows_by_id]
    score = _compatibility_score(final_rows)

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
    excluding the prior outfit's items so the result is visibly different."""
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
            message = f"{total_logged} outfits logged! ✨ You're a Drape pro now."
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
    streak = _get_or_create_streak(db, user_id=user.id)
    today = _today()

    already_today = (
        streak.last_logged_date == today
        and outfit.is_logged
        and outfit.logged_at is not None
        and outfit.logged_at.date() == today
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


def _filter_window(filter_: HistoryFilter) -> Optional[date]:
    today = _today()
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
    window_start = _filter_window(filter_)
    if window_start is not None:
        cutoff = datetime.combine(window_start, datetime.min.time(), tzinfo=timezone.utc)
        base = base.where(OutfitHistory.logged_at >= cutoff)
    rows = list(db.execute(base).all())
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
    today = _today()
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


def _profile_incomplete(user: User) -> bool:
    """Heuristic mirroring CTO doc 2 — show resume banner when measurements
    aren't done yet. We treat onboarding_completed as the truthful signal."""
    return not user.onboarding_completed


def _is_starter_wardrobe_active(outfits: Sequence[Outfit]) -> bool:
    return any(o.using_starter_wardrobe for o in outfits)
