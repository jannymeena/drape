"""Scan accuracy: scanned items keep the AI's untouched detection, and any
later difference from it counts as a user correction, per model."""
from __future__ import annotations

import uuid

from app.db.models import WardrobeItem
from app.services.scan_accuracy_service import scan_accuracy

_DETECTION = {
    "category": "tops",
    "color": "Navy",
    "pattern": "solid",
    "formality": "casual",
    "confidence": 82,
    "model": "claude-haiku-4-5",
}


def _scan_body(**overrides) -> dict:
    body = {
        "name": "Scanned tee",
        "category": "tops",
        "color_name": "navy",
        "pattern": "solid",
        "formality": "casual",
        "added_via": "scan",
        "ai_detection": _DETECTION,
    }
    body.update(overrides)
    return body


def test_create_from_scan_keeps_detection(authed_client, db):
    r = authed_client.post("/api/v1/wardrobe/items", json=_scan_body())
    assert r.status_code == 201, r.text
    body = r.json()
    assert body["added_via"] == "scan"
    assert body["ai_detection_confidence"] == 82
    row = db.get(WardrobeItem, uuid.UUID(body["id"]))
    assert row.ai_detection["model"] == "claude-haiku-4-5"
    assert row.ai_detection["color"] == "Navy"


def test_manual_create_has_no_detection(authed_client, db):
    r = authed_client.post(
        "/api/v1/wardrobe/items", json={"name": "Jeans", "category": "bottoms"}
    )
    assert r.status_code == 201, r.text
    assert r.json()["added_via"] == "manual"
    assert db.get(WardrobeItem, uuid.UUID(r.json()["id"])).ai_detection is None


def test_accuracy_counts_review_and_later_corrections(authed_client, db):
    # Kept as the AI said (colour differs only in case -> not a correction).
    authed_client.post("/api/v1/wardrobe/items", json=_scan_body())
    # Corrected on the review screen before saving.
    authed_client.post(
        "/api/v1/wardrobe/items", json=_scan_body(category="dresses", formality="formal")
    )
    # Corrected later via Edit.
    later = authed_client.post("/api/v1/wardrobe/items", json=_scan_body()).json()
    authed_client.patch(f"/api/v1/wardrobe/items/{later['id']}", json={"pattern": "striped"})
    # Manual items don't count.
    authed_client.post("/api/v1/wardrobe/items", json={"name": "Jeans", "category": "bottoms"})

    [acc] = scan_accuracy(db)
    assert acc.model == "claude-haiku-4-5"
    assert acc.items == 3
    assert acc.any_corrected == 2
    assert acc.corrected == {"category": 1, "color": 0, "pattern": 1, "formality": 1}
    assert round(acc.accuracy("category"), 2) == 0.67


def test_scan_response_carries_model(authed_client, canned_ai):
    canned_ai.vision_model = "claude-haiku-4-5"
    from tests.api.routes.test_wardrobe import _TINY_PNG

    r = authed_client.post(
        "/api/v1/wardrobe/scan-item", files={"file": ("t.png", _TINY_PNG, "image/png")}
    )
    assert r.status_code == 200, r.text
    assert r.json()["detection"]["model"] == "claude-haiku-4-5"
