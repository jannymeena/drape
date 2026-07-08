"""Content-addressed AI response cache (§5.1).

`CachingAIProvider` decorates another `AIProvider` and memoizes `analyze_image`
in Postgres (`ai_response_cache`). The same garment photo always yields the same
detection, so a cache hit serves the stored result for free — a durable win in
dev *and* prod. This is memoization, not a volatile cache: an eviction would mean
re-paying Claude, which is why it lives in Postgres (see §5.1).

Scope: `analyze_image` only. `chat`/outfit-gen passes straight through — outfits
must stay fresh and Today already persists its generated outfits (§5.2).

The cache must never break a request: any DB error is logged and treated as a
miss (read) or a no-op (write), so the real provider still answers.
"""
from __future__ import annotations

import asyncio
import hashlib

import structlog

from app.db.models import AIResponseCache
from app.db.session import SessionLocal
from app.services import ai_usage_log
from app.services.providers.ai.base import AIProvider

_log = structlog.get_logger("provider.ai.caching")


class CachingAIProvider(AIProvider):
    def __init__(self, inner: AIProvider, *, default_model: str) -> None:
        self._inner = inner
        # The decorator must resolve `model=None` to the same id the inner
        # provider would use, so the cache key is stable across calls.
        self._default_model = default_model

    async def chat(
        self,
        messages: list[dict[str, str]],
        *,
        model: str | None = None,
        system: str | None = None,
        max_tokens: int = 1024,
        cache_system: bool = False,
    ) -> str:
        # Not cached by design — passes through to the real provider.
        return await self._inner.chat(
            messages,
            model=model,
            system=system,
            max_tokens=max_tokens,
            cache_system=cache_system,
        )

    async def analyze_image(
        self,
        image_bytes: bytes,
        prompt: str,
        *,
        media_type: str = "image/jpeg",
        model: str | None = None,
        max_tokens: int = 1024,
    ) -> str:
        model_id = model or self._default_model
        key = self._cache_key(model_id, media_type, image_bytes, prompt)

        # DB I/O is synchronous (psycopg2); run it off the event loop.
        hit = await asyncio.to_thread(self._read, key)
        if hit is not None:
            response_text, input_tokens, output_tokens = hit
            _log.info("ai.cache.hit", call_type="analyze_image", model=model_id, cache_key=key)
            # Log the free hit so the usage log reflects the saving (cost = 0).
            ai_usage_log.record(
                model=model_id,
                call_type="analyze_image",
                input_tokens=input_tokens or 0,
                output_tokens=output_tokens or 0,
                latency_ms=0,
                output=response_text,
                cached=True,
                image_bytes=image_bytes,
                media_type=media_type,
            )
            return response_text

        _log.info("ai.cache.miss", call_type="analyze_image", model=model_id, cache_key=key)
        # The inner provider makes the real call and records its own (uncached)
        # usage line — we only store the result.
        text = await self._inner.analyze_image(
            image_bytes, prompt, media_type=media_type, model=model, max_tokens=max_tokens
        )
        await asyncio.to_thread(self._write, key, model_id, text)
        return text

    @staticmethod
    def _cache_key(model: str, media_type: str, image_bytes: bytes, prompt: str) -> str:
        h = hashlib.sha256()
        # NUL separators keep the fields unambiguous (image_bytes is the dominant input).
        h.update(model.encode("utf-8"))
        h.update(b"\x00")
        h.update(media_type.encode("utf-8"))
        h.update(b"\x00")
        h.update(image_bytes)
        h.update(b"\x00")
        h.update(prompt.encode("utf-8"))
        return h.hexdigest()

    @staticmethod
    def _read(key: str) -> tuple[str, int | None, int | None] | None:
        try:
            with SessionLocal() as db:
                row = db.get(AIResponseCache, key)
                if row is None:
                    return None
                return row.response_text, row.input_tokens, row.output_tokens
        except Exception as exc:  # cache must never break the request
            _log.warning("ai.cache.read_failed", cache_key=key, error=str(exc))
            return None

    @staticmethod
    def _write(key: str, model: str, text: str) -> None:
        try:
            with SessionLocal() as db:
                # A concurrent miss may have stored it already — stay idempotent.
                if db.get(AIResponseCache, key) is not None:
                    return
                db.add(
                    AIResponseCache(
                        cache_key=key,
                        model=model,
                        call_type="analyze_image",
                        response_text=text,
                    )
                )
                db.commit()
        except Exception as exc:  # cache must never break the request
            _log.warning("ai.cache.write_failed", cache_key=key, error=str(exc))
