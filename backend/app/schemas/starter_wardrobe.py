"""Phase 5d — starter wardrobe request/response shapes.

Item-level details live inside the materialized `wardrobe_items` rows the
client fetches via /wardrobe.
"""
from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict


class UserStarterWardrobeResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    is_active: bool
    assigned_at: datetime
    deactivated_at: datetime | None
    deactivation_reason: str | None


class TransitionTrackingResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    real_items_count: int
    starter_items_count: int
    percentage_real: float
    blending_ratio: float
    last_updated: datetime


class AssignStarterWardrobeResponse(BaseModel):
    """Returns the assignment, the capsule slug (`template_id`, kept for
    client compatibility), the count of items materialized this call (0 if
    no-op), and the live transition row so the client can render progress
    immediately."""

    assignment: UserStarterWardrobeResponse
    template_id: str
    items_materialized: int
    swapped: bool
    transition: TransitionTrackingResponse


class DeactivateStarterWardrobeRequest(BaseModel):
    reason: str | None = None


class DeactivateStarterWardrobeResponse(BaseModel):
    assignment: UserStarterWardrobeResponse
