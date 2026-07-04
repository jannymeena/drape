"""Device registration wire shapes (push framework, 2.3)."""
from __future__ import annotations

from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class DeviceRegisterRequest(BaseModel):
    platform: Literal["ios", "android"]
    token: str = Field(min_length=8, max_length=255)


class DeviceResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    platform: str
    token: str
    created_at: datetime
