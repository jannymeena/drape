"""§5.1 — content-addressed analyze_image cache (CachingAIProvider)."""
from __future__ import annotations

import asyncio

from app.db.models import AIResponseCache
from app.services.providers.ai.base import AIProvider
from app.services.providers.ai.caching import CachingAIProvider

_IMG = b"fake-jpeg-bytes"
_PROMPT = "describe this garment"


class _CountingAIProvider(AIProvider):
    """Inner provider that records how many real calls it received."""

    def __init__(self, reply: str = '{"category": "top"}') -> None:
        self.reply = reply
        self.analyze_calls = 0
        self.chat_calls = 0

    async def chat(
        self, messages, *, model=None, system=None, max_tokens=1024, cache_system=False
    ) -> str:
        self.chat_calls += 1
        return "chat-reply"

    async def analyze_image(
        self, image_bytes, prompt, *, media_type="image/jpeg", model=None, max_tokens=1024
    ) -> str:
        self.analyze_calls += 1
        return self.reply


def test_cache_key_is_stable_and_input_sensitive():
    k = CachingAIProvider._cache_key
    base = k("m", "image/jpeg", _IMG, _PROMPT)
    assert base == k("m", "image/jpeg", _IMG, _PROMPT)  # deterministic
    assert base != k("m2", "image/jpeg", _IMG, _PROMPT)  # model matters
    assert base != k("m", "image/png", _IMG, _PROMPT)  # media_type matters
    assert base != k("m", "image/jpeg", b"other", _PROMPT)  # bytes matter
    assert base != k("m", "image/jpeg", _IMG, "other")  # prompt matters


def test_miss_then_hit_calls_inner_once(db):
    inner = _CountingAIProvider()
    provider = CachingAIProvider(inner, default_model="claude-haiku-4-5")

    first = asyncio.run(provider.analyze_image(_IMG, _PROMPT))
    second = asyncio.run(provider.analyze_image(_IMG, _PROMPT))

    assert first == second == inner.reply
    assert inner.analyze_calls == 1  # second served from cache

    rows = db.query(AIResponseCache).all()
    assert len(rows) == 1
    assert rows[0].call_type == "analyze_image"
    assert rows[0].model == "claude-haiku-4-5"
    assert rows[0].response_text == inner.reply


def test_different_image_is_a_separate_entry(db):
    inner = _CountingAIProvider()
    provider = CachingAIProvider(inner, default_model="claude-haiku-4-5")

    asyncio.run(provider.analyze_image(_IMG, _PROMPT))
    asyncio.run(provider.analyze_image(b"different-bytes", _PROMPT))

    assert inner.analyze_calls == 2
    assert db.query(AIResponseCache).count() == 2


def test_chat_is_not_cached(db):
    inner = _CountingAIProvider()
    provider = CachingAIProvider(inner, default_model="claude-haiku-4-5")

    asyncio.run(provider.chat([{"role": "user", "content": "hi"}]))
    asyncio.run(provider.chat([{"role": "user", "content": "hi"}]))

    assert inner.chat_calls == 2  # passthrough, never memoized
    assert db.query(AIResponseCache).count() == 0
