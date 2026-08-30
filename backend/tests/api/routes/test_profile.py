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
    """New user with no profile fields starts at blueprint step 1."""
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
    assert body["next_step"] == "style_blueprint_1"
    # No measurements yet — resume-banner progress starts at zero.
    assert body["measurement_steps_completed"] == 0
    assert body["next_incomplete_step"] == "measurements_step_1"


def test_onboarding_status_reports_measurement_progress(authed_client):
    """After submit, the status carries the resume-banner progress fields:
    all 8 fields saved -> 8 done, nothing left."""
    r = authed_client.post("/api/v1/profile/measurements", json=_MEAS)
    assert r.status_code == 200, r.text

    r = authed_client.get("/api/v1/profile/onboarding-status")
    assert r.status_code == 200
    body = r.json()
    assert body["measurement_steps_completed"] == 8
    assert body["next_incomplete_step"] is None


def test_onboarding_status_weight_optional_counts_seven(authed_client):
    """Weight is optional: 7 required fields -> 7 done but still complete
    (next_incomplete_step is None, never routes to the weight step)."""
    payload = {k: v for k, v in _MEAS.items() if k != "weight_kg"}
    r = authed_client.post("/api/v1/profile/measurements", json=payload)
    assert r.status_code == 200, r.text

    r = authed_client.get("/api/v1/profile/onboarding-status")
    body = r.json()
    assert body["measurement_steps_completed"] == 7
    assert body["next_incomplete_step"] is None


# ---------------------------------------------------------------------------
# Style Blueprint — the 7-step onboarding chain
# ---------------------------------------------------------------------------

# One valid body per blueprint step, in flow order: (path suffix, payload).
_BLUEPRINT_STEPS = [
    ("identity", {"shopping_style": "womens", "age_range": "25-34"}),
    ("fit", {"body_shape": "hourglass", "fit_tops": "regular", "fit_bottoms": "relaxed"}),
    ("aesthetics", {"style_aesthetics": ["minimalist", "romantic"]}),
    ("color", {"undertone": "warm", "color_palettes": ["earth_tones", "neutrals"]}),
    (
        "lifestyle",
        {
            "occupation": "Marketing",
            "dress_code": "business_casual",
            "impression_goal": "both",
        },
    ),
    (
        "habits",
        {
            "shopping_feeling": "confident",
            "accessories": "minimal",
            "brand_tier": "premium",
        },
    ),
    (
        "goals",
        {
            "three_month_feeling": "confident_anywhere",
            "style_goals": ["polished", "maximize_wardrobe"],
        },
    ),
]


def _walk_blueprint(client, through: int = 7) -> str:
    """POST the first [through] blueprint steps in order; returns the last
    `next_step`."""
    nxt = ""
    for suffix, payload in _BLUEPRINT_STEPS[:through]:
        r = client.post(f"/api/v1/profile/style-blueprint/{suffix}", json=payload)
        assert r.status_code == 200, f"{suffix}: {r.text}"
        nxt = r.json()["next_step"]
    return nxt


def test_blueprint_steps_chain_in_order(authed_client):
    """Each step advances to the next; step 7 hands off to the reveal."""
    for i, (suffix, payload) in enumerate(_BLUEPRINT_STEPS, start=1):
        r = authed_client.post(
            f"/api/v1/profile/style-blueprint/{suffix}", json=payload
        )
        assert r.status_code == 200, r.text
        expected = "style_blueprint_reveal" if i == 7 else f"style_blueprint_{i + 1}"
        assert r.json()["next_step"] == expected


def test_blueprint_complete_lands_on_dashboard(authed_client):
    _walk_blueprint(authed_client)
    r = authed_client.post("/api/v1/profile/style-blueprint/complete")
    assert r.status_code == 200
    assert r.json()["next_step"] == "today_dashboard"


def test_blueprint_answers_accumulate_in_style_profile(authed_client):
    """Each step merges into the same JSONB blob rather than replacing it."""
    _walk_blueprint(authed_client)

    body = authed_client.get("/api/v1/profile/onboarding-status").json()
    profile = body["style_profile"]
    assert profile["body_shape"] == "hourglass"
    assert profile["style_aesthetics"] == ["minimalist", "romantic"]
    assert profile["undertone"] == "warm"
    assert profile["occupation"] == "Marketing"
    assert profile["brand_tier"] == "premium"
    assert profile["three_month_feeling"] == "confident_anywhere"
    # Step 1 and 7 still write their dedicated columns.
    assert body["shopping_style"] == "womens"
    assert body["age_range"] == "25-34"
    assert body["style_goals"] == ["polished", "maximize_wardrobe"]


def test_blueprint_identity_accepts_null_age_skip(authed_client):
    """Doc 1 says the age question is skippable."""
    r = authed_client.post(
        "/api/v1/profile/style-blueprint/identity",
        json={"shopping_style": "mens", "age_range": None},
    )
    assert r.status_code == 200
    assert r.json()["next_step"] == "style_blueprint_2"


def test_blueprint_lifestyle_allows_no_dress_code(authed_client):
    """`dress_code` is skipped automatically when the user isn't working."""
    r = authed_client.post(
        "/api/v1/profile/style-blueprint/lifestyle",
        json={"occupation": None, "dress_code": None, "impression_goal": "content"},
    )
    assert r.status_code == 200


def test_blueprint_goals_requires_at_least_one(authed_client):
    r = authed_client.post(
        "/api/v1/profile/style-blueprint/goals",
        json={"three_month_feeling": "found_my_look", "style_goals": []},
    )
    assert r.status_code == 422


def test_blueprint_rejects_unknown_enum_value(authed_client):
    r = authed_client.post(
        "/api/v1/profile/style-blueprint/fit",
        json={"body_shape": "pyramid", "fit_tops": "regular", "fit_bottoms": "relaxed"},
    )
    assert r.status_code == 422


def test_legacy_step_pointer_restarts_the_blueprint(client, make_user, auth_headers):
    """A session paused mid-way through the old 15-screen flow resumes at
    step 1 rather than stranding on a screen that no longer chains."""
    user = make_user(email="legacy@example.com", onboarding_completed=False)
    r = client.post(
        "/api/v1/profile/save-progress",
        json={"last_completed_step": "measurements_step_4"},
        headers=auth_headers(user),
    )
    assert r.status_code == 200
    assert r.json()["next_step"] == "style_blueprint_1"


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


# ---------------------------------------------------------------------------
# Avatar upload
# ---------------------------------------------------------------------------

_TINY_PNG = (
    b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01"
    b"\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\rIDATx\x9cc\xfc\xcf"
    b"\xc0\x00\x00\x00\x05\x00\x01\xa5\x86\x82\x16\x00\x00\x00\x00IEND\xaeB`\x82"
)


def test_avatar_upload_sets_url_and_surfaces_on_me(authed_client):
    r = authed_client.post(
        "/api/v1/profile/avatar/upload",
        files={"file": ("me.png", _TINY_PNG, "image/png")},
    )
    assert r.status_code == 200, r.text
    url = r.json()["avatar_url"]
    assert url and url.endswith(".png")
    # Round-trips on /users/me (proves it persisted to the profile row).
    me = authed_client.get("/api/v1/users/me")
    assert me.json()["avatar_url"] == url


def test_avatar_upload_rejects_unsupported_type(authed_client):
    r = authed_client.post(
        "/api/v1/profile/avatar/upload",
        files={"file": ("me.gif", b"GIF89a", "image/gif")},
    )
    assert r.status_code == 415
