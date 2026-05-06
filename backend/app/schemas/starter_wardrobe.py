"""Phase 5d — starter wardrobe request/response shapes.

Templates expose only the metadata the client needs to render a "this kit
is for you" preview. Item-level details live inside the materialized
`wardrobe_items` rows the client fetches via /wardrobe.
"""
from __future__ import annotations

from datetime import datetime
from typing import Any
from uuid import UUID

from pydantic import BaseModel, ConfigDict


class StarterWardrobeTemplateResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    template_id: str
    name: str
    gender: str | None
    age_range: str | None
    style_profile: str | None
    total_items: int
    items: list[dict[str, Any]]
    is_active: bool
    version: int


class TemplatesListResponse(BaseModel):
    templates: list[StarterWardrobeTemplateResponse]


class AssignStarterWardrobeRequest(BaseModel):
    """Optional explicit override. When omitted the server picks based on the
    user's shopping_style + age_range; missing/unsupported combinations fall
    through to a neutral default."""

    template_id: str | None = None


class UserStarterWardrobeResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    template_id: UUID
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
    """Returns the assignment, the chosen template's `template_id` slug, the
    count of items materialized this call (0 if no-op), and the live
    transition row so the client can render progress immediately."""

    assignment: UserStarterWardrobeResponse
    template_id: str
    items_materialized: int
    swapped: bool
    transition: TransitionTrackingResponse


class DeactivateStarterWardrobeRequest(BaseModel):
    reason: str | None = None


class DeactivateStarterWardrobeResponse(BaseModel):
    assignment: UserStarterWardrobeResponse
