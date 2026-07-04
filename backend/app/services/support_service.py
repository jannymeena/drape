"""Support tickets — persist contact / feature-request / bug-report submissions.

Persisting (vs. fire-and-forget email) gives an auditable record; an email or
queue side-effect can be added behind this same call later.
"""
from __future__ import annotations

import structlog
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.db.models import FeatureRequestVote, SupportTicket, User
from app.schemas.support import SupportKind, SupportTicketRequest

_log = structlog.get_logger("support")


def create_ticket(
    db: Session, *, user: User, kind: SupportKind, payload: SupportTicketRequest
) -> SupportTicket:
    ticket = SupportTicket(
        user_id=user.id,
        kind=kind,
        subject=payload.subject,
        message=payload.message,
        extra=payload.extra,
    )
    db.add(ticket)
    db.commit()
    db.refresh(ticket)
    _log.info("support.ticket.created", user_id=str(user.id), kind=kind, ticket_id=str(ticket.id))
    return ticket


class SupportError(Exception):
    """Domain-level support failure. Routes translate to 4xx."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code


def _score(db: Session, ticket_id) -> int:
    return int(
        db.scalar(
            select(func.coalesce(func.sum(FeatureRequestVote.vote), 0)).where(
                FeatureRequestVote.ticket_id == ticket_id
            )
        )
        or 0
    )


def _my_vote(db: Session, *, user_id, ticket_id) -> int:
    row = db.scalar(
        select(FeatureRequestVote).where(
            FeatureRequestVote.user_id == user_id,
            FeatureRequestVote.ticket_id == ticket_id,
        )
    )
    return row.vote if row is not None else 0


def list_feature_requests(
    db: Session, *, user: User, limit: int = 20
) -> list[tuple[SupportTicket, int, int]]:
    """Public feature-request board: every user's feature_request tickets with
    vote score + the caller's own vote, highest-scored first."""
    tickets = list(
        db.scalars(
            select(SupportTicket)
            .where(SupportTicket.kind == "feature_request")
            .order_by(SupportTicket.created_at.desc())
            .limit(200)
        ).all()
    )
    rows = [
        (t, _score(db, t.id), _my_vote(db, user_id=user.id, ticket_id=t.id))
        for t in tickets
    ]
    rows.sort(key=lambda r: (-r[1], r[0].created_at), reverse=False)
    return rows[:limit]


def vote_feature_request(
    db: Session, *, user: User, ticket_id, vote: int
) -> tuple[SupportTicket, int, int]:
    """Upsert the caller's vote (+1 / -1); 0 clears it. Idempotent."""
    ticket = db.get(SupportTicket, ticket_id)
    if ticket is None or ticket.kind != "feature_request":
        raise SupportError("not_found", "Feature request not found")
    row = db.scalar(
        select(FeatureRequestVote).where(
            FeatureRequestVote.user_id == user.id,
            FeatureRequestVote.ticket_id == ticket_id,
        )
    )
    if vote == 0:
        if row is not None:
            db.delete(row)
    elif row is None:
        db.add(FeatureRequestVote(user_id=user.id, ticket_id=ticket_id, vote=vote))
    else:
        row.vote = vote
    db.commit()
    _log.info(
        "support.feature_request.voted",
        user_id=str(user.id),
        ticket_id=str(ticket_id),
        vote=vote,
    )
    return ticket, _score(db, ticket_id), vote
