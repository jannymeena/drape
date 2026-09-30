from __future__ import annotations

import base64
import time

import anthropic
import structlog

from app.services import ai_usage_log
from app.services.providers.ai.base import AIProvider, AIProviderError

_log = structlog.get_logger("provider.ai.anthropic")


class AnthropicProvider(AIProvider):
    """`chat` defaults to `text_model` and `analyze_image` to `vision_model`
    (see Settings.ai_text_model / ai_vision_model). `text_effort` is sent as
    output_config.effort on default-model chat calls only — a caller that
    passes its own `model` (the catalog tagger's Haiku) gets no effort, since
    Haiku 4.5 rejects it."""

    def __init__(
        self,
        api_key: str,
        *,
        text_model: str,
        vision_model: str,
        text_effort: str | None = None,
    ) -> None:
        self._client = anthropic.AsyncAnthropic(api_key=api_key)
        self._text_model = text_model
        self.vision_model = vision_model
        self._text_effort = text_effort

    async def chat(
        self,
        messages: list[dict[str, str]],
        *,
        model: str | None = None,
        system: str | None = None,
        max_tokens: int = 1024,
        cache_system: bool = False,
    ) -> str:
        model_id = model or self._text_model
        kwargs: dict = {"model": model_id, "max_tokens": max_tokens, "messages": messages}
        if model is None and self._text_effort:
            kwargs["output_config"] = {"effort": self._text_effort}
        if system:
            if cache_system:
                # Native prompt caching (Tier 1.3): a breakpoint on the last
                # system block caches the whole prefix; reads bill at ~10% of
                # base input. Below the model's minimum cacheable prefix this
                # silently no-ops — watch cache_* in the usage log.
                kwargs["system"] = [
                    {
                        "type": "text",
                        "text": system,
                        "cache_control": {"type": "ephemeral"},
                    }
                ]
            else:
                kwargs["system"] = system
        started = time.monotonic()
        try:
            resp = await self._client.messages.create(**kwargs)
        except anthropic.APIError as exc:
            _log.warning("ai.chat.failed", model=model_id, error=str(exc))
            raise AIProviderError("ai_call_failed", f"Anthropic chat failed: {exc}") from exc
        latency_ms = int((time.monotonic() - started) * 1000)
        _check_stop_reason(resp, model_id=model_id, call_type="chat")
        text = "".join(b.text for b in resp.content if getattr(b, "type", None) == "text")
        cache_creation = getattr(resp.usage, "cache_creation_input_tokens", 0) or 0
        cache_read = getattr(resp.usage, "cache_read_input_tokens", 0) or 0
        _log.info(
            "ai.chat",
            model=model_id,
            input_tokens=resp.usage.input_tokens,
            output_tokens=resp.usage.output_tokens,
            cache_creation_input_tokens=cache_creation,
            cache_read_input_tokens=cache_read,
            latency_ms=latency_ms,
        )
        ai_usage_log.record(
            model=model_id,
            call_type="chat",
            input_tokens=resp.usage.input_tokens,
            output_tokens=resp.usage.output_tokens,
            latency_ms=latency_ms,
            output=text,
            cache_creation_input_tokens=cache_creation,
            cache_read_input_tokens=cache_read,
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
        model_id = model or self.vision_model
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
        _check_stop_reason(resp, model_id=model_id, call_type="analyze_image")
        text = "".join(b.text for b in resp.content if getattr(b, "type", None) == "text")
        _log.info(
            "ai.analyze_image",
            model=model_id,
            input_tokens=resp.usage.input_tokens,
            output_tokens=resp.usage.output_tokens,
            latency_ms=latency_ms,
            image_bytes=len(image_bytes),
        )
        ai_usage_log.record(
            model=model_id,
            call_type="analyze_image",
            input_tokens=resp.usage.input_tokens,
            output_tokens=resp.usage.output_tokens,
            latency_ms=latency_ms,
            output=text,
            image_bytes=image_bytes,
            media_type=media_type,
        )
        return text


def _check_stop_reason(resp: object, *, model_id: str, call_type: str) -> None:
    """A safety decline comes back as HTTP 200 with stop_reason "refusal" and
    no usable text — surface it as a provider error instead of letting callers
    parse an empty reply. A max_tokens stop is logged (thinking on Sonnet 5.5
    counts toward max_tokens) and left to the caller's parse fallback."""
    stop_reason = getattr(resp, "stop_reason", None)
    if stop_reason == "refusal":
        details = getattr(resp, "stop_details", None)
        category = getattr(details, "category", None)
        _log.warning(f"ai.{call_type}.refused", model=model_id, category=category)
        raise AIProviderError("refused", f"Anthropic declined the request ({category})")
    if stop_reason == "max_tokens":
        _log.warning(f"ai.{call_type}.max_tokens", model=model_id)
