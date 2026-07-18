import os
from uuid import UUID

import boto3
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

from app.services.providers.crypto.base import Encryptor

# Stored-blob layout (version 1):
#   [0]           version byte 0x01
#   [1:3]         big-endian length N of the KMS-wrapped data key
#   [3:3+N]       wrapped data key (KMS CiphertextBlob)
#   [3+N:3+N+12]  AES-GCM nonce
#   [3+N+12:]     AES-GCM ciphertext + tag
_VERSION = b"\x01"
_NONCE_LEN = 12


class KmsEnvelopeEncryptor(Encryptor):
    """Tbd/prd envelope encryption: a fresh KMS data key per encrypt.

    The CMK never leaves KMS. Each encrypt calls GenerateDataKey (one plaintext
    copy used locally for AES-256-GCM, one wrapped copy stored in the blob);
    decrypt unwraps via kms:Decrypt. The KMS EncryptionContext and the GCM
    associated data both carry the user id, so a blob can't be decrypted for —
    or replayed onto — another user, at either layer. CMK rotation is
    transparent: old wrapped keys decrypt under the old key version.
    """

    def __init__(self, *, key_id: str, region: str, client=None) -> None:
        self._key_id = key_id
        self._client = client or boto3.client("kms", region_name=region)

    def encrypt(self, plaintext: bytes, *, user_id: UUID) -> bytes:
        reply = self._client.generate_data_key(
            KeyId=self._key_id,
            KeySpec="AES_256",
            EncryptionContext={"user_id": str(user_id)},
        )
        wrapped: bytes = reply["CiphertextBlob"]
        nonce = os.urandom(_NONCE_LEN)
        ad = str(user_id).encode("utf-8")
        ct = AESGCM(reply["Plaintext"]).encrypt(nonce, plaintext, ad)
        return _VERSION + len(wrapped).to_bytes(2, "big") + wrapped + nonce + ct

    def decrypt(self, ciphertext: bytes, *, user_id: UUID) -> bytes:
        if not ciphertext or ciphertext[0:1] != _VERSION:
            raise ValueError("unknown measurement ciphertext version")
        wrapped_len = int.from_bytes(ciphertext[1:3], "big")
        wrapped = ciphertext[3 : 3 + wrapped_len]
        nonce = ciphertext[3 + wrapped_len : 3 + wrapped_len + _NONCE_LEN]
        ct = ciphertext[3 + wrapped_len + _NONCE_LEN :]
        reply = self._client.decrypt(
            CiphertextBlob=wrapped,
            EncryptionContext={"user_id": str(user_id)},
        )
        ad = str(user_id).encode("utf-8")
        return AESGCM(reply["Plaintext"]).decrypt(nonce, ct, ad)
