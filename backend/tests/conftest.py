"""Shared fixtures for the pytest suite.

Design choices:

  * **Real Postgres**, not SQLite. Matches the user's "catch schema drift early"
    preference and lets us exercise JSONB / enum / FK behavior we actually use.
  * **Truncate-between-tests** isolation, not savepoint rollback. Several
    services in this codebase call `db.commit()` directly (wardrobe_service,
    outfit_service, …); savepoint rollback would require routing every commit
    through a fixture-controlled session, which is more magic than it's worth
    for the speed gain. Truncate is ~2× slower per test but always correct.
  * **Provider DI overrides** for AI / weather, so tests don't hit real APIs.
    The same `_CannedAIProvider` and `_StubWeatherProvider` from
    `scripts/verify_phase_6c.py` are reused — keeps the canned response shape
    in one place.
  * **Token minting via `create_access_token`**, not via `/auth/login`. Faster,
    deterministic, and lets tests focus on the route under test rather than
    the auth dance. Tests that *want* to exercise login (test_auth.py) call it
    explicitly.

Test DB URL: defaults to postgresql+psycopg2://admin:password@localhost:5433/drape_test.
Override with TEST_DATABASE_URL env var.
"""
from __future__ import annotations

import os
from datetime import datetime, timezone as dt_timezone
from typing import Iterator

import pytest

# ---------------------------------------------------------------------------
# Critical: redirect DATABASE_URL to the test DB BEFORE app modules import.
# Settings reads .env at import time; if dev DATABASE_URL gets cached, every
# test below will smash dev data. Set this here, in the conftest module body.
# ---------------------------------------------------------------------------

_TEST_DATABASE_URL = os.environ.get(
    "TEST_DATABASE_URL",
    "postgresql+psycopg2://admin:password@localhost:5433/drape_test",
)
os.environ["DATABASE_URL"] = _TEST_DATABASE_URL

# Settings also requires MEASUREMENT_DEK_DEV in dev. Honor what's already in env
# (from .env via pydantic-settings); inject a known-good default if missing so
# tests don't fail on a fresh shell.
if not os.environ.get("MEASUREMENT_DEK_DEV"):
    # 32 zero bytes, base64-encoded — only used in tests, never persisted to
    # anything that escapes this DB.
    os.environ["MEASUREMENT_DEK_DEV"] = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

# Now safe to import the app stack.
from fastapi.testclient import TestClient  # noqa: E402
from sqlalchemy import create_engine, text  # noqa: E402
from sqlalchemy.orm import Session, sessionmaker  # noqa: E402

from app.core.providers import providers  # noqa: E402
from app.core.security import create_access_token  # noqa: E402
from app.db.base import Base  # noqa: E402
from app.db.models import AuthMethod, User  # noqa: E402
import app.db.models  # noqa: E402,F401  -- register every model with Base.metadata
from app.main import app  # noqa: E402
from app.schemas.user import Role  # noqa: E402
from app.services.providers.hash.bcrypt import BcryptPasswordHasher  # noqa: E402

# Reuse the canned providers built for verify_phase_6c.py — single source of
# truth for the mock response shapes.
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from scripts.verify_phase_6c import _CannedAIProvider, _StubWeatherProvider  # noqa: E402


# ---------------------------------------------------------------------------
# Engine / session
# ---------------------------------------------------------------------------


@pytest.fixture(scope="session")
def engine():
    """Session-scoped engine pointed at the test DB. Refuses to run if the URL
    doesn't look like a test DB — a small guard against accidental dev wipe."""
    url = os.environ["DATABASE_URL"]
    if "test" not in url:
        raise RuntimeError(
            f"refusing to run tests: DATABASE_URL={url!r} doesn't look like a test DB. "
            "Set TEST_DATABASE_URL or rename the test database."
        )
    return create_engine(url, pool_pre_ping=True, future=True)


@pytest.fixture(scope="session")
def session_factory(engine):
    return sessionmaker(bind=engine, autoflush=False, autocommit=False, future=True)


@pytest.fixture
def db(session_factory) -> Iterator[Session]:
    """A fresh session per test. Closed in teardown; truncate is handled by the
    `_truncate_after_test` autouse fixture below."""
    session = session_factory()
    try:
        yield session
    finally:
        session.close()


@pytest.fixture(scope="session", autouse=True)
def _ensure_starter_templates_seeded(engine):
    """Make sure `starter_wardrobe_templates` is populated before any test runs.
    Templates are migration-seed data; if a prior test run (before
    `_truncate_after_test` was taught to preserve them) emptied the table,
    re-seed from JSON here. No-op when the table is already populated."""
    import json
    import uuid
    from pathlib import Path

    with engine.begin() as conn:
        count = conn.execute(text("SELECT count(*) FROM starter_wardrobe_templates")).scalar()
        if count and count > 0:
            return
        json_path = Path(__file__).resolve().parent.parent / "data" / "starter_wardrobe_templates.json"
        templates = json.loads(json_path.read_text())
        for t in templates:
            conn.execute(
                text(
                    """
                    INSERT INTO starter_wardrobe_templates
                        (id, template_id, name, gender, age_range, style_profile,
                         total_items, items)
                    VALUES
                        (:id, :template_id, :name, :gender, :age_range, :style_profile,
                         :total_items, CAST(:items AS jsonb))
                    """
                ),
                {
                    "id": str(uuid.uuid4()),
                    "template_id": t["template_id"],
                    "name": t["name"],
                    "gender": t.get("gender"),
                    "age_range": t.get("age_range"),
                    "style_profile": t.get("style_profile"),
                    "total_items": len(t["items"]),
                    "items": json.dumps(t["items"]),
                },
            )


@pytest.fixture(autouse=True)
def _truncate_after_test(engine):
    """Wipe per-test state after each test. Preserves seed data:
      * `alembic_version` — Alembic's bookkeeping row.
      * `starter_wardrobe_templates` — seeded by the migration once at init;
        re-seeding per test would cost ~50ms with no benefit (templates are
        stable reference data, not per-user state).

    CASCADE handles FK ordering; RESTART IDENTITY resets sequences.
    """
    yield
    preserved = {"alembic_version", "starter_wardrobe_templates"}
    tables = [t.name for t in Base.metadata.sorted_tables if t.name not in preserved]
    if not tables:
        return
    quoted = ", ".join(f'"{name}"' for name in tables)
    with engine.begin() as conn:
        conn.execute(text(f"TRUNCATE TABLE {quoted} RESTART IDENTITY CASCADE"))


# ---------------------------------------------------------------------------
# Provider overrides + TestClient
# ---------------------------------------------------------------------------


@pytest.fixture
def canned_ai() -> _CannedAIProvider:
    return _CannedAIProvider()


@pytest.fixture
def stub_weather() -> _StubWeatherProvider:
    return _StubWeatherProvider()


@pytest.fixture
def image_storage(tmp_path):
    """Per-test LocalFsStorage rooted in pytest's tmp_path so uploads don't
    leak into the dev `./uploads/` directory. tmp_path is auto-cleaned by pytest."""
    from app.services.providers.image.local_fs import LocalFsStorage

    return LocalFsStorage(root=tmp_path / "images", base_url="http://testserver/images")


@pytest.fixture
def client(canned_ai, stub_weather, image_storage, db) -> Iterator[TestClient]:
    """A TestClient with canned AI + weather + a DB session bound to the test DB.

    `db` is included so its dependency override pulls the same session — meaning
    a test can read state via `db` and the route sees that state via DI.
    """
    from app.api.dependencies.providers import (
        get_ai_provider,
        get_image_storage,
        get_weather_provider,
    )
    from app.db.session import get_db

    app.dependency_overrides[get_ai_provider] = lambda: canned_ai
    app.dependency_overrides[get_weather_provider] = lambda: stub_weather
    app.dependency_overrides[get_image_storage] = lambda: image_storage
    app.dependency_overrides[get_db] = lambda: db

    # Also patch the global providers container so non-Depends call sites pick
    # up the canned providers (e.g. background tasks).
    original_ai, original_weather, original_image = (
        providers.ai,
        providers.weather,
        providers.image_storage,
    )
    providers.ai = canned_ai
    providers.weather = stub_weather
    providers.image_storage = image_storage

    try:
        with TestClient(app) as c:
            yield c
    finally:
        app.dependency_overrides.clear()
        providers.ai = original_ai
        providers.weather = original_weather
        providers.image_storage = original_image


# ---------------------------------------------------------------------------
# User + auth factories
# ---------------------------------------------------------------------------


@pytest.fixture
def make_user(db):
    """Factory: returns a callable that creates a User row with sensible defaults."""

    def _make(
        *,
        email: str = "test@example.com",
        password: str = "password1",
        display_name: str = "Test User",
        role: Role = Role.customer,
        tier: str = "free",
        onboarding_completed: bool = True,
        shopping_style: str | None = "womens",
        age_range: str | None = "25-34",
        style_goals: list[str] | None = None,
        timezone: str | None = "America/Toronto",
        location: str | None = "Toronto, ON",
    ) -> User:
        hasher = BcryptPasswordHasher()
        user = User(
            email=email,
            display_name=display_name,
            role=role,
            password_hash=hasher.hash(password),
            auth_method=AuthMethod.email,
            agreed_to_terms=True,
            agreed_to_privacy=True,
            terms_agreed_at=datetime.now(dt_timezone.utc),
            shopping_style=shopping_style,
            age_range=age_range,
            style_goals=style_goals or ["polished"],
            timezone=timezone,
            location=location,
            onboarding_completed=onboarding_completed,
            subscription_tier=tier,
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        return user

    return _make


@pytest.fixture
def auth_headers():
    """Factory: mints a Bearer-header dict for a given user without going
    through /auth/login. Faster than logging in for tests not exercising auth."""

    def _headers(user: User) -> dict[str, str]:
        token = create_access_token(user_id=user.id, role=user.role.value)
        return {"Authorization": f"Bearer {token}"}

    return _headers


@pytest.fixture
def authed_client(client, make_user, auth_headers) -> TestClient:
    """A pre-authenticated TestClient with a default test user. Use when the
    test doesn't care about the user identity — just needs to be authed."""
    user = make_user()
    client.headers.update(auth_headers(user))
    # Stash the user on the client for tests that want it.
    client.test_user = user  # type: ignore[attr-defined]
    return client
