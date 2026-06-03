"""Phase 8d — account data export + self-delete (PIPEDA: access + erasure)."""
from __future__ import annotations

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.api.dependencies.auth import get_current_user
from app.api.dependencies.providers import get_encryptor
from app.db.models import User
from app.db.session import get_db
from app.services import account_service
from app.services.providers.crypto.base import Encryptor

router = APIRouter(prefix="/account", tags=["account"])


@router.get("/export")
def export_my_data(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    encryptor: Encryptor = Depends(get_encryptor),
) -> dict:
    """A portable JSON copy of the caller's data."""
    return account_service.export_user_data(db, user=user, encryptor=encryptor)


@router.delete("", status_code=status.HTTP_204_NO_CONTENT)
def delete_my_account(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> None:
    """Permanently delete the caller's account and all associated data."""
    account_service.delete_account(db, user=user)
