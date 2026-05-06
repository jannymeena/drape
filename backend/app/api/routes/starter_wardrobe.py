"""Phase 5d — starter wardrobe routes.

Three endpoints scoped to the bearer-token user:
  - GET  /starter-wardrobe/templates   browse the catalogue
  - POST /starter-wardrobe/assign      assign (auto-pick or explicit) +
                                       materialize items into /wardrobe
  - POST /starter-wardrobe/deactivate  manual opt-out

Auto-deactivation when the user reaches 15 real items is handled inside
starter_wardrobe_service.recompute_transition (called from wardrobe_service
on item create/delete) — no separate endpoint required.
"""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.dependencies.auth import get_current_user
from app.db.models import User
from app.db.session import get_db
from app.schemas.starter_wardrobe import (
    AssignStarterWardrobeRequest,
    AssignStarterWardrobeResponse,
    DeactivateStarterWardrobeRequest,
    DeactivateStarterWardrobeResponse,
    StarterWardrobeTemplateResponse,
    TemplatesListResponse,
    TransitionTrackingResponse,
    UserStarterWardrobeResponse,
)
from app.services import starter_wardrobe_service
from app.services.starter_wardrobe_service import StarterWardrobeError

router = APIRouter(prefix="/starter-wardrobe", tags=["starter-wardrobe"])


def _translate(err: StarterWardrobeError) -> HTTPException:
    if err.code in ("template_not_found", "not_assigned"):
        return HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(err))
    return HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(err))


@router.get("/templates", response_model=TemplatesListResponse)
def list_templates(
    db: Session = Depends(get_db),
    _user: User = Depends(get_current_user),
) -> TemplatesListResponse:
    templates = starter_wardrobe_service.list_active_templates(db)
    return TemplatesListResponse(
        templates=[StarterWardrobeTemplateResponse.model_validate(t) for t in templates]
    )


@router.post("/assign", response_model=AssignStarterWardrobeResponse)
def assign(
    payload: AssignStarterWardrobeRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> AssignStarterWardrobeResponse:
    try:
        assignment, _template, items, swapped = starter_wardrobe_service.assign(
            db, user=user, template_id=payload.template_id
        )
    except StarterWardrobeError as e:
        raise _translate(e)
    transition = starter_wardrobe_service.get_or_create_transition_row(
        db, user_id=user.id
    )
    return AssignStarterWardrobeResponse(
        assignment=UserStarterWardrobeResponse.model_validate(assignment),
        template_id=_template.template_id,
        items_materialized=len(items),
        swapped=swapped,
        transition=TransitionTrackingResponse.model_validate(transition),
    )


@router.post("/deactivate", response_model=DeactivateStarterWardrobeResponse)
def deactivate(
    payload: DeactivateStarterWardrobeRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> DeactivateStarterWardrobeResponse:
    try:
        assignment = starter_wardrobe_service.deactivate(
            db, user=user, reason=payload.reason or "manual"
        )
    except StarterWardrobeError as e:
        raise _translate(e)
    return DeactivateStarterWardrobeResponse(
        assignment=UserStarterWardrobeResponse.model_validate(assignment),
    )
