from abc import ABC, abstractmethod


class AIProvider(ABC):
    @abstractmethod
    async def chat(self, messages: list[dict[str, str]], *, model: str | None = None) -> str: ...
