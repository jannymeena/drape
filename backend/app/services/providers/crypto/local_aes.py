import base64
import os
from uuid import UUID

from cryptography.hazmat.primitives.ciphers.aead import AESGCM

from app.services.providers.crypto.base import Encryptor


class LocalAesEncryptor(Encryptor):
    def __init__(self, key_b64: str) -> None:
        key = base64.b64decode(key_b64)
        if len(key) != 32:
            raise ValueError(
                f"MEASUREMENT_DEK_DEV must decode to 32 bytes (AES-256), got {len(key)}"
            )
        self._aead = AESGCM(key)

    def encrypt(self, plaintext: bytes, *, user_id: UUID) -> bytes:
        nonce = os.urandom(12)
        ad = str(user_id).encode("utf-8")
        return nonce + self._aead.encrypt(nonce, plaintext, ad)

    def decrypt(self, ciphertext: bytes, *, user_id: UUID) -> bytes:
        nonce, ct = ciphertext[:12], ciphertext[12:]
        ad = str(user_id).encode("utf-8")
        return self._aead.decrypt(nonce, ct, ad)
