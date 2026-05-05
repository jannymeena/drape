from app.services.providers.ai.base import AIProvider


class AnthropicProvider(AIProvider):
    def __init__(self, api_key: str, *, default_model: str = "claude-sonnet-4-6") -> None:
        self._api_key = api_key
        self._default_model = default_model

    async def chat(self, messages: list[dict[str, str]], *, model: str | None = None) -> str:
        raise NotImplementedError("Anthropic chat is wired in Phase 6")
