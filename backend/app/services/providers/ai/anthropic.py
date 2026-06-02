from __future__ import annotations

import base64
import time

import anthropic
import structlog

from app.services.providers.ai.base import AIProvider, AIProviderError

_log = structlog.get_logger("provider.ai.anthropic")

DEFAULT_MODEL = "claude-sonnet-4-6"


class AnthropicProvider(AIProvider):
    # Exposed as a class attribute so config/providers can resolve the fallback
    # without re-importing the module constant. Kept in sync with DEFAULT_MODEL.
    DEFAULT_MODEL = DEFAULT_MODEL

    def __init__(self, api_key: str, *, default_model: str = DEFAULT_MODEL) -> None:
        self._client = anthropic.AsyncAnthropic(api_key=api_key)
        self._default_model = default_model

    async def chat(
        self,
        messages: list[dict[str, str]],
        *,
        model: str | None = None,
        system: str | None = None,
        max_tokens: int = 1024,
    ) -> str:
        model_id = model or self._default_model
        kwargs: dict = {"model": model_id, "max_tokens": max_tokens, "messages": messages}
        if system:
            kwargs["system"] = system
        started = time.monotonic()
        try:
            resp = await self._client.messages.create(**kwargs)
        except anthropic.APIError as exc:
            _log.warning("ai.chat.failed", model=model_id, error=str(exc))
            raise AIProviderError("ai_call_failed", f"Anthropic chat failed: {exc}") from exc
        latency_ms = int((time.monotonic() - started) * 1000)
        text = "".join(b.text for b in resp.content if getattr(b, "type", None) == "text")
        _log.info(
            "ai.chat",
            model=model_id,
            input_tokens=resp.usage.input_tokens,
            output_tokens=resp.usage.output_tokens,
            latency_ms=latency_ms,
        )
        return text

    async def analyze_image(
        self,
        image_bytes: bytes,
        prompt: str,
        *,
        media_type: str = "image/jpeg",
        model: str | None = None,
        max_tokens: int = 1024,
    ) -> str:
        encoded = base64.standard_b64encode(image_bytes).decode("ascii")
        messages = [
            {
                "role": "user",
                "content": [
                    {
                        "type": "image",
                        "source": {"type": "base64", "media_type": media_type, "data": encoded},
                    },
                    {"type": "text", "text": prompt},
                ],
            }
        ]
        model_id = model or self._default_model
        started = time.monotonic()
        try:
            resp = await self._client.messages.create(
                model=model_id, max_tokens=max_tokens, messages=messages
            )
        except anthropic.APIError as exc:
            _log.warning("ai.analyze_image.failed", model=model_id, error=str(exc))
            raise AIProviderError(
                "ai_call_failed", f"Anthropic analyze_image failed: {exc}"
            ) from exc
        latency_ms = int((time.monotonic() - started) * 1000)
        text = "".join(b.text for b in resp.content if getattr(b, "type", None) == "text")
        _log.info(
            "ai.analyze_image",
            model=model_id,
            input_tokens=resp.usage.input_tokens,
            output_tokens=resp.usage.output_tokens,
            latency_ms=latency_ms,
            image_bytes=len(image_bytes),
        )
        return text
