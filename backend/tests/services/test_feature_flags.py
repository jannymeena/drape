"""DISABLED_FEATURES — per-feature switches (apple_login, google_login).

Covers the whole flag matrix: disabled features skip startup key validation,
enabled ones still fail fast when their key is missing, unknown names refuse
to boot, and the provider container wires only the enabled sides.
"""
from __future__ import annotations

import asyncio

import pytest
from pydantic import ValidationError

from app.core.config import Settings
from app.core.providers import Providers
from app.services.providers.oauth.base import OAuthVerificationError


def _tbd_settings(**overrides) -> Settings:
    """A fully-provisioned tbd Settings; tests knock out the piece under test.

    `_env_file=None` + explicit kwargs keep the real dev .env and process env
    out of the picture (init kwargs take precedence in pydantic-settings).
    """
    base: dict = dict(
        _env_file=None,
        environment="tbd",
        jwt_secret="x" * 64,
        anthropic_api_key="test-key",
        ses_region="ca-central-1",
        ses_from_address="no-reply@drape.app",
        kms_key_id="arn:aws:kms:ca-central-1:000000000000:key/test",
        image_bucket="drape-test-images",
        apple_client_id="com.drape.app",
        google_client_id="ios.apps.googleusercontent.com",
    )
    base.update(overrides)
    return Settings(**base)


# ---------------------------------------------------------------------------
# Startup validation
# ---------------------------------------------------------------------------


def test_tbd_boots_without_oauth_keys_when_both_disabled():
    s = _tbd_settings(
        disabled_features="apple_login,google_login",
        apple_client_id=None,
        google_client_id=None,
    )
    assert not s.feature_enabled("apple_login")
    assert not s.feature_enabled("google_login")


def test_tbd_still_requires_client_id_when_enabled():
    with pytest.raises(ValidationError, match="APPLE_CLIENT_ID"):
        _tbd_settings(apple_client_id=None)
    with pytest.raises(ValidationError, match="GOOGLE_CLIENT_ID"):
        _tbd_settings(google_client_id=None)


def test_flags_are_independent_per_provider():
    # Apple off (no key needed), Google on (key still enforced).
    s = _tbd_settings(disabled_features="apple_login", apple_client_id=None)
    assert not s.feature_enabled("apple_login")
    assert s.feature_enabled("google_login")
    with pytest.raises(ValidationError, match="GOOGLE_CLIENT_ID"):
        _tbd_settings(
            disabled_features="apple_login", apple_client_id=None, google_client_id=None
        )


def test_unknown_feature_name_refuses_to_boot():
    with pytest.raises(ValidationError, match="Unknown feature"):
        _tbd_settings(disabled_features="aple_login")  # typo guard


def test_whitespace_and_trailing_commas_tolerated():
    s = _tbd_settings(disabled_features=" apple_login , ", apple_client_id=None)
    assert not s.feature_enabled("apple_login")


def test_default_is_everything_enabled():
    s = _tbd_settings()
    assert s.feature_enabled("apple_login")
    assert s.feature_enabled("google_login")


# ---------------------------------------------------------------------------
# Provider wiring
# ---------------------------------------------------------------------------


def test_both_disabled_wires_no_verifier():
    s = _tbd_settings(
        disabled_features="apple_login,google_login",
        apple_client_id=None,
        google_client_id=None,
    )
    assert Providers._build_oauth(s) is None


def test_one_disabled_side_answers_unavailable_other_stays_wired():
    s = _tbd_settings(disabled_features="apple_login", apple_client_id=None)
    verifier = Providers._build_oauth(s)
    assert verifier is not None
    with pytest.raises(OAuthVerificationError) as exc_info:
        asyncio.run(verifier.verify_apple("any-token"))
    assert exc_info.value.code == "oauth_unavailable"
    # Google side kept its audience — a bogus token fails verification,
    # not availability.
    with pytest.raises(OAuthVerificationError) as exc_info:
        asyncio.run(verifier.verify_google("not-a-jwt"))
    assert exc_info.value.code == "oauth_invalid_token"


def test_dev_never_wires_oauth_regardless_of_flags():
    s = Settings(_env_file=None, environment="dev", measurement_dek_dev="ZGV2LWtleQ==")
    assert Providers._build_oauth(s) is None
