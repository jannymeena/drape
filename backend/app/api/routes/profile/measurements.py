"""Phase 5b — measurements routes.

POST = bulk submit (all 8 measurements). The service encrypts before persisting,
advances onboarding to avatar_reveal, and returns the just-submitted values.
GET = decrypt-and-return (404 if the user hasn't submitted).
"""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.dependencies.auth import get_current_user
from app.api.dependencies.providers import get_encryptor
from app.db.models import User
from app.db.session import get_db
from app.schemas.measurements import (
    MeasurementsRequest,
    MeasurementsResponse,
    MeasurementsSubmitResponse,
)
from app.services import measurements_service
from app.services.measurements_service import MeasurementsError
from app.services.providers.crypto.base import Encryptor

router = APIRouter()


@router.post("/measurements", response_model=MeasurementsSubmitResponse)
def submit_measurements(
    payload: MeasurementsRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    encryptor: Encryptor = Depends(get_encryptor),
) -> MeasurementsSubmitResponse:
    measurements_service.submit(db, encryptor=encryptor, user=user, payload=payload)
    return MeasurementsSubmitResponse(
        measurements_completed=True, next_step="avatar_reveal"
    )


@router.get("/measurements", response_model=MeasurementsResponse)
def get_measurements(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    encryptor: Encryptor = Depends(get_encryptor),
) -> MeasurementsResponse:
    try:
        result = measurements_service.get_for_user(db, encryptor=encryptor, user=user)
    except MeasurementsError:
        # Don't leak crypto details to the client.
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Measurements could not be read",
        )
    if result is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No measurements submitted yet",
        )
    return result
