"""Phase 5b — measurements service.

The whole measurement payload is serialized to JSON, encrypted with AES-256-GCM
(user_id as AAD), and stored as a single `bytea` column. Decryption happens on
read; an operator with raw DB access cannot infer measurements without the DEK.
"""
from __future__ import annotations

import json

import structlog
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.models import User, UserMeasurements
from app.schemas.measurements import MeasurementsRequest, MeasurementsResponse
from app.services.providers.crypto.base import Encryptor

_log = structlog.get_logger("measurements")

_PLAINTEXT_FIELDS = (
    "height_cm",
    "weight_kg",
    "shoulders_cm",
    "chest_cm",
    "waist_cm",
    "inseam_cm",
    "thigh_cm",
    "hips_cm",
)


class MeasurementsError(Exception):
    """Domain-level measurements failure. Routes translate to 4xx."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code


def _serialize(payload: MeasurementsRequest) -> bytes:
    body = {f: getattr(payload, f) for f in _PLAINTEXT_FIELDS}
    return json.dumps(body, separators=(",", ":"), sort_keys=True).encode("utf-8")


def _deserialize(plaintext: bytes) -> dict:
    return json.loads(plaintext.decode("utf-8"))


def submit(
    db: Session,
    *,
    encryptor: Encryptor,
    user: User,
    payload: MeasurementsRequest,
) -> MeasurementsResponse:
    """Encrypt + upsert the user's measurements; advance onboarding to avatar_reveal."""
    plaintext = _serialize(payload)
    ciphertext = encryptor.encrypt(plaintext, user_id=user.id)

    row = db.scalar(
        select(UserMeasurements).where(UserMeasurements.user_id == user.id)
    )
    from datetime import datetime, timezone

    now = datetime.now(timezone.utc)
    if row is None:
        row = UserMeasurements(
            user_id=user.id,
            ciphertext=ciphertext,
            unit_system=payload.unit_system,
            is_complete=True,
            completed_at=now,
        )
        db.add(row)
    else:
        row.ciphertext = ciphertext
        row.unit_system = payload.unit_system
        row.is_complete = True
        row.completed_at = now

    user.onboarding_last_step = "measurements_step_8"
    db.commit()
    _log.info(
        "measurements.submit",
        user_id=str(user.id),
        unit_system=payload.unit_system,
        ciphertext_bytes=len(ciphertext),
    )
    return MeasurementsResponse(
        **{f: getattr(payload, f) for f in _PLAINTEXT_FIELDS},
        unit_system=payload.unit_system,
        is_complete=True,
    )


# Onboarding measurement-step order. Step ids come from profile_service._NEXT;
# the field-per-step mapping mirrors the mobile resume_route_map.dart.
_STEP_FIELDS = (
    "height_cm",  # measurements_step_1
    "weight_kg",  # measurements_step_2 (optional)
    "chest_cm",  # measurements_step_3
    "waist_cm",  # measurements_step_4
    "hips_cm",  # measurements_step_5
    "inseam_cm",  # measurements_step_6
    "thigh_cm",  # measurements_step_7
    "shoulders_cm",  # measurements_step_8
)


def step_progress(
    db: Session, *, encryptor: Encryptor, user: User
) -> tuple[int, str | None]:
    """(steps completed 0-8, next incomplete step id or None when done).

    Weight is optional, so it never becomes the "next" step — a user with the
    seven required fields is done (next=None) even without weight. Best-effort:
    a decrypt failure reads as no progress rather than failing the caller
    (get_for_user already logged it).
    """
    try:
        result = get_for_user(db, encryptor=encryptor, user=user)
    except MeasurementsError:
        return 0, "measurements_step_1"
    if result is None:
        return 0, "measurements_step_1"
    done = sum(1 for f in _STEP_FIELDS if getattr(result, f) is not None)
    for i, field in enumerate(_STEP_FIELDS, start=1):
        if field != "weight_kg" and getattr(result, field) is None:
            return done, f"measurements_step_{i}"
    return done, None


def get_for_user(
    db: Session, *, encryptor: Encryptor, user: User
) -> MeasurementsResponse | None:
    """Fetch + decrypt the user's measurements, or None if they haven't submitted."""
    row = db.scalar(
        select(UserMeasurements).where(UserMeasurements.user_id == user.id)
    )
    if row is None:
        return None
    try:
        plaintext = encryptor.decrypt(row.ciphertext, user_id=user.id)
    except Exception:
        # AAD mismatch / tag failure / DEK rotation gone wrong. Logged but
        # surfaced as a domain error so the route returns 500 with no detail.
        _log.exception("measurements.decrypt_failed", user_id=str(user.id))
        raise MeasurementsError("decrypt_failed", "Measurements could not be decrypted")
    body = _deserialize(plaintext)
    return MeasurementsResponse(
        **body,
        unit_system=row.unit_system,
        is_complete=row.is_complete,
    )
