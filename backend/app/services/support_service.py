"""Support tickets — persist contact / feature-request / bug-report submissions.

Persisting (vs. fire-and-forget email) gives an auditable record; an email or
queue side-effect can be added behind this same call later.
"""
from __future__ import annotations

import structlog
from sqlalchemy.orm import Session

from app.db.models import SupportTicket, User
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
