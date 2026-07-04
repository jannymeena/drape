"""Shop routes (2.4 — items 7a-7e)."""
from __future__ import annotations

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from sqlalchemy.orm import Session

from app.api.dependencies.auth import get_current_user
from app.api.dependencies.billing import _is_pro
from app.api.dependencies.providers import get_affiliate_provider, get_ai_provider
from app.db.models import AdvisorConversation, BuyDontBuyResult, User
from app.db.session import get_db
from app.schemas.shop import (
    AdvisorAskRequest,
    AdvisorConversationResponse,
    AdvisorHistoryResponse,
    AdvisorMessage,
    BuyDontBuyHistoryResponse,
    BuyDontBuyResponse,
    GapAnalysisResponse,
    GapItem,
    ProductResponse,
    ShopFeedResponse,
    WishlistAddRequest,
    WishlistEntry,
    WishlistResponse,
)
from app.services import shop_service
from app.services.billing_service import PLAN_SUMMARY
from app.services.providers.affiliate.base import AffiliateProvider
from app.services.providers.ai.base import AIProvider
from app.services.shop_service import ShopError
from app.services.usage_service import UsageError

router = APIRouter(prefix="/shop", tags=["shop"])

# Same validation limits as the wardrobe scanner.
_ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp"}
_MAX_IMAGE_BYTES = 10 * 1024 * 1024


def _translate_usage(err: UsageError) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_429_TOO_MANY_REQUESTS,
        detail={
            "error": err.code,
            "resource": err.resource,
            "used": err.used,
            "limit": err.limit,
            "resets_at": err.resets_at.isoformat() if err.resets_at else None,
            "message": str(err),
            "plans": PLAN_SUMMARY,
        },
    )


def _to_conversation(convo: AdvisorConversation) -> AdvisorConversationResponse:
    return AdvisorConversationResponse(
        id=convo.id,
        title=convo.title,
        messages=[AdvisorMessage(**m) for m in convo.messages],
        updated_at=convo.updated_at,
    )


def _to_bdb(row: BuyDontBuyResult) -> BuyDontBuyResponse:
    return BuyDontBuyResponse(
        id=row.id,
        product_name=row.product_name,
        verdict=row.verdict,
        score=row.score,
        fit_reason=row.reasons.get("fit", ""),
        value_reason=row.reasons.get("value", ""),
        gap_reason=row.reasons.get("gap", ""),
        created_at=row.created_at,
    )


@router.get("/feed", response_model=ShopFeedResponse)
def feed(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    affiliate: AffiliateProvider = Depends(get_affiliate_provider),
) -> ShopFeedResponse:
    products, complete = shop_service.get_feed(db, user=user, affiliate=affiliate)
    return ShopFeedResponse(
        products=[ProductResponse.model_validate(p) for p in products],
        measurements_complete=complete,
    )


@router.post("/advisor/ask", response_model=AdvisorConversationResponse)
async def advisor_ask(
    payload: AdvisorAskRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    ai: AIProvider = Depends(get_ai_provider),
    affiliate: AffiliateProvider = Depends(get_affiliate_provider),
) -> AdvisorConversationResponse:
    try:
        convo = await shop_service.advisor_ask(
            db,
            user=user,
            ai=ai,
            affiliate=affiliate,
            question=payload.question,
            conversation_id=payload.conversation_id,
        )
    except UsageError as e:
        raise _translate_usage(e)
    except ShopError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    return _to_conversation(convo)


@router.get("/advisor/history", response_model=AdvisorHistoryResponse)
def advisor_history(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> AdvisorHistoryResponse:
    convos = shop_service.advisor_history(db, user=user)
    return AdvisorHistoryResponse(conversations=[_to_conversation(c) for c in convos])


@router.post("/buy-check", response_model=BuyDontBuyResponse)
async def buy_check(
    file: UploadFile = File(...),
    product_name: str | None = Form(default=None),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    ai: AIProvider = Depends(get_ai_provider),
) -> BuyDontBuyResponse:
    if file.content_type not in _ALLOWED_IMAGE_TYPES:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail=f"Unsupported content type {file.content_type!r}",
        )
    content = await file.read()
    if not content:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Empty file upload"
        )
    if len(content) > _MAX_IMAGE_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"File exceeds {_MAX_IMAGE_BYTES} bytes",
        )
    try:
        row = await shop_service.buy_check(
            db,
            user=user,
            ai=ai,
            image_bytes=content,
            media_type=file.content_type,
            product_name=product_name,
        )
    except UsageError as e:
        raise _translate_usage(e)
    return _to_bdb(row)


@router.get("/buy-check/history", response_model=BuyDontBuyHistoryResponse)
def buy_check_history(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> BuyDontBuyHistoryResponse:
    rows = shop_service.buy_check_history(db, user=user)
    return BuyDontBuyHistoryResponse(checks=[_to_bdb(r) for r in rows])


@router.get("/gap-analysis", response_model=GapAnalysisResponse)
def gap_analysis(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> GapAnalysisResponse:
    """Free tier sees the top gap as a teaser (Shop handoff Trigger 4);
    Pro gets the full list."""
    gaps = [GapItem(**g) for g in shop_service.gap_analysis(db, user=user)]
    if _is_pro(user):
        return GapAnalysisResponse(gaps=gaps, is_teaser=False)
    return GapAnalysisResponse(
        gaps=gaps[:1],
        is_teaser=len(gaps) > 1,
        pro_teaser=(
            f"{len(gaps) - 1} more gaps found — upgrade to Drape Pro for the "
            "full analysis."
        )
        if len(gaps) > 1
        else None,
    )


@router.get("/wishlist", response_model=WishlistResponse)
def wishlist(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    affiliate: AffiliateProvider = Depends(get_affiliate_provider),
) -> WishlistResponse:
    entries = []
    for row, product, current in shop_service.wishlist(
        db, user=user, affiliate=affiliate
    ):
        drop = (
            row.added_price_cents - current
            if current is not None and current < row.added_price_cents
            else 0
        )
        entries.append(
            WishlistEntry(
                product=ProductResponse.model_validate(product),
                added_price_cents=row.added_price_cents,
                current_price_cents=current,
                price_drop_cents=drop,
                added_at=row.created_at,
            )
        )
    return WishlistResponse(items=entries)


@router.post(
    "/wishlist", response_model=WishlistResponse, status_code=status.HTTP_201_CREATED
)
def wishlist_add(
    payload: WishlistAddRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    affiliate: AffiliateProvider = Depends(get_affiliate_provider),
) -> WishlistResponse:
    try:
        shop_service.wishlist_add(db, user=user, product_id=payload.product_id)
    except ShopError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    return wishlist(db=db, user=user, affiliate=affiliate)


@router.delete("/wishlist/{product_id}", status_code=status.HTTP_204_NO_CONTENT)
def wishlist_remove(
    product_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> None:
    from uuid import UUID as _UUID

    try:
        pid = _UUID(product_id)
    except ValueError:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found")
    if not shop_service.wishlist_remove(db, user=user, product_id=pid):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found")
