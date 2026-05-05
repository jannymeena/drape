from abc import ABC, abstractmethod
from typing import Any


class OAuthVerifier(ABC):
    @abstractmethod
    async def verify_apple(self, id_token: str) -> dict[str, Any]: ...

    @abstractmethod
    async def verify_google(self, id_token: str) -> dict[str, Any]: ...
