"""Phase 6d — wardrobe analytics rollups.

All four reports read from `wardrobe_items` + `wardrobe_wear_log` + `outfit_history`
+ `streak_tracking` directly. No precomputed materialized views — the dataset
per user is small (cap 30 items free, low hundreds for pro), so per-request
rollups are cheap and avoid a stale-cache class of bugs.
"""
from __future__ import annotations

from collections import Counter, defaultdict
from datetime import date, datetime, timedelta, timezone
from typing import Optional

import structlog
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.db.models import (
    OutfitHistory,
    StreakTracking,
    User,
    WardrobeItem,
    WardrobeWearLog,
)
from app.schemas.analytics import (
    CostPerWearCategory,
    CostPerWearItem,
    CostPerWearReport,
    IntelligenceColorBucket,
    IntelligenceReport,
    IntelligenceUnderutilized,
    UtilizationScore,
    WeeklyReport,
    WeeklyReportTopItem,
)

_log = structlog.get_logger("analytics")

UTILIZATION_WINDOW_DAYS = 30
INTELLIGENCE_UNDERUTILIZED_LIMIT = 10
INTELLIGENCE_TOP_PALETTE_LIMIT = 8
WEEKLY_TOP_ITEMS_LIMIT = 5


def _today() -> date:
    return datetime.now(timezone.utc).date()


def _items_for(db: Session, *, user: User) -> list[WardrobeItem]:
    return list(
        db.scalars(
            select(WardrobeItem).where(WardrobeItem.user_id == user.id)
        ).all()
    )


# ---------------------------------------------------------------------------
# Cost per wear
# ---------------------------------------------------------------------------


def cost_per_wear(db: Session, *, user: User) -> CostPerWearReport:
    items = _items_for(db, user=user)
    item_rows = [
        CostPerWearItem(
            item_id=i.id,
            name=i.name,
            category=i.category,
            purchase_price=float(i.purchase_price) if i.purchase_price is not None else None,
            worn_count=i.worn_count,
            cost_per_wear=(
                float(i.cost_per_wear) if i.cost_per_wear is not None else None
            ),
        )
        for i in items
    ]
    by_cat: dict[str, list[WardrobeItem]] = defaultdict(list)
    for i in items:
        by_cat[i.category].append(i)

    cats: list[CostPerWearCategory] = []
    for cat, members in sorted(by_cat.items()):
        total_price = sum(
            float(i.purchase_price) for i in members if i.purchase_price is not None
        )
        total_wears = sum(i.worn_count for i in members)
        avg_cpw = (total_price / total_wears) if total_wears > 0 and total_price > 0 else None
        cats.append(
            CostPerWearCategory(
                category=cat,
                item_count=len(members),
                total_purchase_price=round(total_price, 2),
                total_wears=total_wears,
                average_cost_per_wear=round(avg_cpw, 2) if avg_cpw is not None else None,
            )
        )

    return CostPerWearReport(
        items=item_rows,
        categories=cats,
        total_items_with_price=sum(1 for i in items if i.purchase_price is not None),
        total_items_with_wears=sum(1 for i in items if i.worn_count > 0),
    )


# ---------------------------------------------------------------------------
# Utilization score
# ---------------------------------------------------------------------------


def _label_for_score(score: int) -> str:
    if score >= 70:
        return "High"
    if score >= 40:
        return "Moderate"
    return "Low"


def utilization_score(db: Session, *, user: User) -> UtilizationScore:
    """Score 0-100 = % of items worn at least once in the last 30 days,
    rounded. With 0 items, returns 0/Low."""
    items = _items_for(db, user=user)
    total = len(items)
    if total == 0:
        return UtilizationScore(
            score=0,
            items_worn_recently=0,
            items_total=0,
            days_window=UTILIZATION_WINDOW_DAYS,
            label="Low",
        )
    cutoff = _today() - timedelta(days=UTILIZATION_WINDOW_DAYS)
    item_ids = [i.id for i in items]
    recent_ids = set(
        db.scalars(
            select(WardrobeWearLog.item_id)
            .where(
                WardrobeWearLog.user_id == user.id,
                WardrobeWearLog.item_id.in_(item_ids),
                WardrobeWearLog.worn_date >= cutoff,
            )
            .distinct()
        ).all()
    )
    score = round(len(recent_ids) / total * 100)
    return UtilizationScore(
        score=score,
        items_worn_recently=len(recent_ids),
        items_total=total,
        days_window=UTILIZATION_WINDOW_DAYS,
        label=_label_for_score(score),
    )


# ---------------------------------------------------------------------------
# Weekly report (free teaser)
# ---------------------------------------------------------------------------


def _monday_this_week() -> date:
    today = _today()
    return today - timedelta(days=today.weekday())


def weekly_report(db: Session, *, user: User) -> WeeklyReport:
    week_start = _monday_this_week()
    week_start_dt = datetime.combine(week_start, datetime.min.time(), tzinfo=timezone.utc)

    outfits_logged = int(
        db.scalar(
            select(func.count(OutfitHistory.id)).where(
                OutfitHistory.user_id == user.id,
                OutfitHistory.logged_at >= week_start_dt,
            )
        )
        or 0
    )
    distinct_items = int(
        db.scalar(
            select(func.count(func.distinct(WardrobeWearLog.item_id))).where(
                WardrobeWearLog.user_id == user.id,
                WardrobeWearLog.worn_date >= week_start,
            )
        )
        or 0
    )
    # Top items this week, by wear count.
    top_rows = list(
        db.execute(
            select(
                WardrobeWearLog.item_id,
                func.count(WardrobeWearLog.id).label("c"),
            )
            .where(
                WardrobeWearLog.user_id == user.id,
                WardrobeWearLog.worn_date >= week_start,
            )
            .group_by(WardrobeWearLog.item_id)
            .order_by(func.count(WardrobeWearLog.id).desc())
            .limit(WEEKLY_TOP_ITEMS_LIMIT)
        ).all()
    )
    name_by_id: dict = {}
    if top_rows:
        ids = [r[0] for r in top_rows]
        rows = db.scalars(
            select(WardrobeItem).where(WardrobeItem.id.in_(ids))
        ).all()
        name_by_id = {i.id: i.name for i in rows}
    top_items = [
        WeeklyReportTopItem(
            item_id=item_id,
            name=name_by_id.get(item_id, "(deleted)"),
            worn_count=int(c),
        )
        for item_id, c in top_rows
    ]

    streak = db.scalar(
        select(StreakTracking).where(StreakTracking.user_id == user.id)
    )
    streak_days = streak.current_streak if streak else 0

    return WeeklyReport(
        week_start_date=week_start,
        outfits_logged=outfits_logged,
        items_worn_distinct=distinct_items,
        top_items=top_items,
        streak_days=streak_days,
    )


# ---------------------------------------------------------------------------
# Intelligence report (Pro)
# ---------------------------------------------------------------------------


def intelligence_report(db: Session, *, user: User) -> IntelligenceReport:
    items = _items_for(db, user=user)
    total_items = len(items)
    total_wears = sum(i.worn_count for i in items)
    total_price = sum(
        float(i.purchase_price) for i in items if i.purchase_price is not None
    )
    avg_cpw: Optional[float] = None
    if total_wears > 0 and total_price > 0:
        avg_cpw = round(total_price / total_wears, 2)

    # Color palette: top N color_name buckets weighted by wear.
    color_counts: Counter[str] = Counter()
    color_wears: Counter[str] = Counter()
    for i in items:
        if i.color_name:
            color_counts[i.color_name] += 1
            color_wears[i.color_name] += i.worn_count
    top_colors = sorted(
        color_counts.keys(), key=lambda c: (-color_wears[c], -color_counts[c])
    )[:INTELLIGENCE_TOP_PALETTE_LIMIT]
    palette = [
        IntelligenceColorBucket(
            color_name=c,
            item_count=color_counts[c],
            worn_count=color_wears[c],
        )
        for c in top_colors
    ]

    # Underutilized: lowest worn_count first; ties broken by oldest last_worn.
    sorted_underused = sorted(
        items,
        key=lambda i: (
            i.worn_count,
            i.last_worn or date(1970, 1, 1),
        ),
    )[:INTELLIGENCE_UNDERUTILIZED_LIMIT]
    today = _today()
    underused = [
        IntelligenceUnderutilized(
            item_id=i.id,
            name=i.name,
            category=i.category,
            worn_count=i.worn_count,
            days_since_last_worn=(
                (today - i.last_worn).days if i.last_worn is not None else None
            ),
        )
        for i in sorted_underused
    ]

    # Most worn category (by total wears).
    by_cat_wears: Counter[str] = Counter()
    for i in items:
        by_cat_wears[i.category] += i.worn_count
    most_worn = (
        by_cat_wears.most_common(1)[0][0] if by_cat_wears and by_cat_wears.most_common(1)[0][1] > 0 else None
    )

    # Real-vs-starter ratio: 0.0 = all starter, 1.0 = all real.
    if total_items == 0:
        real_ratio = 0.0
    else:
        real = sum(1 for i in items if not i.is_starter_wardrobe)
        real_ratio = round(real / total_items, 4)

    return IntelligenceReport(
        total_items=total_items,
        total_wears=total_wears,
        average_cost_per_wear=avg_cpw,
        color_palette=palette,
        underutilized_items=underused,
        most_worn_category=most_worn,
        real_vs_starter_ratio=real_ratio,
    )
