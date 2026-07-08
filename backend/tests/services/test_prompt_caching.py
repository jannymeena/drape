"""Tier 1.3 — Anthropic native prompt caching on the outfit-generation prefix.

Covers the whole chain: the provider marks the system prefix with
cache_control when asked, cache usage flows into the ai_usage log with
cache-aware cost math, and the outfit prompt is split so the stable content
(persona, schema, wardrobe) sits in `system` while volatile content
(occasion, weather) stays in the user message.
"""
from __future__ import annotations

import asyncio
import json
import uuid

import pytest

from app.core.config import settings
from app.db.models import WardrobeItem
from app.services import ai_pricing, outfit_service
from app.services.providers.ai.anthropic import AnthropicProvider
from app.services.providers.weather.base import WeatherSnapshot


class _FakeUsage:
    def __init__(self, *, cache_creation=0, cache_read=0):
        self.input_tokens = 100
        self.output_tokens = 50
        self.cache_creation_input_tokens = cache_creation
        self.cache_read_input_tokens = cache_read


class _FakeBlock:
    type = "text"
    text = '{"ok": true}'


class _FakeResponse:
    def __init__(self, usage):
        self.content = [_FakeBlock()]
        self.usage = usage


class _FakeMessages:
    def __init__(self, response):
        self._response = response
        self.calls: list[dict] = []

    async def create(self, **kwargs):
        self.calls.append(kwargs)
        return self._response


class _FakeClient:
    def __init__(self, response):
        self.messages = _FakeMessages(response)


def _provider(usage: _FakeUsage | None = None) -> AnthropicProvider:
    provider = AnthropicProvider("sk-ant-test", default_model="claude-haiku-4-5")
    provider._client = _FakeClient(_FakeResponse(usage or _FakeUsage()))
    return provider


# ---------------------------------------------------------------------------
# Provider: cache_control on the system prefix
# ---------------------------------------------------------------------------


def test_cache_system_wraps_system_in_cache_control_block():
    provider = _provider()
    asyncio.run(
        provider.chat(
            [{"role": "user", "content": "occasion: work"}],
            system="stable prefix",
            cache_system=True,
        )
    )
    request = provider._client.messages.calls[0]
    assert request["system"] == [
        {
            "type": "text",
            "text": "stable prefix",
            "cache_control": {"type": "ephemeral"},
        }
    ]


def test_without_cache_system_the_string_form_is_kept():
    provider = _provider()
    asyncio.run(
        provider.chat(
            [{"role": "user", "content": "hi"}],
            system="plain system",
        )
    )
    assert provider._client.messages.calls[0]["system"] == "plain system"


def test_no_system_sends_no_system_field():
    provider = _provider()
    asyncio.run(provider.chat([{"role": "user", "content": "hi"}], cache_system=True))
    assert "system" not in provider._client.messages.calls[0]


# ---------------------------------------------------------------------------
# Usage log + pricing account for cache tokens
# ---------------------------------------------------------------------------


@pytest.fixture
def usage_log(tmp_path, monkeypatch):
    log_path = tmp_path / "ai_usage.jsonl"
    monkeypatch.setattr(settings, "ai_usage_log_enabled", True)
    monkeypatch.setattr(settings, "ai_usage_log_path", str(log_path))
    return log_path


def test_cache_usage_recorded_in_usage_log(usage_log):
    provider = _provider(_FakeUsage(cache_creation=0, cache_read=4000))
    asyncio.run(
        provider.chat(
            [{"role": "user", "content": "hi"}], system="s", cache_system=True
        )
    )
    entry = json.loads(usage_log.read_text().strip())
    assert entry["cache_read_input_tokens"] == 4000
    assert entry["cache_creation_input_tokens"] == 0
    # Haiku 4.5: 100 in * $1 + 50 out * $5 + 4000 read * $0.10, per MTok.
    expected = (100 * 1 + 50 * 5 + 4000 * 0.10) / 1_000_000
    assert entry["cost_usd"] == pytest.approx(expected, abs=1e-9)


def test_cost_usd_bills_cache_writes_at_premium():
    # Cache write ~1.25x base input; read ~0.1x (5m TTL columns).
    cost = ai_pricing.cost_usd(
        "claude-haiku-4-5",
        0,
        0,
        cache_creation_input_tokens=1_000_000,
        cache_read_input_tokens=1_000_000,
    )
    assert cost == pytest.approx(1.25 + 0.10)


# ---------------------------------------------------------------------------
# Outfit prompt split: stable prefix in system, volatile in user message
# ---------------------------------------------------------------------------


def _item(name: str = "Blue Oxford Shirt") -> WardrobeItem:
    return WardrobeItem(
        id=uuid.uuid4(),
        user_id=uuid.uuid4(),
        name=name,
        category="tops",
        color_name="blue",
        formality="smart_casual",
        pattern="solid",
        is_starter_wardrobe=False,
    )


def test_system_context_carries_the_stable_content():
    items = [_item(), _item("Grey Chinos")]
    system = outfit_service._build_system_context(
        items=items,
        style_goals=["polished"],
        using_starter_wardrobe=False,
        body_analysis=None,
    )
    assert "You are Drape" in system  # persona
    assert "Respond with ONLY a JSON object" in system  # response format
    assert "Blue Oxford Shirt" in system and "Grey Chinos" in system
    assert "Style goals: polished." in system
    # Nothing volatile in the cacheable prefix.
    assert "Weather" not in system
    assert "Build ONE outfit" not in system


def test_user_prompt_carries_only_the_volatile_content():
    weather = WeatherSnapshot(
        temp_c=21.0, feels_like_c=19.0, condition="cloudy", humidity_pct=60, wind_kph=10.0
    )
    prompt = outfit_service._build_user_prompt(occasion="work", weather=weather)
    assert "occasion: work" in prompt
    assert "21°C" in prompt
    assert "id=" not in prompt  # items live in the system prefix now


def test_system_context_is_byte_stable_across_calls():
    # Prefix caching is a byte-exact match — same inputs must render
    # identically or every call would write a fresh cache entry.
    items = [_item()]
    kwargs = dict(
        items=items, style_goals=["casual"], using_starter_wardrobe=True, body_analysis=None
    )
    assert outfit_service._build_system_context(
        **kwargs
    ) == outfit_service._build_system_context(**kwargs)


class _RecordingAI:
    def __init__(self):
        self.calls: list[dict] = []

    async def chat(self, messages, *, model=None, system=None, max_tokens=1024, cache_system=False):
        self.calls.append({"system": system, "cache_system": cache_system, "messages": messages})
        item_ids = [str(uuid.uuid4()), str(uuid.uuid4())]  # minimal valid proposal
        return json.dumps(
            {
                "occasion": "work",
                "item_ids": item_ids,
                "reasoning_short": "s",
                "reasoning_full": "f",
                "per_item_rationales": {},
                "compatibility_score": 80,
                "factors": ["Color harmony"],
            }
        )

    async def analyze_image(self, *args, **kwargs):
        raise NotImplementedError


def test_outfit_generation_requests_system_caching():
    ai = _RecordingAI()
    asyncio.run(
        outfit_service._ask_ai_for_outfit(
            ai,
            occasion="work",
            items=[_item()],
            weather=None,
            style_goals=None,
            using_starter_wardrobe=False,
        )
    )
    call = ai.calls[0]
    assert call["cache_system"] is True
    assert "You are Drape" in call["system"]
    assert call["messages"][0]["content"].startswith("Build ONE outfit")
