"""Two-model split: photos go to the vision model, reasoning over text to the
text model with an explicit effort level; Sonnet 5.5 stop reasons are handled."""
from __future__ import annotations

import asyncio

import pytest
from pydantic import ValidationError

from app.core.config import Settings
from app.services.providers.ai.anthropic import AnthropicProvider
from app.services.providers.ai.base import AIProviderError


class _Usage:
    input_tokens = 100
    output_tokens = 50
    cache_creation_input_tokens = 0
    cache_read_input_tokens = 0


class _Block:
    type = "text"
    text = '{"ok": true}'


class _Response:
    def __init__(self, stop_reason: str = "end_turn", category: str | None = None) -> None:
        self.content = [] if stop_reason == "refusal" else [_Block()]
        self.usage = _Usage()
        self.stop_reason = stop_reason
        self.stop_details = type("_Details", (), {"category": category})()


class _Messages:
    def __init__(self, response: _Response) -> None:
        self.response = response
        self.calls: list[dict] = []

    async def create(self, **kwargs):
        self.calls.append(kwargs)
        return self.response


class _Client:
    def __init__(self, response: _Response) -> None:
        self.messages = _Messages(response)


def _provider(response: _Response | None = None, *, effort: str | None = "low"):
    provider = AnthropicProvider(
        "sk-ant-test",
        text_model="claude-sonnet-5-5",
        vision_model="claude-haiku-4-5",
        text_effort=effort,
    )
    provider._client = _Client(response or _Response())
    return provider


def _chat(provider, **kwargs) -> str:
    return asyncio.run(provider.chat([{"role": "user", "content": "hi"}], **kwargs))


def test_chat_uses_text_model_with_effort():
    provider = _provider()
    _chat(provider)
    call = provider._client.messages.calls[0]
    assert call["model"] == "claude-sonnet-5-5"
    assert call["output_config"] == {"effort": "low"}
    assert "thinking" not in call  # adaptive thinking is the model default


def test_explicit_model_gets_no_effort():
    # The catalog tagger passes its own Haiku model; Haiku 4.5 rejects effort.
    provider = _provider()
    _chat(provider, model="claude-haiku-4-5")
    call = provider._client.messages.calls[0]
    assert call["model"] == "claude-haiku-4-5"
    assert "output_config" not in call


def test_no_effort_configured_sends_none():
    provider = _provider(effort=None)
    _chat(provider)
    assert "output_config" not in provider._client.messages.calls[0]


def test_analyze_image_uses_vision_model():
    provider = _provider()
    asyncio.run(provider.analyze_image(b"img", "what is this?", media_type="image/png"))
    call = provider._client.messages.calls[0]
    assert call["model"] == "claude-haiku-4-5"
    assert "output_config" not in call
    assert provider.vision_model == "claude-haiku-4-5"


def test_refusal_raises_provider_error():
    provider = _provider(_Response(stop_reason="refusal", category="general_harms"))
    with pytest.raises(AIProviderError) as exc:
        _chat(provider)
    assert exc.value.code == "refused"


def test_max_tokens_stop_still_returns_text():
    provider = _provider(_Response(stop_reason="max_tokens"))
    assert _chat(provider) == '{"ok": true}'


# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------


def _settings(**overrides) -> Settings:
    base: dict = dict(
        _env_file=None,
        environment="dev",
        measurement_dek_dev="AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
    )
    base.update(overrides)
    return Settings(**base)


def test_default_split_is_haiku_vision_sonnet_text():
    s = _settings()
    assert s.ai_vision_model == "claude-haiku-4-5"
    assert s.ai_text_model == "claude-sonnet-5-5"
    assert s.ai_text_effort == "low"


def test_haiku_text_model_with_effort_refuses_to_boot():
    with pytest.raises(ValidationError, match="AI_TEXT_EFFORT"):
        _settings(ai_text_model="claude-haiku-4-5")


def test_blank_effort_allows_haiku_text_model():
    s = _settings(ai_text_model="claude-haiku-4-5", ai_text_effort="")
    assert s.ai_text_effort is None
