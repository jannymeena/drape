"""Phase 6d — Pro-tier gating.

Used as a FastAPI dependency:

    @router.get(..., response_model=...)
    def intelligence_report(
        user: User = Depends(require_pro),
        ...
    ): ...

Free users get a 402 with `code: pro_required` and a feature label so the
client can render the upsell sheet contextually.
"""
from __future__ import annotations

from fastapi import Depends, HTTPException, Request, status

from app.api.dependencies.auth import get_current_user
from app.db.models import User
from app.services.billing_service import PLAN_SUMMARY


def _is_pro(user: User) -> bool:
    return (user.subscription_tier or "free") == "pro"


def require_pro(
    request: Request, user: User = Depends(get_current_user)
) -> User:
    if _is_pro(user):
        return user
    feature = request.url.path.rsplit("/", 1)[-1] or "this_feature"
    raise HTTPException(
        status_code=status.HTTP_402_PAYMENT_REQUIRED,
        detail={
            "error": "pro_required",
            "feature": feature,
            "message": (
                "This feature is available on Drape Pro. "
                "Upgrade to unlock unlimited intelligence reports."
            ),
            # Paywall payload — plans the client can render immediately.
            "plans": PLAN_SUMMARY,
        },
    )
