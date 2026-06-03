"""Phase 8c/8d/8e — settings, support tickets, account export + self-delete."""
from __future__ import annotations

from app.db.models import SupportTicket, User


# ---------------------------------------------------------------------------
# Settings
# ---------------------------------------------------------------------------


def test_settings_get_returns_defaults(client, make_user, auth_headers):
    user = make_user(email="s@example.com")
    r = client.get("/api/v1/settings", headers=auth_headers(user))
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["push_enabled"] is True
    assert body["theme"] == "light"
    assert body["unit_system"] == "metric"


def test_settings_patch_persists(client, make_user, auth_headers):
    user = make_user(email="s2@example.com")
    r = client.patch(
        "/api/v1/settings",
        headers=auth_headers(user),
        json={"theme": "dark", "push_enabled": False, "unit_system": "imperial"},
    )
    assert r.status_code == 200, r.text
    assert r.json()["theme"] == "dark"
    # Re-read to prove persistence.
    again = client.get("/api/v1/settings", headers=auth_headers(user))
    assert again.json()["push_enabled"] is False
    assert again.json()["unit_system"] == "imperial"


def test_settings_patch_rejects_bad_theme(client, make_user, auth_headers):
    user = make_user(email="s3@example.com")
    r = client.patch(
        "/api/v1/settings", headers=auth_headers(user), json={"theme": "neon"}
    )
    assert r.status_code == 422


# ---------------------------------------------------------------------------
# Support
# ---------------------------------------------------------------------------


def test_support_endpoints_create_tickets(client, db, make_user, auth_headers):
    user = make_user(email="sup@example.com")
    for path, kind in [
        ("/api/v1/support/contact", "contact"),
        ("/api/v1/support/feature-request", "feature_request"),
        ("/api/v1/support/bug-report", "bug_report"),
    ]:
        r = client.post(
            path,
            headers=auth_headers(user),
            json={"subject": "Hi", "message": "Some text"},
        )
        assert r.status_code == 201, r.text
        assert r.json()["kind"] == kind
    kinds = {
        t.kind
        for t in db.query(SupportTicket).filter_by(user_id=user.id).all()
    }
    assert kinds == {"contact", "feature_request", "bug_report"}


def test_support_rejects_empty_message(client, make_user, auth_headers):
    user = make_user(email="sup2@example.com")
    r = client.post(
        "/api/v1/support/contact", headers=auth_headers(user), json={"message": ""}
    )
    assert r.status_code == 422


# ---------------------------------------------------------------------------
# Account export + delete
# ---------------------------------------------------------------------------


def test_account_export_returns_snapshot(client, make_user, auth_headers):
    user = make_user(email="exp@example.com", display_name="Exporter")
    r = client.get("/api/v1/account/export", headers=auth_headers(user))
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["account"]["email"] == "exp@example.com"
    assert "settings" in body and "wardrobe" in body and "stats" in body


def test_account_delete_removes_user(client, db, make_user, auth_headers):
    user = make_user(email="del@example.com")
    uid = user.id
    r = client.delete("/api/v1/account", headers=auth_headers(user))
    assert r.status_code == 204, r.text
    assert db.get(User, uid) is None
