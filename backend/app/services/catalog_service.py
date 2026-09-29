"""Affiliate catalog (11e) — feed → `products` sync and one-at-a-time AI tagging.

Driven by the catalog worker (app/workers/catalog_worker.py), never by a
request: shop/outfit/starter reads only ever see what's already in the table.

- `sync_catalog` diffs the provider catalog against `products` by
  `external_id`: new rows are inserted untagged, changed rows updated, and rows
  the feed dropped are deactivated (never deleted — wardrobe items and
  wishlists point at them). A text change (name/category/retailer) clears the
  tags so the product is re-tagged; a price change doesn't. A Postgres
  advisory lock keeps concurrent workers from syncing at once.
- `tag_next` tags ONE untagged product per call (role, warmth, formality,
  occasions, colour, gender) with a cheap model. Products are picked
  round-robin across (retailer, category) so every outfit role gets usable
  products early instead of one category at a time. Only tagged products are
  offered to outfit generation and the starter capsule.
"""
from __future__ import annotations

import hashlib
import json
import re
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Optional

import structlog
from sqlalchemy import func, select, update
from sqlalchemy.orm import Session

from app.db.models import Product, User
from app.services.providers.affiliate.base import AffiliateProduct, AffiliateProvider
from app.services.providers.ai.base import AIProvider, AIProviderError

_log = structlog.get_logger("catalog")

# Arbitrary app-wide key for pg_try_advisory_xact_lock around a sync.
_SYNC_LOCK_KEY = 0x5A0C_CA7A

GENDERS = ("women", "men", "unisex")
ROLES = ("top", "bottom", "dress", "outerwear", "shoes", "accessory")
WARMTHS = ("light", "mid", "heavy")
FORMALITIES = ("casual", "smart_casual", "formal")
OCCASIONS = ("work", "casual", "date_night")

# Shop category -> outfit role, and back (wardrobe categories are the shop's).
ROLE_BY_CATEGORY = {
    "tops": "top",
    "bottoms": "bottom",
    "dresses": "dress",
    "outerwear": "outerwear",
    "shoes": "shoes",
    "accessories": "accessory",
}
CATEGORY_BY_ROLE = {v: k for k, v in ROLE_BY_CATEGORY.items()}

_JSON_OBJECT_RE = re.compile(r"\{.*\}", re.DOTALL)


@dataclass(frozen=True)
class SyncResult:
    added: int
    updated: int
    deactivated: int


def _tag_hash(p: AffiliateProduct) -> str:
    return hashlib.sha256(f"{p.name}|{p.category}|{p.retailer}".encode()).hexdigest()


def sync_catalog(
    db: Session,
    *,
    affiliate: AffiliateProvider,
    advertiser_genders: dict[str, str] | None = None,
) -> Optional[SyncResult]:
    """Diff the provider catalog into `products`. None when another worker
    holds the sync lock. Raises the provider's error when the catalog can't be
    loaded — the table is left untouched."""
    catalog = affiliate.catalog()  # before any writes
    genders = advertiser_genders or {}
    if not db.scalar(select(func.pg_try_advisory_xact_lock(_SYNC_LOCK_KEY))):
        db.rollback()
        return None

    existing = {row.external_id: row for row in db.scalars(select(Product)).all()}
    added = updated = 0
    for p in catalog:
        row = existing.get(p.external_id)
        if row is None:
            row = Product(external_id=p.external_id)
            db.add(row)
            added += 1
        elif (
            not row.is_active
            or (row.name, row.brand, row.category, row.price_cents, row.currency)
            != (p.name, p.brand, p.category, p.price_cents, p.currency)
            or (row.image_url, row.product_url, row.retailer)
            != (p.image_url, p.product_url, p.retailer)
        ):
            updated += 1
        row.name = p.name
        row.brand = p.brand
        row.category = p.category
        row.price_cents = p.price_cents
        row.currency = p.currency
        row.image_url = p.image_url
        row.product_url = p.product_url
        row.retailer = p.retailer
        row.advertiser_id = p.advertiser_id
        row.is_active = True
        mapped = genders.get(p.advertiser_id or "")
        if mapped in GENDERS:
            row.gender = mapped
        digest = _tag_hash(p)
        if row.tag_hash != digest:
            row.tag_hash = digest
            row.tagged_at = None  # re-tag: what the tags describe changed

    live = {p.external_id for p in catalog}
    stale = [
        ext for ext, row in existing.items() if row.is_active and ext not in live
    ]
    if stale:
        db.execute(
            update(Product)
            .where(Product.external_id.in_(stale))
            .values(is_active=False)
        )
    db.commit()
    result = SyncResult(added=added, updated=updated, deactivated=len(stale))
    _log.info("catalog.synced", total=len(catalog), **result.__dict__)
    return result


# ---------------------------------------------------------------------------
# Tagging
# ---------------------------------------------------------------------------

_TAG_SYSTEM = (
    "You classify one fashion product for an outfit-building app. Reply with "
    "ONLY a JSON object — no prose, no markdown:\n"
    '{"gender": "women|men|unisex", '
    '"role": "top|bottom|dress|outerwear|shoes|accessory", '
    '"warmth": "light|mid|heavy", '
    '"formality": "casual|smart_casual|formal", '
    '"occasions": ["work", "casual", "date_night"], '
    '"color_name": "one or two words"}\n'
    "role: dress also covers jumpsuits and playsuits. warmth: light = summer "
    "wear (linen, shorts, vests, sandals), heavy = winter wear (coats, puffers, "
    "knits, boots), else mid. occasions: every one of work / casual / "
    "date_night the piece genuinely suits — at least one."
)


def _pick_untagged(db: Session) -> Optional[Product]:
    """Next product to tag: from the (retailer, category) group with the
    fewest tagged products, so each role becomes usable early. Rows another
    worker is tagging are skipped (FOR UPDATE SKIP LOCKED)."""
    tagged_counts = dict(
        (tuple(k), n)
        for *k, n in db.execute(
            select(Product.retailer, Product.category, func.count())
            .where(Product.is_active.is_(True), Product.tagged_at.is_not(None))
            .group_by(Product.retailer, Product.category)
        ).all()
    )
    untagged = db.execute(
        select(Product.id, Product.retailer, Product.category)
        .where(Product.is_active.is_(True), Product.tagged_at.is_(None))
        .order_by(Product.created_at, Product.external_id)
    ).all()
    untagged.sort(key=lambda r: tagged_counts.get((r.retailer, r.category), 0))
    for candidate in untagged:
        row = db.scalar(
            select(Product)
            .where(Product.id == candidate.id, Product.tagged_at.is_(None))
            .with_for_update(skip_locked=True)
        )
        if row is not None:
            return row
    return None


def _parse_tags(text: str) -> dict:
    match = _JSON_OBJECT_RE.search(text or "")
    if match is None:
        raise ValueError("no JSON object in tag reply")
    data = json.loads(match.group(0))
    if not isinstance(data, dict):
        raise ValueError("tag reply is not an object")
    return data


def _apply_tags(row: Product, data: dict) -> None:
    """Validated tags onto the row; anything off-vocabulary falls back to what
    the feed category and a neutral default say, so a sloppy reply still
    yields a usable product."""
    fallback_role = ROLE_BY_CATEGORY.get(row.category, "accessory")
    role = data.get("role")
    # The feed category is authoritative for shoes/accessories vs apparel; the
    # AI only refines within apparel (a "top" that is really a playsuit).
    non_apparel = ("shoes", "accessory")
    if role not in ROLES or (role in non_apparel) != (fallback_role in non_apparel):
        role = fallback_role
    elif fallback_role in non_apparel:
        role = fallback_role
    row.role = role
    row.warmth = data.get("warmth") if data.get("warmth") in WARMTHS else "mid"
    row.formality = (
        data.get("formality") if data.get("formality") in FORMALITIES else "casual"
    )
    occasions = [o for o in (data.get("occasions") or []) if o in OCCASIONS]
    row.occasions = sorted(set(occasions)) or ["casual"]
    color = data.get("color_name")
    row.color_name = color.strip()[:50] if isinstance(color, str) and color.strip() else None
    if row.gender is None:  # advertiser mapping wins when present
        row.gender = data.get("gender") if data.get("gender") in GENDERS else "unisex"
    row.tagged_at = datetime.now(timezone.utc)


async def tag_next(db: Session, *, ai: AIProvider, model: Optional[str] = None) -> Optional[Product]:
    """Tag one untagged product. Returns it, or None when nothing is waiting.
    An AI outage leaves it untagged (raises AIProviderError for the caller to
    back off); an unparseable reply tags it from the feed category instead of
    retrying forever."""
    row = _pick_untagged(db)
    if row is None:
        db.rollback()
        return None
    prompt = (
        f"Product: {row.name}\nRetailer: {row.retailer}\nShop category: {row.category}"
    )
    try:
        text = await ai.chat(
            [{"role": "user", "content": prompt}],
            model=model,
            system=_TAG_SYSTEM,
            max_tokens=200,
            cache_system=True,
        )
    except AIProviderError:
        db.rollback()
        raise
    try:
        data = _parse_tags(text)
    except (ValueError, json.JSONDecodeError) as exc:
        _log.warning("catalog.tag_unparseable", external_id=row.external_id, error=str(exc))
        data = {}
    _apply_tags(row, data)
    db.commit()
    _log.info(
        "catalog.tagged",
        external_id=row.external_id,
        role=row.role,
        gender=row.gender,
        warmth=row.warmth,
        parsed=bool(data),
    )
    return row


# ---------------------------------------------------------------------------
# Reads for outfits / starter capsule / shop
# ---------------------------------------------------------------------------


def display_name(product: Product) -> str:
    """Style name without the feed's " | colour | size" suffix (boohooMAN)."""
    return product.name.split("|", 1)[0].strip()[:200] or product.name[:200]


def genders_for(user: User) -> tuple[str, ...]:
    """Product genders a user is shown, from onboarding's shopping_style."""
    style = user.shopping_style
    if style == "womens":
        return ("women", "unisex")
    if style == "mens":
        return ("men", "unisex")
    return GENDERS


def tagged_products(db: Session, *, user: User) -> list[Product]:
    """Active, tagged products in the user's genders."""
    return list(
        db.scalars(
            select(Product)
            .where(
                Product.is_active.is_(True),
                Product.tagged_at.is_not(None),
                Product.gender.in_(genders_for(user)),
            )
            .order_by(Product.external_id)
        ).all()
    )
