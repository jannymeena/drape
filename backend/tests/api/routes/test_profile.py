"""Profile route tests — onboarding step machine + measurements encryption.

Measurements POST encrypts at rest; GET decrypts and round-trips. The test
asserts both the wire-shape contract and that the raw ciphertext on the row
isn't readable (plaintext bytes shouldn't be substring-searchable)."""
from __future__ import annotations

from sqlalchemy import select

from app.db.models import UserMeasurements


# Standard measurement payload reused across tests.
_MEAS = {
    "height_cm": 175.0,
    "weight_kg": 70.0,
    "shoulders_cm": 42.0,
    "chest_cm": 96.0,
    "waist_cm": 78.0,
    "inseam_cm": 80.0,
    "thigh_cm": 56.0,
    "hips_cm": 98.0,
    "unit_system": "metric",
}


# ---------------------------------------------------------------------------
# Onboarding step machine
# ---------------------------------------------------------------------------


def test_onboarding_status_returns_next_step(client, make_user, auth_headers):
    """New user with no profile fields should be routed to shopping_style."""
    user = make_user(
        email="onboard@example.com",
        onboarding_completed=False,
        shopping_style=None,
        age_range=None,
        style_goals=None,
    )
    r = client.get("/api/v1/profile/onboarding-status", headers=auth_headers(user))
    assert r.status_code == 200
    body = r.json()
    assert body["onboarding_completed"] is False
    assert body["next_step"] == "shopping_style_selection"


def test_shopping_style_advances_next_step(authed_client):
    r = authed_client.post(
        "/api/v1/profile/shopping-style", json={"shopping_style": "womens"}
    )
    assert r.status_code == 200
    assert r.json()["next_step"] == "age_range"


def test_age_range_accepts_null_skip(authed_client):
    """Doc 1 says age-range is skippable."""
    r = authed_client.post("/api/v1/profile/age-range", json={"age_range": None})
    assert r.status_code == 200


def test_style_goals_requires_at_least_one(authed_client):
    r = authed_client.post(
        "/api/v1/profile/style-goals", json={"style_goals": []}
    )
    assert r.status_code == 422


def test_style_goals_accepts_valid_list(authed_client):
    r = authed_client.post(
        "/api/v1/profile/style-goals",
        json={"style_goals": ["polished", "maximize_wardrobe"]},
    )
    assert r.status_code == 200


# ---------------------------------------------------------------------------
# Measurements — encrypt + round-trip
# ---------------------------------------------------------------------------


def test_measurements_round_trip_through_encryption(authed_client):
    """POST → GET returns the same values. Encryption is a service concern;
    from the API surface it's just data going in and out."""
    r1 = authed_client.post("/api/v1/profile/measurements", json=_MEAS)
    assert r1.status_code == 200, r1.text
    assert r1.json()["measurements_completed"] is True

    r2 = authed_client.get("/api/v1/profile/measurements")
    assert r2.status_code == 200
    body = r2.json()
    for key, expected in _MEAS.items():
        if key == "unit_system":
            continue
        assert body[key] == expected, f"{key}: got {body[key]}, expected {expected}"


def test_measurements_ciphertext_is_unreadable_on_disk(authed_client, db):
    """The raw row in `user_measurements` must not contain plaintext substrings —
    confirms the encryptor actually ran (not a plaintext fall-through)."""
    authed_client.post("/api/v1/profile/measurements", json=_MEAS)
    row = db.scalar(
        select(UserMeasurements).where(
            UserMeasurements.user_id == authed_client.test_user.id
        )
    )
    assert row is not None
    raw = bytes(row.ciphertext)
    # Plaintext substrings that would appear in the JSON: "175", "height_cm".
    assert b"175" not in raw, "ciphertext contains plaintext height value"
    assert b"height_cm" not in raw, "ciphertext contains plaintext JSON keys"


def test_measurements_get_before_post_returns_404(authed_client):
    r = authed_client.get("/api/v1/profile/measurements")
    assert r.status_code == 404


def test_measurements_rejects_implausible_values(authed_client):
    """Plausibility validation: height 500cm should be rejected at the schema
    boundary (catches imperial-as-metric submission errors)."""
    bad = dict(_MEAS, height_cm=500.0)
    r = authed_client.post("/api/v1/profile/measurements", json=bad)
    assert r.status_code == 422


# ---------------------------------------------------------------------------
# Save progress
# ---------------------------------------------------------------------------


def test_save_progress_persists_last_step(authed_client):
    r = authed_client.post(
        "/api/v1/profile/save-progress",
        json={"last_completed_step": "measurements_step_4"},
    )
    assert r.status_code == 200
