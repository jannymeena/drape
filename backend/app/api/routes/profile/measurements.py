"""Phase 5b — measurements routes.

POST = bulk submit (all 8 measurements). The service encrypts before persisting
and returns the just-submitted values. PATCH = save some of them, merged into
what's saved (the set stays incomplete until every required one is in). Measurements sit outside onboarding
since the 7-step Style Blueprint redesign — they're entered from the Shop and
Profile tabs — so submitting does not advance the onboarding step machine.
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
    MeasurementsPatchRequest,
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
    return MeasurementsSubmitResponse(measurements_completed=True)


@router.patch("/measurements", response_model=MeasurementsResponse)
def update_measurements(
    payload: MeasurementsPatchRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    encryptor: Encryptor = Depends(get_encryptor),
) -> MeasurementsResponse:
    """Partial save: only the fields sent change (null clears one). Returns
    the merged set."""
    try:
        return measurements_service.update(
            db,
            encryptor=encryptor,
            user=user,
            changes=payload.changes(),
            unit_system=payload.unit_system,
        )
    except MeasurementsError as e:
        if e.code == "unknown_field":
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(e)
            )
        # Don't leak crypto details to the client.
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Measurements could not be saved",
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
