"""Tier 1.1 / §5.5.1 — measurements → consent-gated derived fit profile.

The privacy contract under test: raw centimetres never reach a prompt; only
coarse categorical strings do, and only after the separate opt-in. Covers the
derivation matrix, the prompt block, the consent gate, the consent timestamp,
the export surface, and the end-to-end path into the outfit system prompt.
"""
from __future__ import annotations

import re

import pytest

from app.core.config import settings
from app.services import fit_profile, measurements_service, outfit_service, user_service
from app.schemas.measurements import MeasurementsRequest
from app.schemas.user import UserUpdate
from app.services.providers.crypto.local_aes import LocalAesEncryptor

_MEAS = dict(
    height_cm=175.0,
    weight_kg=70.0,
    shoulders_cm=44.0,
    chest_cm=96.0,
    waist_cm=78.0,
    inseam_cm=80.0,
    thigh_cm=56.0,
    hips_cm=98.0,
    unit_system="metric",
)


def _encryptor() -> LocalAesEncryptor:
    return LocalAesEncryptor(settings.measurement_dek_dev)


# ---------------------------------------------------------------------------
# Derivation matrix
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "chest,waist,hips,expected",
    [
        (100, 70, 102, "hourglass"),  # balanced chest/hips, defined waist
        (110, 85, 95, "inverted_triangle"),  # chest clearly wider
        (90, 75, 105, "triangle"),  # hips clearly wider
        (95, 80, 96, "rectangle"),  # balanced, waist not defined
    ],
)
def test_body_shape_matrix(chest, waist, hips, expected):
    profile = fit_profile.derive({"chest_cm": chest, "waist_cm": waist, "hips_cm": hips})
    assert profile["body_shape"] == expected


@pytest.mark.parametrize(
    "height,expected",
    [(150, "petite"), (159.9, "petite"), (160, "average"), (178, "average"), (185, "tall")],
)
def test_height_bands(height, expected):
    assert fit_profile.derive({"height_cm": height})["height_band"] == expected


@pytest.mark.parametrize(
    "shoulders,height,expected",
    [(40, 175, "slim"), (44, 175, "regular"), (48, 175, "broad")],
)
def test_build_from_shoulders_and_height(shoulders, height, expected):
    profile = fit_profile.derive({"shoulders_cm": shoulders, "height_cm": height})
    assert profile["build"] == expected


def test_partial_measurements_derive_partially():
    assert fit_profile.derive({"height_cm": 170}) == {"height_band": "average"}
    assert fit_profile.derive({}) is None
    assert fit_profile.derive({"chest_cm": 96}) is None  # shape needs all three


def test_derived_profile_contains_no_numbers():
    profile = fit_profile.derive(
        {k: v for k, v in _MEAS.items() if k != "unit_system"}
    )
    assert profile is not None
    for value in profile.values():
        assert isinstance(value, str)
        assert not re.search(r"\d", value)


# ---------------------------------------------------------------------------
# Prompt block
# ---------------------------------------------------------------------------


def test_prompt_block_renders_coarse_categories_only():
    block = fit_profile.to_prompt_block(
        {"height_band": "tall", "build": "broad", "body_shape": "inverted_triangle"}
    )
    assert block == (
        "Fit: tall, broad build, inverted triangle shape — "
        "favor cuts and silhouettes that flatter this.\n"
    )
    assert not re.search(r"\d", block)  # exact cm never leave our infra


def test_prompt_block_empty_without_profile():
    assert fit_profile.to_prompt_block(None) == ""
    assert fit_profile.to_prompt_block({}) == ""


# ---------------------------------------------------------------------------
# Submit derives; consent gates
# ---------------------------------------------------------------------------


def test_submit_stores_derived_profile(db, make_user):
    user = make_user(email="fit@example.com")
    measurements_service.submit(
        db, encryptor=_encryptor(), user=user, payload=MeasurementsRequest(**_MEAS)
    )
    # Without consent: stored, but the gate returns nothing.
    assert measurements_service.fit_profile_for_user(db, user=user) is None

    user.use_measurements_for_fit = True
    db.commit()
    profile = measurements_service.fit_profile_for_user(db, user=user)
    assert profile == {
        "body_shape": "rectangle",
        "height_band": "average",
        "build": "regular",
    }


def test_consent_toggle_sets_and_clears_timestamp(db, make_user):
    user = make_user(email="consent@example.com")
    assert user.measurements_fit_consent_at is None

    user_service.update_user(db, user, UserUpdate(use_measurements_for_fit=True))
    assert user.use_measurements_for_fit is True
    granted_at = user.measurements_fit_consent_at
    assert granted_at is not None

    # Re-affirming does not move the original consent timestamp.
    user_service.update_user(db, user, UserUpdate(use_measurements_for_fit=True))
    assert user.measurements_fit_consent_at == granted_at

    user_service.update_user(db, user, UserUpdate(use_measurements_for_fit=False))
    assert user.use_measurements_for_fit is False
    assert user.measurements_fit_consent_at is None


def test_outfit_system_prompt_includes_fit_only_via_gate(db, make_user):
    user = make_user(email="fitprompt@example.com")
    measurements_service.submit(
        db, encryptor=_encryptor(), user=user, payload=MeasurementsRequest(**_MEAS)
    )

    def _system() -> str:
        return outfit_service._build_system_context(
            items=[],
            style_goals=None,
            using_starter_wardrobe=False,
            fit=measurements_service.fit_profile_for_user(db, user=user),
        )

    assert "Fit:" not in _system()  # consent off → nothing enters the prompt

    user.use_measurements_for_fit = True
    db.commit()
    system = _system()
    assert "Fit: average, regular build, rectangle shape" in system
    # The raw numbers must not appear anywhere in the prompt.
    for cm in ("175", "96", "78", "98", "44"):
        assert cm not in system
