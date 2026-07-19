"""§3.1 hardening — Settings error sanitization, CORS resolution, rate limiter."""
from __future__ import annotations

import pytest
from pydantic import ValidationError

from app.core.config import Settings, sanitize_settings_error
from app.core.rate_limit import SlidingWindowLimiter


# ---------------------------------------------------------------------------
# Settings validation errors must never echo input values
# ---------------------------------------------------------------------------


_SECRET = "postgresql+psycopg2://admin:SuperSecretPw123@db:5432/zoura"


def _boot_error(**overrides) -> ValidationError:
    kwargs = {
        "environment": "tbd",
        "database_url": _SECRET,
        "jwt_secret": "x" * 40,
        "jwt_access_ttl_minutes": "not-a-number",  # forces a field failure
        **overrides,
    }
    with pytest.raises(ValidationError) as exc_info:
        Settings(_env_file=None, **kwargs)  # a real .env must not leak in here
    return exc_info.value


def test_sanitized_settings_error_withholds_values():
    message = sanitize_settings_error(_boot_error())
    assert "jwt_access_ttl_minutes" in message  # field name present
    assert "SuperSecretPw123" not in message  # secrets absent
    assert "not-a-number" not in message  # offending input absent
    assert "values withheld" in message


def test_sanitized_settings_error_lists_missing_required_keys():
    # tbd with nothing configured: our own validator message names the env
    # vars (safe — names only, never values).
    message = sanitize_settings_error(_boot_error(jwt_access_ttl_minutes=60))
    assert "Missing required env vars" in message
    assert "ANTHROPIC_API_KEY" in message


# ---------------------------------------------------------------------------
# CORS origin resolution
# ---------------------------------------------------------------------------


def _dev_settings(**overrides) -> Settings:
    return Settings(
        _env_file=None,
        environment="dev",
        measurement_dek_dev="AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
        **overrides,
    )


def test_cors_defaults_open_in_dev():
    assert _dev_settings().cors_origin_list == ["*"]


def test_cors_explicit_list_parsed():
    s = _dev_settings(cors_allow_origins="https://zoura.style, https://app.zoura.style")
    assert s.cors_origin_list == ["https://zoura.style", "https://app.zoura.style"]


def test_cors_defaults_closed_outside_dev():
    s = _dev_settings()  # cheap: emulate resolution without booting full tbd config
    s.environment = "tbd"
    s.cors_allow_origins = None
    assert s.cors_origin_list == []


def test_auth_rate_limit_floor_applied_outside_dev(monkeypatch):
    monkeypatch.setenv("MEASUREMENT_DEK_DEV", "")
    s = Settings(
        _env_file=None,
        environment="tbd",
        jwt_secret="x" * 40,
        anthropic_api_key="k",
        ses_region="ca-central-1",
        ses_from_address="no-reply@zoura.style",
        kms_key_id="alias/x",
        image_bucket="b",
        google_client_id="g",
        stripe_api_key="sk",
        stripe_webhook_secret="whsec",
        stripe_price_id_pro_monthly="p1",
        stripe_price_id_pro_yearly="p2",
        fcm_credentials_json="{}",
        awin_api_key="a",
        apple_client_id="ac",
    )
    assert s.auth_rate_limit_per_minute == 10


# ---------------------------------------------------------------------------
# SlidingWindowLimiter
# ---------------------------------------------------------------------------


def test_limiter_allows_up_to_limit_then_denies():
    limiter = SlidingWindowLimiter(window_seconds=60)
    assert all(limiter.allow("k", limit=3, now=float(i)) for i in range(3))
    assert limiter.allow("k", limit=3, now=3.0) is False


def test_limiter_window_slides():
    limiter = SlidingWindowLimiter(window_seconds=60)
    for i in range(3):
        limiter.allow("k", limit=3, now=float(i))
    # 61s after the first hit, it has left the window... but denied attempts
    # were also recorded, so use a fresh burst pattern to prove the slide:
    assert limiter.allow("k", limit=3, now=100.0) is True


def test_limiter_denied_hits_still_count():
    limiter = SlidingWindowLimiter(window_seconds=60)
    for i in range(5):
        limiter.allow("k", limit=3, now=float(i))
    # Hammering while throttled must not earn earlier release: at t=61 the
    # hits at t=2,3,4 (two of them denied) are still in the window.
    assert limiter.allow("k", limit=3, now=61.0) is False


def test_limiter_keys_are_isolated():
    limiter = SlidingWindowLimiter(window_seconds=60)
    for i in range(4):
        limiter.allow("a", limit=3, now=float(i))
    assert limiter.allow("b", limit=3, now=4.0) is True
