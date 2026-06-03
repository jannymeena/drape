"""Users route tests — admin list, per-user GET/PATCH (self vs admin),
DELETE (admin only)."""
from __future__ import annotations

from app.schemas.user import Role


def test_get_self_returns_200(client, make_user, auth_headers):
    user = make_user(email="self@example.com")
    r = client.get(f"/api/v1/users/{user.id}", headers=auth_headers(user))
    assert r.status_code == 200
    assert r.json()["email"] == "self@example.com"


def test_get_other_user_as_customer_returns_403(client, make_user, auth_headers):
    """Self-or-admin rule: a customer can't read someone else's row."""
    alice = make_user(email="alice@example.com")
    bob = make_user(email="bob@example.com")
    r = client.get(f"/api/v1/users/{alice.id}", headers=auth_headers(bob))
    assert r.status_code == 403


def test_get_other_user_as_admin_returns_200(client, make_user, auth_headers):
    alice = make_user(email="alice@example.com")
    admin = make_user(email="admin@example.com", role=Role.admin)
    r = client.get(f"/api/v1/users/{alice.id}", headers=auth_headers(admin))
    assert r.status_code == 200
    assert r.json()["email"] == "alice@example.com"


def test_list_users_as_admin_returns_all(client, make_user, auth_headers):
    admin = make_user(email="admin@example.com", role=Role.admin)
    make_user(email="alice@example.com")
    make_user(email="bob@example.com")
    r = client.get("/api/v1/users", headers=auth_headers(admin))
    assert r.status_code == 200
    emails = {u["email"] for u in r.json()}
    assert {"admin@example.com", "alice@example.com", "bob@example.com"} <= emails


def test_list_users_as_customer_returns_403(client, make_user, auth_headers):
    customer = make_user(email="cust@example.com")
    r = client.get("/api/v1/users", headers=auth_headers(customer))
    assert r.status_code == 403


def test_patch_self_updates_display_name(client, make_user, auth_headers):
    user = make_user(email="patch@example.com", display_name="Old Name")
    r = client.patch(
        f"/api/v1/users/{user.id}",
        headers=auth_headers(user),
        json={"display_name": "New Name"},
    )
    assert r.status_code == 200
    assert r.json()["display_name"] == "New Name"


def test_patch_email_to_existing_returns_409(client, make_user, auth_headers):
    make_user(email="taken@example.com")
    user = make_user(email="mine@example.com")
    r = client.patch(
        f"/api/v1/users/{user.id}",
        headers=auth_headers(user),
        json={"email": "taken@example.com"},
    )
    assert r.status_code == 409, r.text
    assert r.json()["detail"]["code"] == "email_taken"


def test_patch_profile_fields_persist(client, make_user, auth_headers):
    user = make_user(email="prof@example.com")
    r = client.patch(
        f"/api/v1/users/{user.id}",
        headers=auth_headers(user),
        json={"gender": "Female", "phone": "+1 555", "community_share_avatar": True},
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["gender"] == "Female"
    assert body["community_share_avatar"] is True


def test_patch_other_user_as_customer_returns_403(client, make_user, auth_headers):
    alice = make_user(email="alice@example.com")
    bob = make_user(email="bob@example.com")
    r = client.patch(
        f"/api/v1/users/{alice.id}",
        headers=auth_headers(bob),
        json={"display_name": "Hacked"},
    )
    assert r.status_code == 403


def test_delete_user_as_admin_returns_204(client, make_user, auth_headers):
    alice = make_user(email="alice@example.com")
    admin = make_user(email="admin@example.com", role=Role.admin)
    r = client.delete(f"/api/v1/users/{alice.id}", headers=auth_headers(admin))
    assert r.status_code == 204
    # Re-reading must 404.
    r2 = client.get(f"/api/v1/users/{alice.id}", headers=auth_headers(admin))
    assert r2.status_code == 404


def test_delete_user_as_customer_returns_403(client, make_user, auth_headers):
    customer = make_user(email="cust@example.com")
    target = make_user(email="target@example.com")
    r = client.delete(f"/api/v1/users/{target.id}", headers=auth_headers(customer))
    assert r.status_code == 403
