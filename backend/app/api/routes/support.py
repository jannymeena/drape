"""Phase 8e — support: contact, feature requests, bug reports."""
from __future__ import annotations

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.api.dependencies.auth import get_current_user
from app.db.models import User
from app.db.session import get_db
from app.schemas.support import SupportTicketRequest, SupportTicketResponse
from app.services import support_service

router = APIRouter(prefix="/support", tags=["support"])


def _create(db: Session, user: User, kind: str, payload: SupportTicketRequest) -> SupportTicketResponse:
    ticket = support_service.create_ticket(db, user=user, kind=kind, payload=payload)
    return SupportTicketResponse.model_validate(ticket)


@router.post("/contact", response_model=SupportTicketResponse, status_code=status.HTTP_201_CREATED)
def contact(
    payload: SupportTicketRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> SupportTicketResponse:
    return _create(db, user, "contact", payload)


@router.post("/feature-request", response_model=SupportTicketResponse, status_code=status.HTTP_201_CREATED)
def feature_request(
    payload: SupportTicketRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> SupportTicketResponse:
    return _create(db, user, "feature_request", payload)


@router.post("/bug-report", response_model=SupportTicketResponse, status_code=status.HTTP_201_CREATED)
def bug_report(
    payload: SupportTicketRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> SupportTicketResponse:
    return _create(db, user, "bug_report", payload)
