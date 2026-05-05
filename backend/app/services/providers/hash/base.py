from abc import ABC, abstractmethod


class PasswordHasher(ABC):
    @abstractmethod
    def hash(self, plaintext: str) -> str: ...

    @abstractmethod
    def verify(self, plaintext: str, hashed: str) -> bool: ...
