from __future__ import annotations

from abc import ABC, abstractmethod


class AIProviderError(Exception):
    """Domain-level AI provider failure. Routes translate to 5xx (or domain-specific code)."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code


class AIProvider(ABC):
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
