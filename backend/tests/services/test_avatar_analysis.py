"""§5.5 — avatar body/skin analysis + its injection into the outfit prompt."""
from __future__ import annotations

import asyncio

from app.services import avatar_analysis, outfit_service
from app.services.providers.ai.base import AIProvider, AIProviderError


class _CannedAI(AIProvider):
    def __init__(self, reply: str = "", *, raise_on_image: bool = False) -> None:
        self.reply = reply
        self.raise_on_image = raise_on_image

    async def chat(self, messages, *, model=None, system=None, max_tokens=1024) -> str:
        return ""

    async def analyze_image(
        self, image_bytes, prompt, *, media_type="image/jpeg", model=None, max_tokens=1024
    ) -> str:
        if self.raise_on_image:
            raise AIProviderError("ai_call_failed", "boom")
        return self.reply


def test_analyze_body_parses_plain_json():
    ai = _CannedAI(
        '{"body_type": "athletic", "skin_tone": "warm/olive", '
        '"styling_notes": "Structured fits suit you."}'
    )
    out = asyncio.run(avatar_analysis.analyze_body(ai, image_bytes=b"img"))
    assert out == {
        "body_type": "athletic",
        "skin_tone": "warm/olive",
        "styling_notes": "Structured fits suit you.",
    }


def test_analyze_body_extracts_from_fenced_and_drops_unknown_empty_keys():
    ai = _CannedAI(
        'Sure!\n```json\n{"body_type": "slim", "skin_tone": "  ", '
        '"styling_notes": "Go monochrome.", "extra": "ignore me"}\n```'
    )
    out = asyncio.run(avatar_analysis.analyze_body(ai, image_bytes=b"img"))
    # Empty skin_tone dropped, unknown key dropped.
    assert out == {"body_type": "slim", "styling_notes": "Go monochrome."}


def test_analyze_body_returns_none_on_garbage():
    out = asyncio.run(avatar_analysis.analyze_body(_CannedAI("not json"), image_bytes=b"img"))
    assert out is None


def test_analyze_body_returns_none_on_ai_error():
    ai = _CannedAI(raise_on_image=True)
    out = asyncio.run(avatar_analysis.analyze_body(ai, image_bytes=b"img"))
    assert out is None


def test_prompt_includes_wearer_block_when_analysis_present():
    prompt = outfit_service._build_user_prompt(
        occasion="work",
        items=[],
        weather=None,
        style_goals=None,
        using_starter_wardrobe=False,
        body_analysis={"body_type": "hourglass", "skin_tone": "cool/fair"},
    )
    assert "Wearer:" in prompt
    assert "hourglass" in prompt
    assert "cool/fair" in prompt


def test_prompt_omits_wearer_block_when_no_analysis():
    prompt = outfit_service._build_user_prompt(
        occasion="work",
        items=[],
        weather=None,
        style_goals=None,
        using_starter_wardrobe=False,
        body_analysis=None,
    )
    assert "Wearer" not in prompt
