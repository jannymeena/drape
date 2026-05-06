"""Phase 5b — body measurements request/response shapes.

Wire format follows the CTO doc Screen 11–18: values are always submitted in
metric (cm / kg). The client converts imperial input client-side before the
bulk POST. `unit_system` is stored as a UI-display hint only.
"""
from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

UnitSystem = Literal["metric", "imperial"]

# Plausible human ranges. Tighter bounds reject mojibake / unit-confusion errors
# (e.g. someone entering "70" inches as cm). Bounds are deliberately wide enough
# to cover edge cases (children's measurements, very tall/short adults).
_HEIGHT = (50.0, 250.0)   # cm
_WEIGHT = (20.0, 300.0)   # kg
_BODY = (10.0, 250.0)     # cm — shoulders, chest, waist, inseam, thigh, hips


class MeasurementsRequest(BaseModel):
    height_cm: float = Field(ge=_HEIGHT[0], le=_HEIGHT[1])
    weight_kg: float | None = Field(default=None, ge=_WEIGHT[0], le=_WEIGHT[1])
    shoulders_cm: float = Field(ge=_BODY[0], le=_BODY[1])
    chest_cm: float = Field(ge=_BODY[0], le=_BODY[1])
    waist_cm: float = Field(ge=_BODY[0], le=_BODY[1])
    inseam_cm: float = Field(ge=_BODY[0], le=_BODY[1])
    thigh_cm: float = Field(ge=_BODY[0], le=_BODY[1])
    hips_cm: float = Field(ge=_BODY[0], le=_BODY[1])
    unit_system: UnitSystem = "metric"


class MeasurementsResponse(BaseModel):
    """Decrypted view of the user's measurements + completion metadata."""

    model_config = ConfigDict(from_attributes=True)

    height_cm: float
    weight_kg: float | None
    shoulders_cm: float
    chest_cm: float
    waist_cm: float
    inseam_cm: float
    thigh_cm: float
    hips_cm: float
    unit_system: UnitSystem
    is_complete: bool


class MeasurementsSubmitResponse(BaseModel):
    success: bool = True
    measurements_completed: bool
    next_step: Literal["avatar_reveal"]
