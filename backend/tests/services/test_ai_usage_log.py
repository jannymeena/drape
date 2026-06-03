"""§5.3 — dev AI usage/cost file log + pricing."""
from __future__ import annotations

import json

from app.core.config import settings
from app.services import ai_pricing, ai_usage_log

_TINY_PNG = (
    b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01"
    b"\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\rIDATx\x9cc\xfc\xcf"
    b"\xc0\x00\x00\x00\x05\x00\x01\xa5\x86\x82\x16\x00\x00\x00\x00IEND\xaeB`\x82"
)


def test_cost_usd_resolves_dated_model_via_family():
    exact = ai_pricing.cost_usd("claude-haiku-4-5", 1_000_000, 1_000_000)
    dated = ai_pricing.cost_usd("claude-haiku-4-5-20251001", 1_000_000, 1_000_000)
    assert exact == dated > 0


def test_record_writes_jsonl_with_image_meta(tmp_path, monkeypatch):
    path = tmp_path / "ai_usage.jsonl"
    monkeypatch.setattr(settings, "ai_usage_log_path", str(path))
    monkeypatch.setattr(settings, "ai_usage_log_enabled", True)

    ai_usage_log.record(
        model="claude-haiku-4-5",
        call_type="analyze_image",
        input_tokens=120,
        output_tokens=40,
        latency_ms=850,
        output='{"category":"tops","color":"white"}',
        image_bytes=_TINY_PNG,
        media_type="image/png",
    )

    entry = json.loads(path.read_text().strip())
    assert entry["model"] == "claude-haiku-4-5"
    assert entry["call_type"] == "analyze_image"
    assert entry["cost_usd"] > 0
    assert entry["output"].startswith("{")
    # Pillow is installed in dev → dimensions present; size always present.
    assert entry["image"]["size_bytes"] == len(_TINY_PNG)
    assert entry["image"]["width"] == 1 and entry["image"]["height"] == 1


def test_record_cache_hit_is_zero_cost(tmp_path, monkeypatch):
    path = tmp_path / "ai_usage.jsonl"
    monkeypatch.setattr(settings, "ai_usage_log_path", str(path))
    monkeypatch.setattr(settings, "ai_usage_log_enabled", True)
    ai_usage_log.record(
        model="claude-haiku-4-5",
        call_type="chat",
        input_tokens=999,
        output_tokens=999,
        latency_ms=1,
        output="hi",
        cached=True,
    )
    assert json.loads(path.read_text().strip())["cost_usd"] == 0.0


def test_record_noop_when_disabled(tmp_path, monkeypatch):
    path = tmp_path / "ai_usage.jsonl"
    monkeypatch.setattr(settings, "ai_usage_log_path", str(path))
    monkeypatch.setattr(settings, "ai_usage_log_enabled", False)
    ai_usage_log.record(
        model="x", call_type="chat", input_tokens=1, output_tokens=1,
        latency_ms=1, output="hi",
    )
    assert not path.exists()
