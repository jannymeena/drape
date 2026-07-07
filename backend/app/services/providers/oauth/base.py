from abc import ABC, abstractmethod
from typing import Any


class OAuthVerificationError(Exception):
    """Domain-level OAuth token verification failure. Services translate to AuthError."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code


class OAuthVerifier(ABC):
    @abstractmethod
    async def verify_apple(self, id_token: str) -> dict[str, Any]: ...

    @abstractmethod
    async def verify_google(self, id_token: str) -> dict[str, Any]: ...
