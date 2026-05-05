from abc import ABC, abstractmethod
from uuid import UUID


class Encryptor(ABC):
    @abstractmethod
    def encrypt(self, plaintext: bytes, *, user_id: UUID) -> bytes: ...

    @abstractmethod
    def decrypt(self, ciphertext: bytes, *, user_id: UUID) -> bytes: ...
