"""RequestIdMiddleware — one structured request.completed line per request,
carrying request_id always and user_id once the auth dependency has run.
The middleware must be pure ASGI for that: BaseHTTPMiddleware would isolate
the dependency's contextvars in a child task (regression guard for the
'no reference it's the same user' log gap, 2026-07-18)."""
from __future__ import annotations

from contextlib import contextmanager

import structlog
from structlog.contextvars import merge_contextvars
from structlog.testing import LogCapture


@contextmanager
def _capture_with_contextvars():
    """structlog.testing.capture_logs drops the merge_contextvars processor,
    so bound request_id/user_id would never reach the captured entries; this
    variant keeps the merge in front of the capture."""
    capture = LogCapture()
    previous = structlog.get_config()["processors"]
    structlog.configure(processors=[merge_contextvars, capture])
    try:
        yield capture.entries
    finally:
        structlog.configure(processors=previous)


def test_request_completed_carries_request_and_user_ids(authed_client):
    with _capture_with_contextvars() as logs:
        r = authed_client.get("/api/v1/users/me")
    assert r.status_code == 200

    completed = [e for e in logs if e["event"] == "request.completed"]
    assert len(completed) == 1
    entry = completed[0]
    assert entry["method"] == "GET"
    assert entry["path"] == "/api/v1/users/me"
    assert entry["status"] == 200
    assert entry["duration_ms"] >= 0
    # The same id the client got back — logs and support tickets correlate.
    assert entry["request_id"] == r.headers["X-Request-ID"]
    # The auth dependency bound the caller; the middleware's event sees it.
    assert entry["user_id"] == str(authed_client.test_user.id)


def test_unauthenticated_request_completes_without_user_id(client):
    with _capture_with_contextvars() as logs:
        r = client.get("/api/v1/health")
    assert r.status_code == 200
    completed = [e for e in logs if e["event"] == "request.completed"]
    assert len(completed) == 1
    assert "request_id" in completed[0]
    assert "user_id" not in completed[0]


def test_failed_auth_still_completes_with_status(client):
    with _capture_with_contextvars() as logs:
        r = client.get("/api/v1/users/me")  # no bearer token
    assert r.status_code == 401
    completed = [e for e in logs if e["event"] == "request.completed"]
    assert len(completed) == 1
    assert completed[0]["status"] == 401
    assert "user_id" not in completed[0]
