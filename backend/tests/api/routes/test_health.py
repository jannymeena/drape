"""Health endpoint — used by ALB / Kubernetes / docker-compose readiness probes."""
from __future__ import annotations


def test_health_returns_ok(client):
    r = client.get("/api/v1/health")
    assert r.status_code == 200
    assert r.json() == {"status": "ok"}


def test_health_requires_no_auth(client):
    """Liveness probes don't send tokens — must be reachable without."""
    r = client.get("/api/v1/health")
    assert r.status_code != 401
