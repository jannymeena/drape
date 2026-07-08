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
    # §5.5.1 consent state is part of the PIPEDA access-request snapshot.
    assert body["account"]["use_measurements_for_fit"] is False
    assert body["account"]["measurements_fit_consent_at"] is None


def test_account_delete_removes_user(client, db, make_user, auth_headers):
    user = make_user(email="del@example.com")
    uid = user.id
    r = client.delete("/api/v1/account", headers=auth_headers(user))
    assert r.status_code == 204, r.text
    assert db.get(User, uid) is None


# ---------------------------------------------------------------------------
# Feature-request votes (2.1)
# ---------------------------------------------------------------------------


def _make_feature(client, message="Dark mode please"):
    r = client.post("/api/v1/support/feature-request", json={"message": message})
    assert r.status_code == 201, r.text
    return r.json()["id"]


def test_feature_request_vote_and_list(authed_client):
    tid = _make_feature(authed_client)

    r = authed_client.post(
        f"/api/v1/support/feature-requests/{tid}/vote", json={"vote": 1}
    )
    assert r.status_code == 200, r.text
    assert r.json() == {"ticket_id": tid, "score": 1, "my_vote": 1}

    r = authed_client.get("/api/v1/support/feature-requests")
    assert r.status_code == 200
    items = r.json()["items"]
    mine = next(i for i in items if i["id"] == tid)
    assert mine["score"] == 1
    assert mine["my_vote"] == 1


def test_feature_request_revote_and_clear(authed_client):
    tid = _make_feature(authed_client)
    vote = lambda v: authed_client.post(  # noqa: E731
        f"/api/v1/support/feature-requests/{tid}/vote", json={"vote": v}
    ).json()

    assert vote(1)["score"] == 1
    # Flipping the vote replaces it (not additive).
    assert vote(-1)["score"] == -1
    # 0 clears.
    cleared = vote(0)
    assert cleared["score"] == 0
    assert cleared["my_vote"] == 0


def test_feature_request_vote_404_for_non_feature_ticket(authed_client):
    r = authed_client.post("/api/v1/support/bug-report", json={"message": "boom"})
    bug_id = r.json()["id"]
    r = authed_client.post(
        f"/api/v1/support/feature-requests/{bug_id}/vote", json={"vote": 1}
    )
    assert r.status_code == 404


def test_feature_request_list_is_public_across_users(
    client, authed_client, make_user, auth_headers
):
    """The board shows other users' requests; my_vote is per-caller."""
    tid = _make_feature(authed_client)
    authed_client.post(
        f"/api/v1/support/feature-requests/{tid}/vote", json={"vote": 1}
    )

    other = make_user(email="voter@example.com")
    r = client.get(
        "/api/v1/support/feature-requests", headers=auth_headers(other)
    )
    items = r.json()["items"]
    row = next(i for i in items if i["id"] == tid)
    assert row["score"] == 1  # sees the community score
    assert row["my_vote"] == 0  # but hasn't voted themselves
