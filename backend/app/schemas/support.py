from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

SupportKind = Literal["contact", "feature_request", "bug_report"]


class SupportTicketRequest(BaseModel):
    subject: str | None = Field(default=None, max_length=200)
    message: str = Field(min_length=1, max_length=5000)
    # Free-form extras: category for feature requests, device/app info for bugs.
    extra: dict | None = None


class SupportTicketResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    kind: SupportKind
    subject: str | None
    message: str
    status: str
    created_at: datetime
