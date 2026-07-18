"""Shop backend (2.4 — items 7a-7e).

- Feed (7a): products synced lazily from the AffiliateProvider catalog,
  ordered profile-aware; carries the measurements gate flag.
- AI Style Advisor (7b): AIProvider.chat returning structured suggestions,
  persisted per conversation. Free limit 10 questions/week.
- Buy/Don't-Buy (7c): analyze_image (through the AI cache) -> fit/value/gap
  verdict, persisted. Free limit 5 checks/week.
- Gap Analysis (7d): deterministic heuristic over wardrobe category coverage
  (no AI call — cheap, testable; outfit-unlock counts are combinatorial).
- Wishlist (7e): saved products; price at save time vs provider live price
  marks drops.
"""
from __future__ import annotations

import json
import re
from typing import Optional
from uuid import UUID

import structlog
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.models import (
    AdvisorConversation,
    BuyDontBuyResult,
    Product,
    User,
    UserMeasurements,
    WardrobeItem,
    WishlistItem,
)
from app.services import usage_service
from app.services.providers.affiliate.base import AffiliateProvider
from app.services.providers.ai.base import AIProvider

_log = structlog.get_logger("shop")

ADVISOR_MAX_QUESTION_LEN = 500


class ShopError(Exception):
    """Domain-level shop failure. Routes translate to 4xx."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code


# ---------------------------------------------------------------------------
# 7a — products + feed
# ---------------------------------------------------------------------------


def sync_products(db: Session, *, affiliate: AffiliateProvider) -> int:
    """Upsert the provider catalog into `products` (idempotent, by external_id)."""
    count = 0
    for p in affiliate.catalog():
        row = db.scalar(select(Product).where(Product.external_id == p.external_id))
        if row is None:
            row = Product(external_id=p.external_id)
            db.add(row)
            count += 1
        row.name = p.name
        row.brand = p.brand
        row.category = p.category
        row.price_cents = p.price_cents
        row.currency = p.currency
        row.image_url = p.image_url
        row.product_url = p.product_url
        row.retailer = p.retailer
        row.is_active = True
    db.commit()
    return count


def _measurements_complete(db: Session, *, user_id: UUID) -> bool:
    return bool(
        db.scalar(
            select(UserMeasurements.is_complete).where(
                UserMeasurements.user_id == user_id
            )
        )
    )


def get_feed(
    db: Session, *, user: User, affiliate: AffiliateProvider
) -> tuple[list[Product], bool]:
    """Products (lazily synced) + whether fit features are unlocked.
    Ordering is a light profile-aware touch: the user's wardrobe's thinnest
    categories surface first (the feed doubles as gap-filling)."""
    if db.scalar(select(Product).limit(1)) is None:
        sync_products(db, affiliate=affiliate)
    products = list(
        db.scalars(select(Product).where(Product.is_active.is_(True))).all()
    )
    counts: dict[str, int] = {}
    for item in db.scalars(
        select(WardrobeItem).where(WardrobeItem.user_id == user.id)
    ).all():
        counts[item.category] = counts.get(item.category, 0) + 1
    products.sort(key=lambda p: (counts.get(p.category, 0), p.category, p.name))
    return products, _measurements_complete(db, user_id=user.id)


# ---------------------------------------------------------------------------
# 7b — AI style advisor
# ---------------------------------------------------------------------------

_ADVISOR_SYSTEM = (
    "You are Zoura's personal stylist. Answer the user's styling question in "
    "2-4 sentences, then suggest up to 3 product categories to look for. "
    'Reply with ONLY JSON: {"reply": "...", "suggestions": '
    '[{"name": "...", "category": "tops|bottoms|shoes|outerwear|dresses|accessories", '
    '"reason": "..."}]}'
)


def _extract_json(text: str) -> Optional[dict]:
    m = re.search(r"\{.*\}", text, re.S)
    if not m:
        return None
    try:
        parsed = json.loads(m.group(0))
    except json.JSONDecodeError:
        return None
    return parsed if isinstance(parsed, dict) else None


def _match_products(db: Session, suggestions: list[dict]) -> list[dict]:
    """Best-effort: attach a concrete catalog product to each suggestion."""
    enriched = []
    for sug in suggestions[:3]:
        category = str(sug.get("category", "")).lower()
        product = db.scalar(
            select(Product)
            .where(Product.category == category, Product.is_active.is_(True))
            .order_by(Product.price_cents)
        )
        enriched.append(
            {
                "name": str(sug.get("name", ""))[:200],
                "category": category,
                "reason": str(sug.get("reason", ""))[:500],
                "product_id": str(product.id) if product else None,
            }
        )
    return enriched


async def advisor_ask(
    db: Session,
    *,
    user: User,
    ai: AIProvider,
    affiliate: AffiliateProvider,
    question: str,
    conversation_id: Optional[UUID] = None,
) -> AdvisorConversation:
    """One advisor turn. Counts 1 against the weekly advisor limit (429 via
    UsageError before any AI spend)."""
    usage_service.check_and_increment(db, user=user, resource="advisor")

    if db.scalar(select(Product).limit(1)) is None:
        sync_products(db, affiliate=affiliate)

    if conversation_id is not None:
        convo = db.get(AdvisorConversation, conversation_id)
        if convo is None or convo.user_id != user.id:
            raise ShopError("not_found", "Conversation not found")
    else:
        convo = AdvisorConversation(
            user_id=user.id, title=question[:200], messages=[]
        )
        db.add(convo)

    raw = await ai.chat(
        [{"role": "user", "content": question}], system=_ADVISOR_SYSTEM
    )
    parsed = _extract_json(raw) or {}
    reply = str(parsed.get("reply") or raw)[:2000]
    suggestions = parsed.get("suggestions")
    enriched = _match_products(db, suggestions) if isinstance(suggestions, list) else []

    convo.messages = [
        *convo.messages,
        {"role": "user", "content": question},
        {"role": "assistant", "content": reply, "suggestions": enriched},
    ]
    db.commit()
    db.refresh(convo)
    _log.info(
        "shop.advisor.answered",
        user_id=str(user.id),
        conversation_id=str(convo.id),
        suggestions=len(enriched),
    )
    return convo


def advisor_history(db: Session, *, user: User) -> list[AdvisorConversation]:
    return list(
        db.scalars(
            select(AdvisorConversation)
            .where(AdvisorConversation.user_id == user.id)
            .order_by(AdvisorConversation.updated_at.desc())
            .limit(50)
        ).all()
    )


# ---------------------------------------------------------------------------
# 7c — buy / don't buy
# ---------------------------------------------------------------------------

_BDB_PROMPT = (
    "You are Zoura's purchase advisor. The user is considering buying the "
    "garment in this image. Assess it against a typical versatile wardrobe: "
    "fit risk, value, and whether it fills a gap. Reply with ONLY JSON: "
    '{"verdict": "buy"|"dont_buy", "score": 0-100, '
    '"fit_reason": "...", "value_reason": "...", "gap_reason": "..."}'
)


async def buy_check(
    db: Session,
    *,
    user: User,
    ai: AIProvider,
    image_bytes: bytes,
    media_type: str,
    product_name: Optional[str] = None,
) -> BuyDontBuyResult:
    """Analyze a product photo -> verdict. Counts 1 against the weekly
    buy/don't-buy limit (5 free) before any AI spend; the image call itself
    goes through the content-addressed AI cache."""
    usage_service.check_and_increment(db, user=user, resource="buy_dont_buy")

    raw = await ai.analyze_image(image_bytes, _BDB_PROMPT, media_type=media_type)
    parsed = _extract_json(raw) or {}
    verdict = parsed.get("verdict")
    if verdict not in ("buy", "dont_buy"):
        # Parse failure is recoverable: a neutral leaning-buy verdict beats a 500.
        verdict = "buy"
        parsed.setdefault("fit_reason", "We couldn't fully assess this item.")
    try:
        score = max(0, min(100, int(parsed.get("score", 50))))
    except (TypeError, ValueError):
        score = 50

    row = BuyDontBuyResult(
        user_id=user.id,
        product_name=(product_name or None),
        verdict=verdict,
        score=score,
        reasons={
            "fit": str(parsed.get("fit_reason", ""))[:500],
            "value": str(parsed.get("value_reason", ""))[:500],
            "gap": str(parsed.get("gap_reason", ""))[:500],
        },
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    _log.info(
        "shop.buy_check",
        user_id=str(user.id),
        verdict=verdict,
        score=score,
    )
    return row


def buy_check_history(db: Session, *, user: User) -> list[BuyDontBuyResult]:
    return list(
        db.scalars(
            select(BuyDontBuyResult)
            .where(BuyDontBuyResult.user_id == user.id)
            .order_by(BuyDontBuyResult.created_at.desc())
            .limit(20)
        ).all()
    )


# ---------------------------------------------------------------------------
# 7d — gap analysis (deterministic heuristic; no AI spend)
# ---------------------------------------------------------------------------

# What a "complete" versatile wardrobe roughly needs per category, and which
# categories each one combines with (drives the outfit-unlock estimate).
_GAP_TARGETS: dict[str, int] = {
    "tops": 5,
    "bottoms": 4,
    "shoes": 3,
    "outerwear": 2,
}
_COMBINES_WITH: dict[str, tuple[str, ...]] = {
    "tops": ("bottoms", "shoes"),
    "bottoms": ("tops", "shoes"),
    "shoes": ("tops", "bottoms"),
    "outerwear": ("tops", "bottoms"),
}


def gap_analysis(db: Session, *, user: User) -> list[dict]:
    """Missing-category recommendations, biggest gap first. Each gap carries an
    outfit-unlock estimate: one new item combines with what the user already
    owns in its complementary categories."""
    counts: dict[str, int] = {}
    for item in db.scalars(
        select(WardrobeItem).where(WardrobeItem.user_id == user.id)
    ).all():
        counts[item.category] = counts.get(item.category, 0) + 1

    gaps: list[dict] = []
    for category, target in _GAP_TARGETS.items():
        have = counts.get(category, 0)
        if have >= target:
            continue
        unlocked = 1
        for other in _COMBINES_WITH[category]:
            unlocked *= max(counts.get(other, 0), 1)
        gaps.append(
            {
                "category": category,
                "have": have,
                "recommended": target,
                "reason": (
                    f"You have {have} {category} — a versatile wardrobe works "
                    f"best with at least {target}."
                ),
                "outfits_unlocked": unlocked,
            }
        )
    gaps.sort(key=lambda g: (g["have"] - g["recommended"], -g["outfits_unlocked"]))
    return gaps


# ---------------------------------------------------------------------------
# 7e — wishlist
# ---------------------------------------------------------------------------


def wishlist_add(db: Session, *, user: User, product_id: UUID) -> WishlistItem:
    product = db.get(Product, product_id)
    if product is None or not product.is_active:
        raise ShopError("not_found", "Product not found")
    row = db.scalar(
        select(WishlistItem).where(
            WishlistItem.user_id == user.id,
            WishlistItem.product_id == product_id,
        )
    )
    if row is not None:
        return row  # idempotent
    row = WishlistItem(
        user_id=user.id,
        product_id=product_id,
        added_price_cents=product.price_cents,
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def wishlist_remove(db: Session, *, user: User, product_id: UUID) -> bool:
    row = db.scalar(
        select(WishlistItem).where(
            WishlistItem.user_id == user.id,
            WishlistItem.product_id == product_id,
        )
    )
    if row is None:
        return False
    db.delete(row)
    db.commit()
    return True


def wishlist(
    db: Session, *, user: User, affiliate: AffiliateProvider
) -> list[tuple[WishlistItem, Product, Optional[int]]]:
    """(saved item, product, current price). A current price below the saved
    price is a drop — the client renders the delta."""
    rows = list(
        db.scalars(
            select(WishlistItem)
            .where(WishlistItem.user_id == user.id)
            .order_by(WishlistItem.created_at.desc())
        ).all()
    )
    out = []
    for row in rows:
        product = db.get(Product, row.product_id)
        if product is None:
            continue
        current = affiliate.current_price_cents(product.external_id)
        out.append((row, product, current))
    return out
