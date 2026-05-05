from uuid import UUID

from app.services.providers.crypto.base import Encryptor


class KmsEnvelopeEncryptor(Encryptor):
    def __init__(self, *, key_id: str, region: str) -> None:
        self._key_id = key_id
        self._region = region

    def encrypt(self, plaintext: bytes, *, user_id: UUID) -> bytes:
        raise NotImplementedError("KMS envelope encryption is wired in Phase 5")

    def decrypt(self, ciphertext: bytes, *, user_id: UUID) -> bytes:
        raise NotImplementedError("KMS envelope encryption is wired in Phase 5")
