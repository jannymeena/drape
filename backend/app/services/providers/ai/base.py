from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass, field


class AIProviderError(Exception):
    """Domain-level AI provider failure. Routes translate to 5xx (or domain-specific code)."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code


@dataclass
class ResearchResult:
    """`web_research` output: the model's final text and the pages it drew on
    (`{"url", "title"}`, de-duplicated, in first-cited order)."""

    text: str
    model: str
    sources: list[dict[str, str]] = field(default_factory=list)


class AIProvider(ABC):
    # Model id `analyze_image` uses when no `model` is passed. Recorded on each
    # scanned item so scan accuracy can be compared per model. None = not a
    # real model (mocks, test fakes).
    vision_model: str | None = None

    @abstractmethod
    async def chat(
        self,
        messages: list[dict[str, str]],
        *,
        model: str | None = None,
        system: str | None = None,
        max_tokens: int = 1024,
        cache_system: bool = False,
    ) -> str:
        """Text chat. Returns the assistant's text reply.

        cache_system hints that `system` is a stable prefix reused across
        calls; providers with native prompt caching mark it accordingly
        (Tier 1.3 — callers put stable content in `system`, volatile content
        in `messages`, since caching is a byte-exact prefix match)."""

    @abstractmethod
    async def analyze_image(
        self,
        image_bytes: bytes,
        prompt: str,
        *,
        media_type: str = "image/jpeg",
        model: str | None = None,
        max_tokens: int = 1024,
    ) -> str:
        """Multimodal vision. Returns the assistant's text reply (typically JSON for structured output)."""

    async def web_research(
        self,
        prompt: str,
        *,
        model: str,
        system: str | None = None,
        max_searches: int = 6,
        country: str | None = None,
    ) -> ResearchResult:
        """Answer `prompt` after searching the web (server-side search tool).
        Only real providers can; the default refuses so mocks/fakes never
        pretend to have researched anything."""
        raise AIProviderError("unsupported", "web research needs a real AI provider")
