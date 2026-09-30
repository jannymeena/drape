"""Weekly trend brief — what's in fashion right now, researched on the web.

The model only knows fashion up to its training data. Once a week per
audience (womenswear / menswear) the trend worker asks it to search current
fashion coverage and write a short, practical brief; the newest brief is fed
to the outfit and advisor prompts (`prompt_block`). The research sends no user
data — only the audience, the month and the country.
"""
from __future__ import annotations

from datetime import date, datetime, timedelta, timezone
from typing import Optional

import structlog
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.db.models import TrendBrief
from app.services.providers.ai.base import AIProvider, AIProviderError

_log = structlog.get_logger("trends")

AUDIENCES = ("womens", "mens")
_AUDIENCE_LABEL = {"womens": "womenswear", "mens": "menswear"}

# A brief is refreshed once it is this old…
REFRESH_AFTER = timedelta(days=7)
# …and stops being used at all past this age (a stale "trend" is worse than none).
MAX_AGE = timedelta(days=21)
# Hard cap on what enters every prompt.
_MAX_BRIEF_CHARS = 2500
# pg_try_advisory_xact_lock keys (one per audience) so several server
# processes never research the same brief twice.
_LOCK_KEY_BASE = 0x7E4D_B000
# Where the app's users are (PIPEDA / ca-central-1); steers the search.
_COUNTRY = "CA"

_SYSTEM = (
    "You are a fashion editor briefing a team of personal stylists who dress "
    "everyday clients from the clothes they already own."
)


def _season(d: date) -> str:
    return ("winter", "spring", "summer", "fall")[(d.month % 12) // 3]


def research_prompt(audience: str, today: date) -> str:
    label = _AUDIENCE_LABEL[audience]
    return (
        f"Research what's fashionable in {label} right now: {today:%B %Y}, "
        f"{_season(today)} in Canada. Search the web first and base every point "
        "on current fashion coverage (e.g. Vogue, Harper's Bazaar, Elle, The Cut, "
        "Who What Wear, GQ, retailer trend reports), preferring the last two "
        "months. Then write 6-10 bullet points a stylist can apply to everyday "
        "wardrobes: key silhouettes and cuts, colours, pairings (which shoes with "
        "which dresses or trousers), footwear, outerwear, accessories, and what's "
        "fading. Each bullet is one plain sentence of at most 25 words, starting "
        "with \"- \" (no bold, no headings). Wearable guidance, not runway-only "
        "looks. Reply with only the bullet points: no introduction, no sources."
    )


def _clip(brief: str) -> str:
    """Cap what enters every prompt, cutting at a bullet boundary so no
    bullet is left half-written."""
    if len(brief) <= _MAX_BRIEF_CHARS:
        return brief
    cut = brief.rfind("\n-", 0, _MAX_BRIEF_CHARS)
    return brief[:cut].rstrip() if cut > 0 else brief[:_MAX_BRIEF_CHARS]


def latest(db: Session, *, audience: str) -> Optional[TrendBrief]:
    return db.scalars(
        select(TrendBrief)
        .where(TrendBrief.audience == audience)
        .order_by(TrendBrief.created_at.desc())
        .limit(1)
    ).first()


def refresh_due(db: Session, *, audience: str, now: datetime) -> bool:
    row = latest(db, audience=audience)
    return row is None or now - row.created_at >= REFRESH_AFTER


async def generate(
    db: Session, *, ai: AIProvider, audience: str, model: str, today: date
) -> TrendBrief:
    """Research + store one brief. Raises AIProviderError on failure (the
    worker retries later); an empty answer counts as a failure."""
    result = await ai.web_research(
        research_prompt(audience, today), model=model, system=_SYSTEM, country=_COUNTRY
    )
    brief = _clip(result.text.strip())
    if not brief:
        raise AIProviderError("empty_research", "web research returned no brief")
    row = TrendBrief(
        audience=audience, brief=brief, sources=result.sources, model=result.model
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    _log.info("trends.brief_saved", audience=audience, sources=len(result.sources))
    return row


async def refresh_if_due(
    db: Session, *, ai: AIProvider, audience: str, model: str, now: datetime
) -> Optional[TrendBrief]:
    """Research a new brief when the newest is `REFRESH_AFTER` old (or there
    is none). Holds a per-audience advisory lock for the whole research, so a
    second process skips instead of paying for a duplicate. Returns the new
    row, or None when nothing was due or another process is on it."""
    lock = _LOCK_KEY_BASE + AUDIENCES.index(audience)
    if not db.scalar(select(func.pg_try_advisory_xact_lock(lock))):
        db.rollback()
        return None
    if not refresh_due(db, audience=audience, now=now):
        db.rollback()
        return None
    return await generate(db, ai=ai, audience=audience, model=model, today=now.date())


def briefs_for(
    db: Session, *, shopping_style: Optional[str], now: Optional[datetime] = None
) -> list[TrendBrief]:
    """Fresh-enough briefs for a user: their audience, or both when they
    shop for everything (or haven't said)."""
    now = now or datetime.now(timezone.utc)
    audiences = (shopping_style,) if shopping_style in AUDIENCES else AUDIENCES
    rows = [latest(db, audience=a) for a in audiences]
    return [r for r in rows if r is not None and now - r.created_at < MAX_AGE]


def prompt_block(briefs: list[TrendBrief]) -> str:
    """The prompt section for `briefs`; empty when there are none, so the
    stylist falls back to timeless styling."""
    if not briefs:
        return ""
    parts = []
    for b in briefs:
        when = f"{b.created_at.day} {b.created_at:%B %Y}"
        head = f"{_AUDIENCE_LABEL[b.audience].capitalize()}, researched {when}"
        parts.append(f"{head}:\n{b.brief}")
    return (
        "What's in fashion right now (from current fashion coverage). Use it "
        "where it suits the wearer and the pieces available; fit, the occasion "
        "and their own style come first:\n" + "\n\n".join(parts) + "\n"
    )
