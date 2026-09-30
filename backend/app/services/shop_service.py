"""Shop backend (2.4 — items 7a-7e).

- Feed (7a): the synced catalog (the catalog worker owns syncing — see
  catalog_service) in the user's genders, ordered profile-aware; carries the
  measurements gate flag.
- AI Style Advisor (7b): AIProvider.chat with the conversation so far and the
  user's profile + wardrobe, returning up to 3 looks whose pieces are matched
  to real catalog products; persisted per conversation. Free limit 25
  questions/week.
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
from sqlalchemy import or_, select
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
from app.services import catalog_service, measurements_service, usage_service
from app.services import fit_profile as fit_profile_mod
from app.services.outfit_service import _build_wearer_block
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


def _measurements_complete(db: Session, *, user_id: UUID) -> bool:
    return bool(
        db.scalar(
            select(UserMeasurements.is_complete).where(
                UserMeasurements.user_id == user_id
            )
        )
    )


def get_feed(db: Session, *, user: User) -> tuple[list[Product], bool]:
    """Active products in the user's genders (untagged products from an
    unmapped advertiser have no gender yet and are included) + whether fit
    features are unlocked. Ordering is a light profile-aware touch: the user's
    wardrobe's thinnest categories surface first (the feed doubles as
    gap-filling)."""
    products = list(
        db.scalars(
            select(Product).where(
                Product.is_active.is_(True),
                or_(
                    Product.gender.in_(catalog_service.genders_for(user)),
                    Product.gender.is_(None),
                ),
            )
        ).all()
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

_ADVISOR_PERSONA = (
    "You are Zoura's personal stylist. Answer the user's styling question warmly "
    "in 2-4 sentences, in the second person. When the question calls for buying "
    "something, suggest up to 3 distinct looks; each look has 2-4 pieces to buy "
    "and one short note tying it to the user — ideally naming a piece they "
    "already own that it pairs with. Never suggest buying something the user "
    "already owns. When no shopping is needed (e.g. how to style what they "
    "have), return no looks. Only describe pieces the shop actually carries: "
    "use the words from the shop's vocabulary below in each piece's keywords."
)

_ADVISOR_FORMAT = (
    "Respond with ONLY a JSON object — no prose, no markdown, no code fences:\n"
    '{"reply": "...", "looks": [{"name": "Classic Guest", "note": "...", '
    '"pieces": [{"category": "tops|bottoms|dresses|outerwear|shoes|accessories", '
    '"color": "burgundy", "formality": "casual|smart_casual|formal", '
    '"keywords": ["satin", "midi", "dress"]}]}]}'
)

# Wardrobe lines sent to the AI; enough to know what they own, bounded cost.
_ADVISOR_MAX_WARDROBE_LINES = 60
# Prior messages replayed on a follow-up (5 turns).
_ADVISOR_MAX_HISTORY = 10
_ADVISOR_MAX_LOOKS = 3
_ADVISOR_MAX_PIECES = 4

_CATEGORY_ALIASES = {
    **{role: cat for cat, role in catalog_service.ROLE_BY_CATEGORY.items()},
    "top": "tops",
    "bottom": "bottoms",
    "dress": "dresses",
    "shoe": "shoes",
    "footwear": "shoes",
    "accessory": "accessories",
    "jacket": "outerwear",
    "coat": "outerwear",
}

_WORD_RE = re.compile(r"[a-z]+")

# Words in product names that say nothing about the piece itself.
_VOCAB_STOPWORDS = frozenset(
    "women womens men mens with and the for in of size plus petite tall "
    "maternity pack set new".split()
)
_VOCAB_PER_CATEGORY = 30


def _extract_json(text: str) -> Optional[dict]:
    m = re.search(r"\{.*\}", text, re.S)
    if not m:
        return None
    try:
        parsed = json.loads(m.group(0))
    except json.JSONDecodeError:
        return None
    return parsed if isinstance(parsed, dict) else None


def _shop_vocabulary(products: list[Product]) -> str:
    """Most common descriptive words per category across the products this
    user can be shown, so the AI describes pieces the catalog can match
    (no "saree" when the shop has none)."""
    counts: dict[str, dict[str, int]] = {}
    for p in products:
        brand = set(_WORD_RE.findall(p.brand.lower()))
        words = set(_WORD_RE.findall(catalog_service.display_name(p).lower()))
        bucket = counts.setdefault(p.category, {})
        for w in words - brand - _VOCAB_STOPWORDS:
            if len(w) > 2:
                bucket[w] = bucket.get(w, 0) + 1
    lines = []
    for cat in sorted(counts):
        top = sorted(counts[cat], key=lambda w: (-counts[cat][w], w))[:_VOCAB_PER_CATEGORY]
        lines.append(f"- {cat}: {', '.join(top)}")
    return "\n".join(lines) if lines else "- (the shop is empty right now)"


def _catalog_for(db: Session, *, user: User) -> list[Product]:
    return list(
        db.scalars(
            select(Product).where(
                Product.is_active.is_(True),
                or_(
                    Product.gender.in_(catalog_service.genders_for(user)),
                    Product.gender.is_(None),
                ),
            )
        ).all()
    )


def _advisor_system(db: Session, *, user: User, catalog: list[Product]) -> str:
    """Persona + format + who the user is and what they own. Stable across a
    conversation's turns, so it's sent as a cacheable system prefix."""
    about = []
    shopping_for = {"womens": "womenswear", "mens": "menswear"}.get(
        user.shopping_style or "", "womenswear and menswear"
    )
    about.append(f"Shops for: {shopping_for}.")
    if user.age_range:
        about.append(f"Age range: {user.age_range}.")
    if user.style_goals:
        about.append(f"Style goals: {', '.join(user.style_goals)}.")
    for key, value in sorted((user.style_profile or {}).items()):
        if key == "occupation" or value in (None, "", []):
            continue
        shown = ", ".join(map(str, value)) if isinstance(value, list) else value
        about.append(f"{key.replace('_', ' ')}: {shown}.")
    wearer = _build_wearer_block(user.profile.body_analysis if user.profile else None)
    fit = fit_profile_mod.to_prompt_block(
        measurements_service.fit_profile_for_user(db, user=user)
    )

    owned = db.scalars(
        select(WardrobeItem)
        .where(
            WardrobeItem.user_id == user.id,
            WardrobeItem.is_starter_wardrobe.is_(False),
        )
        .order_by(WardrobeItem.created_at.desc())
        .limit(_ADVISOR_MAX_WARDROBE_LINES)
    ).all()
    if owned:
        lines = "\n".join(
            f"- {i.name} [{' | '.join(d for d in (i.category, i.color_name, i.formality) if d)}]"
            for i in owned
        )
        wardrobe = f"The user's own wardrobe ({len(owned)} items):\n{lines}"
    else:
        wardrobe = "The user hasn't added their own clothes yet."

    return (
        f"{_ADVISOR_PERSONA}\n\n{_ADVISOR_FORMAT}\n\n"
        f"About the user:\n{chr(10).join(about)}\n{wearer}{fit}\n{wardrobe}\n\n"
        f"The shop's vocabulary (what it carries, by category):\n"
        f"{_shop_vocabulary(catalog)}"
    )


def _history_for_ai(messages: list[dict]) -> list[dict[str, str]]:
    """Prior turns as plain chat messages. Assistant turns carry a one-line
    recap of the looks (names, pieces, prices) so follow-ups like "anything
    cheaper?" have something to refer to."""
    out: list[dict[str, str]] = []
    for m in messages[-_ADVISOR_MAX_HISTORY:]:
        content = m.get("content", "")
        if m.get("role") == "assistant" and m.get("looks"):
            recap = "; ".join(
                f"{look['name']} (~${look['total_price_cents'] / 100:.0f}: "
                + ", ".join(
                    f"{it['name']} ${it['price_cents'] / 100:.0f}" for it in look["items"]
                )
                + ")"
                for look in m["looks"]
            )
            content = f"{content}\n[Looks shown: {recap}]"
        out.append({"role": m.get("role", "user"), "content": content})
    return out


def _piece_score(
    product: Product, *, color: str, formality: str, keywords: list[str]
) -> Optional[int]:
    """Relevance of a product to a described piece, or None when it doesn't
    qualify: it needs a keyword hit, or a colour hit plus matching formality,
    and a casual product never fills a formal piece. A piece with no
    qualifying product is left out rather than filled with something random."""
    if formality == "formal" and product.formality == "casual":
        return None
    words = set(_WORD_RE.findall(product.name.lower()))
    hits = sum(1 for k in keywords if k in words)
    color_hit = bool(color) and (
        color in (product.color_name or "").lower() or color in words
    )
    formality_hit = bool(formality) and product.formality == formality
    if not hits and not (color_hit and formality_hit):
        return None
    return 2 * hits + (3 if color_hit else 0) + (1 if formality_hit else 0)


def _match_looks(raw_looks: list, *, catalog: list[Product]) -> list[dict]:
    """Turn the AI's described looks into real products: per piece, the
    best-scoring qualifying product in that category (see `_piece_score`;
    cheaper wins ties), never repeating a product in one answer. Looks that
    end up with no products are dropped."""
    by_category: dict[str, list[Product]] = {}
    for p in catalog:
        by_category.setdefault(p.category, []).append(p)
    used: set[UUID] = set()
    looks: list[dict] = []
    for raw in raw_looks[:_ADVISOR_MAX_LOOKS]:
        if not isinstance(raw, dict):
            continue
        items: list[dict] = []
        for piece in (raw.get("pieces") or [])[:_ADVISOR_MAX_PIECES]:
            if not isinstance(piece, dict):
                continue
            cat = str(piece.get("category", "")).strip().lower()
            cat = cat if cat in catalog_service.ROLE_BY_CATEGORY else _CATEGORY_ALIASES.get(cat)
            if cat is None:
                continue
            color = str(piece.get("color") or "").strip().lower()
            formality = str(piece.get("formality") or "").strip().lower()
            keywords = [
                w
                for k in (piece.get("keywords") or [])
                if isinstance(k, str)
                for w in _WORD_RE.findall(k.lower())
                if len(w) > 2
            ]
            scored = [
                (score, -p.price_cents, p)
                for p in by_category.get(cat, [])
                if p.id not in used
                and (score := _piece_score(
                    p, color=color, formality=formality, keywords=keywords
                )) is not None
            ]
            if not scored:
                continue
            best = max(scored, key=lambda t: (t[0], t[1]))[2]
            used.add(best.id)
            items.append(
                {
                    "product_id": str(best.id),
                    "name": catalog_service.display_name(best),
                    "brand": best.brand,
                    "category": best.category,
                    "price_cents": best.price_cents,
                    "currency": best.currency,
                    "image_url": best.image_url,
                    "product_url": best.product_url,
                    "retailer": best.retailer,
                }
            )
        if items:
            looks.append(
                {
                    "name": str(raw.get("name") or f"Look {len(looks) + 1}")[:80],
                    "note": str(raw.get("note") or "")[:300],
                    "items": items,
                    "total_price_cents": sum(i["price_cents"] for i in items),
                }
            )
    return looks


async def advisor_ask(
    db: Session,
    *,
    user: User,
    ai: AIProvider,
    question: str,
    conversation_id: Optional[UUID] = None,
) -> AdvisorConversation:
    """One advisor turn. Counts 1 against the weekly advisor limit (429 via
    UsageError before any AI spend)."""
    if conversation_id is not None:
        convo = get_conversation(db, user=user, conversation_id=conversation_id)
    else:
        convo = AdvisorConversation(user_id=user.id, title=question[:200], messages=[])
    usage_service.check_and_increment(db, user=user, resource="advisor")
    if conversation_id is None:
        db.add(convo)

    catalog = _catalog_for(db, user=user)
    raw = await ai.chat(
        [*_history_for_ai(convo.messages), {"role": "user", "content": question}],
        system=_advisor_system(db, user=user, catalog=catalog),
        max_tokens=4096,  # headroom for adaptive thinking (counts toward max_tokens)
        cache_system=True,
    )
    parsed = _extract_json(raw) or {}
    reply = str(parsed.get("reply") or raw)[:2000]
    raw_looks = parsed.get("looks")
    looks = _match_looks(raw_looks, catalog=catalog) if isinstance(raw_looks, list) else []

    convo.messages = [
        *convo.messages,
        {"role": "user", "content": question},
        {"role": "assistant", "content": reply, "looks": looks},
    ]
    db.commit()
    db.refresh(convo)
    _log.info(
        "shop.advisor.answered",
        user_id=str(user.id),
        conversation_id=str(convo.id),
        looks=len(looks),
        items=sum(len(look["items"]) for look in looks),
    )
    return convo


def get_conversation(
    db: Session, *, user: User, conversation_id: UUID
) -> AdvisorConversation:
    convo = db.get(AdvisorConversation, conversation_id)
    if convo is None or convo.user_id != user.id:
        raise ShopError("not_found", "Conversation not found")
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
            # §3.1 pagination cap — each row also costs an affiliate price
            # lookup below, so an unbounded wishlist is a fan-out risk too.
            .limit(200)
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
