"""Phase 5c — wardrobe item routes.

The CTO doc routes use `/wardrobe/user/{user_id}` and similar — we expose
`/wardrobe` (current user) instead. Trusting the bearer token avoids IDOR.
"""
from __future__ import annotations

from uuid import UUID

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from sqlalchemy.orm import Session

from app.api.dependencies.auth import get_current_user
from app.api.dependencies.providers import get_image_storage
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
from app.services.providers.image.base import ImageStorageProvider
from app.services.wardrobe_service import WardrobeError

_ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp"}
_MAX_IMAGE_BYTES = 8 * 1024 * 1024  # 8 MiB

router = APIRouter(prefix="/wardrobe", tags=["wardrobe"])


def _translate(err: WardrobeError) -> HTTPException:
    if err.code == "not_found":
        return HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(err))
    return HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(err))


async def _read_image(upload: UploadFile) -> tuple[bytes, str]:
    if upload.content_type not in _ALLOWED_IMAGE_TYPES:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail=f"Unsupported content type {upload.content_type!r}; "
            f"expected one of {sorted(_ALLOWED_IMAGE_TYPES)}",
        )
    content = await upload.read()
    if len(content) == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Empty file upload",
        )
    if len(content) > _MAX_IMAGE_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"File exceeds {_MAX_IMAGE_BYTES} bytes",
        )
    return content, upload.content_type


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


@router.post("/items/{item_id}/images", response_model=WardrobeItemResponse)
async def add_images(
    item_id: UUID,
    files: list[UploadFile] = File(...),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    storage: ImageStorageProvider = Depends(get_image_storage),
) -> WardrobeItemResponse:
    if not files:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="At least one file is required",
        )
    uploads = [await _read_image(f) for f in files]
    try:
        item = wardrobe_service.add_images(
            db, user=user, item_id=item_id, uploads=uploads, storage=storage
        )
    except WardrobeError as e:
        raise _translate(e)
    return WardrobeItemResponse.model_validate(item)


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
