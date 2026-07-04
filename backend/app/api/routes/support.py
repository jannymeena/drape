"""Phase 8e — support: contact, feature requests, bug reports."""
from __future__ import annotations

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.dependencies.auth import get_current_user
from app.db.models import User
from app.db.session import get_db
from app.schemas.support import (
    FeatureRequestItem,
    FeatureRequestListResponse,
    FeatureRequestVoteRequest,
    FeatureRequestVoteResponse,
    SupportTicketRequest,
    SupportTicketResponse,
)
from app.services import support_service
from app.services.support_service import SupportError

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


def _to_item(ticket, score: int, my_vote: int) -> FeatureRequestItem:
    return FeatureRequestItem(
        id=ticket.id,
        subject=ticket.subject,
        message=ticket.message,
        status=ticket.status,
        created_at=ticket.created_at,
        score=score,
        my_vote=my_vote,
    )


@router.get("/feature-requests", response_model=FeatureRequestListResponse)
def list_feature_requests(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> FeatureRequestListResponse:
    """Public board: everyone's feature requests, highest score first."""
    rows = support_service.list_feature_requests(db, user=user)
    return FeatureRequestListResponse(items=[_to_item(*row) for row in rows])


@router.post(
    "/feature-requests/{ticket_id}/vote",
    response_model=FeatureRequestVoteResponse,
)
def vote_feature_request(
    ticket_id: UUID,
    payload: FeatureRequestVoteRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> FeatureRequestVoteResponse:
    """Upsert the caller's vote (+1 / -1); 0 clears it."""
    try:
        _, score, my_vote = support_service.vote_feature_request(
            db, user=user, ticket_id=ticket_id, vote=payload.vote
        )
    except SupportError as err:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail=str(err)
        ) from err
    return FeatureRequestVoteResponse(
        ticket_id=ticket_id, score=score, my_vote=my_vote
    )
