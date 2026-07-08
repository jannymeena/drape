from __future__ import annotations

import json

import structlog

from app.services.providers.ai.base import AIProvider

_log = structlog.get_logger("provider.ai.mock")


class MockAIProvider(AIProvider):
    """Deterministic canned responses for dev when ANTHROPIC_API_KEY is unset.

    Keeps Phases 6a/6b/6c verifiable end-to-end without burning real API quota.
    Tbd/prd never reaches this — config validator forces ANTHROPIC_API_KEY there.
    """

    async def chat(
        self,
        messages: list[dict[str, str]],
        *,
        model: str | None = None,
        system: str | None = None,
        max_tokens: int = 1024,
        cache_system: bool = False,  # no-op: nothing real to cache
    ) -> str:
        last_content = ""
        if messages:
            raw = messages[-1].get("content", "")
            last_content = raw if isinstance(raw, str) else str(raw)
        _log.info("ai.chat.mock", model=model, messages_len=len(messages))
        return f"[mock] received {len(messages)} message(s); last user content: {last_content[:120]!r}"

    async def analyze_image(
        self,
        image_bytes: bytes,
        prompt: str,
        *,
        media_type: str = "image/jpeg",
        model: str | None = None,
        max_tokens: int = 1024,
    ) -> str:
        _log.info(
            "ai.analyze_image.mock",
            image_bytes=len(image_bytes),
            media_type=media_type,
        )
        return json.dumps(
            {
                "category": "tops",
                "color": "blue",
                "pattern": "solid",
                "formality": "casual",
                "confidence": 75,
            }
        )
