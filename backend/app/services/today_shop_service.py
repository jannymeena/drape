"""Today's "Shop the look": up to three catalog products for the day, and
why they were picked — no AI call, from the products' tags.

In order, until three are picked:

1. **The look** (starter mode): the pieces of today's starter outfit — the
   outfit is the thing to shop.
2. **Missing** (own wardrobe): what today's plan couldn't be styled
   without (`missing_roles`, e.g. a top for a formal event); when today's
   looks are fine, the wardrobe's category gaps (`shop_service.gap_analysis`,
   e.g. 0 of 3 shoes). One product per missing role or category in turn.
3. **Related**: products for today's weather (`weather_needs`: rain → rain
   wear, sun → caps and hats, cold → coats, beanies, scarves, heat → light
   pieces); with no particular weather, accessories for today's occasion;
   else anything.

Within a group, products that suit today's occasion and weather come
first, and ties are broken by a per-user, per-day shuffle, so the row
changes day to day but not between opens.

`kind` says which rule picked the first product; the client shows the
matching heading.
"""
from __future__ import annotations

import hashlib
from dataclasses import dataclass
from datetime import date
from typing import Iterable, Optional, Protocol
from uuid import UUID

from sqlalchemy.orm import Session

from app.core.localtime import user_today
from app.db.models import Product, User
from app.schemas.outfit import payload_to_outfit_items
from app.services import catalog_service, outfit_service, shop_service

MAX_PICKS = 3

# What Today's weather calls for. Feels-like thresholds in °C.
_COLD_AT_OR_BELOW = 10.0
_HEAT_AT_OR_ABOVE = 26.0
_SUN_AT_OR_ABOVE = 16.0

_TITLES = {
    "look": "Shop today's look",
    "missing": "To complete today's look",
    "gap": "Missing from your wardrobe",
    "rain": "For today's rain",
    "sun": "For the sun today",
    "cold": "For the cold today",
    "heat": "For the heat today",
    "occasion": "To finish the look",
    "picks": "Picked for you",
}


class _Weather(Protocol):
    condition: str
    feels_like_c: float


def weather_needs(weather: Optional[_Weather]) -> list[str]:
    """The weather tags today calls for, most pressing first (rain before
    cold before sun before heat); [] for mild, unremarkable weather or none
    known."""
    if weather is None:
        return []
    condition = (weather.condition or "").lower()
    feels = weather.feels_like_c
    needs: list[str] = []
    if condition in ("rain", "thunderstorm"):
        needs.append("rain")
    if condition == "snow" or feels <= _COLD_AT_OR_BELOW:
        needs.append("cold")
    if condition == "clear" and feels >= _SUN_AT_OR_ABOVE:
        needs.append("sun")
    if feels >= _HEAT_AT_OR_ABOVE:
        needs.append("heat")
    return needs


@dataclass(frozen=True)
class TodayShop:
    kind: str  # look | missing | gap | rain | sun | cold | heat | occasion | picks
    title: str
    products: list[Product]


def _daily_order(user: User, day: date, product: Product) -> str:
    return hashlib.sha256(f"{user.id}:{day.isoformat()}:{product.id}".encode()).hexdigest()


def _ranked(
    products: Iterable[Product],
    *,
    user: User,
    day: date,
    occasion: Optional[str],
    needs: list[str],
) -> list[Product]:
    """Best for today first: suits the occasion (x2), matches the weather;
    then the day's shuffle."""

    def score(p: Product) -> int:
        fits_occasion = occasion is not None and occasion in (p.occasions or [])
        return 2 * fits_occasion + len(set(p.weather or []) & set(needs))

    return sorted(products, key=lambda p: (-score(p), _daily_order(user, day, p)))


def _round_robin(groups: list[list[Product]], *, taken: set[UUID], limit: int) -> list[Product]:
    """One from each group in turn, skipping ones already picked."""
    picked: list[Product] = []
    queues = [list(g) for g in groups]
    while len(picked) < limit and any(queues):
        for queue in queues:
            while queue and queue[0].id in taken:
                queue.pop(0)
            if queue and len(picked) < limit:
                p = queue.pop(0)
                picked.append(p)
                taken.add(p.id)
    return picked


def today_picks(db: Session, *, user: User, weather: Optional[_Weather]) -> TodayShop:
    state = outfit_service.today_outfits_state(db, user=user)
    occasion = state.styling.occasion if state.styling else None
    needs = weather_needs(weather)
    day = user_today(user)
    pool = catalog_service.tagged_products(db, user=user)
    by_id = {p.id: p for p in pool}

    def ranked(products: Iterable[Product]) -> list[Product]:
        return _ranked(products, user=user, day=day, occasion=occasion, needs=needs)

    picks: list[Product] = []
    taken: set[UUID] = set()
    kind: Optional[str] = None

    if state.mode == outfit_service.MODE_STARTER:
        # 1. Starter mode: today's outfit is the look to shop.
        for outfit in state.outfits:
            for item in payload_to_outfit_items(outfit.items):
                p = by_id.get(item.product_id) if item.product_id else None
                if p is not None and p.id not in taken and len(picks) < MAX_PICKS:
                    picks.append(p)
                    taken.add(p.id)
        kind = "look" if picks else None
    else:
        # 2. Own wardrobe: what today's look needs, else the wardrobe's gaps.
        groups: list[list[Product]] = []
        if not state.wardrobe_ready and state.missing_roles:
            kind = "missing"
            groups = [ranked(p for p in pool if p.role == role) for role in state.missing_roles]
        elif gaps := shop_service.gap_analysis(db, user=user):
            kind = "gap"
            groups = [ranked(p for p in pool if p.category == g["category"]) for g in gaps]
        picks = _round_robin(groups, taken=taken, limit=MAX_PICKS)
        if not picks:
            kind = None

    # 3. Related: today's weather, else the occasion's accessories, else anything.
    if len(picks) < MAX_PICKS:
        related_kind, related = _related(pool, needs=needs, occasion=occasion)
        more = [p for p in ranked(related) if p.id not in taken][: MAX_PICKS - len(picks)]
        picks.extend(more)
        if kind is None:
            kind = related_kind if more else "picks"
    kind = kind or "picks"
    return TodayShop(kind=kind, title=_TITLES[kind], products=picks)


def _related(
    pool: list[Product], *, needs: list[str], occasion: Optional[str]
) -> tuple[str, list[Product]]:
    for need in needs:
        matching = [p for p in pool if need in (p.weather or [])]
        if matching:
            return need, matching
    if occasion is not None:
        accessories = [
            p for p in pool if p.role == "accessory" and occasion in (p.occasions or [])
        ]
        if accessories:
            return "occasion", accessories
    return "picks", list(pool)
