"""Phase 5b — body measurements request/response shapes.

Wire format follows the CTO doc Screen 11–18: values are always submitted in
metric (cm / kg). The client converts imperial input client-side before the
bulk POST. `unit_system` is stored as a UI-display hint only.
"""
from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator

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


class MeasurementsPatchRequest(BaseModel):
    """PATCH: only the fields sent change. A field sent as null is cleared;
    one left out keeps its saved value. Used when only some measurements are
    known — e.g. the four the Style Blueprint shape finder asks for."""

    model_config = ConfigDict(extra="forbid")

    height_cm: float | None = Field(default=None, ge=_HEIGHT[0], le=_HEIGHT[1])
    weight_kg: float | None = Field(default=None, ge=_WEIGHT[0], le=_WEIGHT[1])
    shoulders_cm: float | None = Field(default=None, ge=_BODY[0], le=_BODY[1])
    chest_cm: float | None = Field(default=None, ge=_BODY[0], le=_BODY[1])
    waist_cm: float | None = Field(default=None, ge=_BODY[0], le=_BODY[1])
    inseam_cm: float | None = Field(default=None, ge=_BODY[0], le=_BODY[1])
    thigh_cm: float | None = Field(default=None, ge=_BODY[0], le=_BODY[1])
    hips_cm: float | None = Field(default=None, ge=_BODY[0], le=_BODY[1])
    unit_system: UnitSystem | None = None

    @model_validator(mode="after")
    def _changes_something(self) -> "MeasurementsPatchRequest":
        if not self.changes():
            raise ValueError("send at least one measurement")
        return self

    def changes(self) -> dict[str, float | None]:
        """The measurements sent (unit_system aside), null ones included."""
        sent = self.model_dump(exclude_unset=True)
        sent.pop("unit_system", None)
        return sent


class MeasurementsResponse(BaseModel):
    """Decrypted view of the user's measurements + completion metadata.
    A field is null until it's been saved: a partial set (PATCH) is stored
    with `is_complete` false."""

    model_config = ConfigDict(from_attributes=True)

    height_cm: float | None = None
    weight_kg: float | None = None
    shoulders_cm: float | None = None
    chest_cm: float | None = None
    waist_cm: float | None = None
    inseam_cm: float | None = None
    thigh_cm: float | None = None
    hips_cm: float | None = None
    unit_system: UnitSystem
    is_complete: bool


class MeasurementsSubmitResponse(BaseModel):
    success: bool = True
    measurements_completed: bool
