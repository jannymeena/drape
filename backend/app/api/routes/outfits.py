"""Phase 6c — outfit interaction routes.

Routes are scoped to the bearer-token user. `outfit_service._get_outfit_owned`
is the only path to a row by id, so cross-user IDOR is structurally impossible
(matches the wardrobe.py pattern).
"""
from __future__ import annotations

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.api.dependencies.auth import get_current_user
from app.api.dependencies.providers import get_ai_provider, get_weather_provider
from app.api.routes.today import _to_outfit_response
from app.db.models import User
from app.db.session import get_db
from app.schemas.outfit import (
    HistoryFilter,
    LogOutfitResponse,
    MixAndMatchRequest,
    MixAndMatchResponse,
    OutfitFavoriteResponse,
    OutfitHistoryResponse,
    OutfitReasoningResponse,
    OutfitResponse,
    payload_to_outfit_items,
)
from app.core.providers import providers
from app.services import outfit_service, push_service, usage_service
from app.services.outfit_service import OutfitError
from app.services.providers.ai.base import AIProvider
from app.services.providers.weather.base import WeatherProvider
from app.services.billing_service import PLAN_SUMMARY
from app.services.usage_service import UsageError

router = APIRouter(prefix="/outfits", tags=["outfits"])


def _translate(err: OutfitError) -> HTTPException:
    if err.code == "not_found":
        return HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(err))
    if err.code in ("ai_call_failed", "parse_failed"):
        return HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail={"error": err.code, "message": str(err)},
        )
    return HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(err))


def _translate_usage(
    err: UsageError, *, db: Session | None = None, user: User | None = None
) -> HTTPException:
    # Transactional push (2.3): fire-and-forget nudge when the weekly cap
    # hits — dev provider just logs; real delivery lands in Tier 3.3.
    if db is not None and user is not None and err.code == "limit_reached":
        push_service.notify_user(
            db,
            push=providers.push,
            user_id=user.id,
            title="You've hit this week's free limit",
            body=str(err),
            data={"route": "paywall"},
        )
    return HTTPException(
        status_code=status.HTTP_429_TOO_MANY_REQUESTS,
        detail={
            "error": err.code,
            "resource": err.resource,
            "used": err.used,
            "limit": err.limit,
            "resets_at": err.resets_at.isoformat() if err.resets_at else None,
            "message": str(err),
            # Paywall payload — plans the client can render immediately.
            "plans": PLAN_SUMMARY,
        },
    )


@router.get("/history", response_model=OutfitHistoryResponse)
def history(
    filter: HistoryFilter = Query(default="all"),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> OutfitHistoryResponse:
    return outfit_service.get_history(db, user=user, filter_=filter)


@router.get("/{outfit_id}/reasoning", response_model=OutfitReasoningResponse)
def reasoning(
    outfit_id: UUID,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> OutfitReasoningResponse:
    try:
        return outfit_service.get_reasoning(db, user=user, outfit_id=outfit_id)
    except OutfitError as e:
        raise _translate(e)


@router.post("/{outfit_id}/regenerate", response_model=OutfitResponse)
async def regenerate(
    outfit_id: UUID,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    ai: AIProvider = Depends(get_ai_provider),
    weather: WeatherProvider = Depends(get_weather_provider),
) -> OutfitResponse:
    try:
        usage_service.check_and_increment(
            db, user=user, resource="outfits", count=1
        )
        fresh = await outfit_service.regenerate(
            db=db, user=user, ai=ai, weather=weather, outfit_id=outfit_id
        )
    except UsageError as e:
        raise _translate_usage(e, db=db, user=user)
    except OutfitError as e:
        raise _translate(e)
    return _to_outfit_response(fresh)


@router.post("/{outfit_id}/mix-and-match", response_model=MixAndMatchResponse)
def mix_and_match(
    outfit_id: UUID,
    payload: MixAndMatchRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> MixAndMatchResponse:
    try:
        usage_service.check_and_increment(
            db, user=user, resource="mix_and_match", count=1
        )
        outfit, score = outfit_service.mix_and_match(
            db, user=user, outfit_id=outfit_id, swaps=payload.swapped_items
        )
    except UsageError as e:
        raise _translate_usage(e, db=db, user=user)
    except OutfitError as e:
        raise _translate(e)
    return MixAndMatchResponse(
        outfit_id=outfit.id,
        items=payload_to_outfit_items(outfit.items),
        compatibility_score=score,
        image_url=outfit.image_url,
    )


@router.post("/{outfit_id}/toggle-favorite", response_model=OutfitFavoriteResponse)
def toggle_favorite(
    outfit_id: UUID,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> OutfitFavoriteResponse:
    try:
        outfit = outfit_service.toggle_favorite(db, user=user, outfit_id=outfit_id)
    except OutfitError as e:
        raise _translate(e)
    return OutfitFavoriteResponse(
        outfit_id=outfit.id,
        is_favorite=outfit.is_favorite,
        favorited_at=outfit.favorited_at,
    )


@router.post("/{outfit_id}/log", response_model=LogOutfitResponse)
def log_outfit(
    outfit_id: UUID,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> LogOutfitResponse:
    try:
        outfit, toast, streak = outfit_service.log_outfit(
            db, user=user, outfit_id=outfit_id
        )
    except OutfitError as e:
        raise _translate(e)
    return LogOutfitResponse(
        outfit_id=outfit.id,
        logged_at=outfit.logged_at,  # type: ignore[arg-type]
        current_streak=streak.current_streak,
        longest_streak=streak.longest_streak,
        total_outfits_logged=streak.total_outfits_logged,
        toast=toast,
    )
