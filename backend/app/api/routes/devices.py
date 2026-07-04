"""Device registration for push notifications (2.3 — item 11d framework)."""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.dependencies.auth import get_current_user
from app.db.models import User
from app.db.session import get_db
from app.schemas.device import DeviceRegisterRequest, DeviceResponse
from app.services import push_service

router = APIRouter(prefix="/devices", tags=["devices"])


@router.post("", response_model=DeviceResponse, status_code=status.HTTP_201_CREATED)
def register_device(
    payload: DeviceRegisterRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> DeviceResponse:
    """Upsert by token — re-registering moves the token to the caller."""
    device = push_service.register_device(
        db, user=user, platform=payload.platform, token=payload.token
    )
    return DeviceResponse.model_validate(device)


@router.delete("/{token}", status_code=status.HTTP_204_NO_CONTENT)
def remove_device(
    token: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> None:
    if not push_service.remove_device(db, user=user, token=token):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Device not registered"
        )
