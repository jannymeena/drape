"""Phase 6c — Today dashboard + force-generate.

Two endpoints:
  - GET  /today/dashboard           composite payload for the home tab
  - POST /today/generate-outfits    force-generate (used by Empty/Error states)

Generation uses the same `outfit_service.generate_for_user` path the dashboard
calls when no outfits exist yet, so behaviour is consistent.
"""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.dependencies.auth import get_current_user
from app.api.dependencies.providers import get_ai_provider, get_weather_provider
from app.db.models import User
from app.db.session import get_db
from app.schemas.outfit import (
    BannerDismissResponse,
    GenerateOccasionRequest,
    GenerateOutfitsRequest,
    GenerateOutfitsResponse,
    OutfitResponse,
    TodayBanners,
    TodayDashboardResponse,
    TodayUsage,
    TodayUser,
    WeatherContext,
    payload_to_outfit_items,
)
from app.core.localtime import next_day_rollover_utc
from app.core.providers import providers
from app.services import banner_service, outfit_service, push_service, usage_service
from app.services.outfit_service import (
    DAILY_OUTFIT_TARGET,
    OutfitError,
    _starter_wardrobe_banner,  # type: ignore[attr-defined]
    _outfits_generated_today,  # type: ignore[attr-defined]
    _profile_incomplete,  # type: ignore[attr-defined]
)
from app.services.providers.ai.base import AIProvider
from app.services.providers.weather.base import WeatherProvider, WeatherProviderError
from app.services.billing_service import PLAN_SUMMARY
from app.services.usage_service import UsageError

router = APIRouter(prefix="/today", tags=["today"])


def _translate(err: OutfitError) -> HTTPException:
    if err.code == "no_wardrobe":
        return HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(err))
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


def _to_outfit_response(outfit) -> OutfitResponse:
    return OutfitResponse(
        id=outfit.id,
        user_id=outfit.user_id,
        occasion=outfit.occasion,
        items=payload_to_outfit_items(outfit.items),
        image_url=outfit.image_url,
        ai_reasoning_short=outfit.ai_reasoning_short,
        ai_reasoning_full=outfit.ai_reasoning_full,
        compatibility_score=outfit.compatibility_score,
        weather_context=(
            WeatherContext.model_validate(outfit.weather_context)
            if outfit.weather_context
            else None
        ),
        using_starter_wardrobe=outfit.using_starter_wardrobe,
        generation_method=outfit.generation_method,
        is_logged=outfit.is_logged,
        logged_at=outfit.logged_at,
        worn_count=outfit.worn_count,
        is_favorite=outfit.is_favorite,
        created_at=outfit.created_at,
        updated_at=outfit.updated_at,
    )


# (Daily reset is the user's next 05:00-local rollover — see core/localtime.)


@router.get("/dashboard", response_model=TodayDashboardResponse)
async def dashboard(
    lat: float | None = None,
    lon: float | None = None,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    weather: WeatherProvider = Depends(get_weather_provider),
) -> TodayDashboardResponse:
    # Read-only frame: the shell + any outfits already generated today + the
    # occasions still pending. Generation happens out-of-band via
    # POST /today/outfits, so the client paints the shell instantly and fills
    # each card as its AI call returns. No AI provider needed here.
    outfits = outfit_service._today_outfits(db, user=user)[:DAILY_OUTFIT_TARGET]
    ready = outfit_service.wardrobe_ready(db, user_id=user.id)
    pending = outfit_service.pending_occasions(db, user=user) if ready else []

    weather_ctx = None
    if outfits and outfits[0].weather_context:
        weather_ctx = WeatherContext.model_validate(outfits[0].weather_context)
    else:
        # No outfit to borrow weather from yet — do a direct lookup so the chip
        # still shows conditions while the outfit cards generate. Real device
        # coords personalize it; absent, the service falls back to Toronto.
        try:
            snap = await weather.current(
                lat if lat is not None else 43.65,
                lon if lon is not None else -79.38,
            )
            weather_ctx = WeatherContext(
                temp_c=snap.temp_c,
                feels_like_c=snap.feels_like_c,
                condition=snap.condition,
                humidity_pct=snap.humidity_pct,
                wind_kph=snap.wind_kph,
            )
        except WeatherProviderError:
            weather_ctx = None

    return TodayDashboardResponse(
        user=TodayUser(
            name=user.display_name,
            location=user.location,
            timezone=user.timezone,
        ),
        weather=weather_ctx,
        outfits=[_to_outfit_response(o) for o in outfits],
        usage=TodayUsage(
            outfits_generated_today=_outfits_generated_today(db, user=user),
            outfit_target_per_day=DAILY_OUTFIT_TARGET,
            resets_at=next_day_rollover_utc(user),
        ),
        banners=TodayBanners(
            starter_wardrobe=_starter_wardrobe_banner(db, user_id=user.id),
            incomplete_profile=_profile_incomplete(db, user_id=user.id),
        ),
        wardrobe_ready=ready,
        pending_occasions=pending,
    )


@router.post("/outfits", response_model=OutfitResponse)
async def generate_occasion(
    payload: GenerateOccasionRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    ai: AIProvider = Depends(get_ai_provider),
    weather: WeatherProvider = Depends(get_weather_provider),
) -> OutfitResponse:
    """Generate (or return the existing) outfit for ONE occasion — the Today
    dashboard's per-occasion fill. Idempotent for an occasion already generated
    today. Part of the free daily set: it does NOT consume a weekly outfit
    credit (mirrors the old inline dashboard generation). Manual regeneration
    via POST /outfits/{id}/regenerate is what counts against the limit."""
    try:
        outfit = await outfit_service.ensure_one(
            db=db,
            user=user,
            ai=ai,
            weather=weather,
            occasion=payload.occasion,
            lat=payload.lat,
            lon=payload.lon,
        )
    except OutfitError as e:
        raise _translate(e)
    return _to_outfit_response(outfit)


@router.post("/generate-outfits", response_model=GenerateOutfitsResponse)
async def generate_outfits(
    payload: GenerateOutfitsRequest | None = None,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    ai: AIProvider = Depends(get_ai_provider),
    weather: WeatherProvider = Depends(get_weather_provider),
) -> GenerateOutfitsResponse:
    """Force-generate the daily set of 3 outfits. Each outfit counts as one
    `outfits` usage tick — 21/wk free, unlimited Pro."""
    request = payload or GenerateOutfitsRequest()
    occasions = tuple(request.occasions or outfit_service.DEFAULT_OCCASIONS)
    try:
        usage_service.check_and_increment(
            db, user=user, resource="outfits", count=len(occasions)
        )
        outfits = await outfit_service.generate_for_user(
            db=db,
            user=user,
            ai=ai,
            weather=weather,
            occasions=occasions,
            lat=request.lat,
            lon=request.lon,
        )
    except UsageError as e:
        raise _translate_usage(e, db=db, user=user)
    except OutfitError as e:
        raise _translate(e)
    using_starter = any(o.using_starter_wardrobe for o in outfits)
    return GenerateOutfitsResponse(
        outfits=[_to_outfit_response(o) for o in outfits],
        using_starter_wardrobe=using_starter,
    )


@router.post("/banners/{banner}/dismiss", response_model=BannerDismissResponse)
def dismiss_banner(
    banner: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> BannerDismissResponse:
    """Hide a dashboard banner for 7 days (CTO doc 2 banner rules)."""
    if banner not in banner_service.KNOWN_BANNERS:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Unknown banner {banner!r}; expected one of "
            f"{sorted(banner_service.KNOWN_BANNERS)}",
        )
    row = banner_service.dismiss(db, user_id=user.id, banner=banner)
    return BannerDismissResponse(
        banner=row.banner,
        dismissed_at=row.dismissed_at,
        hidden_for_days=banner_service.DISMISS_WINDOW_DAYS,
    )
