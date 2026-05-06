"""Phase 5c — wardrobe item routes.

The CTO doc routes use `/wardrobe/user/{user_id}` and similar — we expose
`/wardrobe` (current user) instead. Trusting the bearer token avoids IDOR.
"""
from __future__ import annotations

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.dependencies.auth import get_current_user
from app.db.models import User
from app.db.session import get_db
from app.schemas.wardrobe import (
    LogWornRequest,
    LogWornResponse,
    ToggleFavoriteResponse,
    WardrobeItemCreate,
    WardrobeItemResponse,
    WardrobeItemUpdate,
    WardrobeListQuery,
    WardrobeListResponse,
)
from app.services import wardrobe_service
from app.services.wardrobe_service import WardrobeError

router = APIRouter(prefix="/wardrobe", tags=["wardrobe"])


def _translate(err: WardrobeError) -> HTTPException:
    if err.code == "not_found":
        return HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(err))
    return HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(err))


@router.get("", response_model=WardrobeListResponse)
def list_items(
    query: WardrobeListQuery = Depends(),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> WardrobeListResponse:
    rows, total = wardrobe_service.list_for_user(db, user=user, query=query)
    return WardrobeListResponse(
        items=[WardrobeItemResponse.model_validate(r) for r in rows],
        total=total,
        limit=query.limit,
        offset=query.offset,
    )


@router.post("/items", response_model=WardrobeItemResponse, status_code=status.HTTP_201_CREATED)
def create_item(
    payload: WardrobeItemCreate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> WardrobeItemResponse:
    return WardrobeItemResponse.model_validate(
        wardrobe_service.create_item(db, user=user, payload=payload)
    )


@router.get("/items/{item_id}", response_model=WardrobeItemResponse)
def get_item(
    item_id: UUID,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> WardrobeItemResponse:
    try:
        return WardrobeItemResponse.model_validate(
            wardrobe_service.get_item(db, user=user, item_id=item_id)
        )
    except WardrobeError as e:
        raise _translate(e)


@router.patch("/items/{item_id}", response_model=WardrobeItemResponse)
def update_item(
    item_id: UUID,
    payload: WardrobeItemUpdate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> WardrobeItemResponse:
    try:
        return WardrobeItemResponse.model_validate(
            wardrobe_service.update_item(db, user=user, item_id=item_id, payload=payload)
        )
    except WardrobeError as e:
        raise _translate(e)


@router.delete("/items/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_item(
    item_id: UUID,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> None:
    try:
        wardrobe_service.delete_item(db, user=user, item_id=item_id)
    except WardrobeError as e:
        raise _translate(e)


@router.post("/items/{item_id}/log-worn", response_model=LogWornResponse)
def log_worn(
    item_id: UUID,
    payload: LogWornRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> LogWornResponse:
    try:
        item, already = wardrobe_service.log_worn(
            db, user=user, item_id=item_id, payload=payload
        )
    except WardrobeError as e:
        raise _translate(e)
    return LogWornResponse(
        item_id=item.id,
        worn_count=item.worn_count,
        last_worn=item.last_worn,
        cost_per_wear=item.cost_per_wear,
        already_logged_today=already,
    )


@router.post("/items/{item_id}/toggle-favorite", response_model=ToggleFavoriteResponse)
def toggle_favorite(
    item_id: UUID,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> ToggleFavoriteResponse:
    try:
        item = wardrobe_service.toggle_favorite(db, user=user, item_id=item_id)
    except WardrobeError as e:
        raise _translate(e)
    return ToggleFavoriteResponse(
        item_id=item.id,
        is_favorite=item.is_favorite,
        favorited_at=item.favorited_at,
    )
