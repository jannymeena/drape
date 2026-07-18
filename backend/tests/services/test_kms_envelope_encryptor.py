"""KmsEnvelopeEncryptor (item 11b) — envelope encryption round-trip.

A local AES master key plays the CMK: the fake KMS client wraps/unwraps data
keys for real and enforces EncryptionContext, so key generation, the stored
blob layout, user binding at both layers, and tamper rejection are all
exercised without AWS.
"""
from __future__ import annotations

import os
from uuid import uuid4

import pytest
from cryptography.exceptions import InvalidTag
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

from app.services.providers.crypto.kms_envelope import KmsEnvelopeEncryptor


class _KmsContextError(Exception):
    """Stands in for botocore's InvalidCiphertextException."""


class _FakeKms:
    """Wraps data keys under a local master key; rejects context mismatches."""

    def __init__(self) -> None:
        self._master = AESGCM(os.urandom(32))
        self.generate_calls: list[dict] = []
        self.decrypt_calls: list[dict] = []

    @staticmethod
    def _ad(context: dict) -> bytes:
        return "|".join(f"{k}={v}" for k, v in sorted(context.items())).encode()

    def generate_data_key(self, *, KeyId, KeySpec, EncryptionContext):
        assert KeySpec == "AES_256"
        self.generate_calls.append({"KeyId": KeyId, "EncryptionContext": EncryptionContext})
        plaintext = os.urandom(32)
        nonce = os.urandom(12)
        blob = nonce + self._master.encrypt(nonce, plaintext, self._ad(EncryptionContext))
        return {"Plaintext": plaintext, "CiphertextBlob": blob, "KeyId": KeyId}

    def decrypt(self, *, CiphertextBlob, EncryptionContext):
        self.decrypt_calls.append({"EncryptionContext": EncryptionContext})
        nonce, ct = CiphertextBlob[:12], CiphertextBlob[12:]
        try:
            plaintext = self._master.decrypt(nonce, ct, self._ad(EncryptionContext))
        except InvalidTag:
            raise _KmsContextError("context mismatch or corrupted key blob")
        return {"Plaintext": plaintext}


@pytest.fixture()
def kms() -> _FakeKms:
    return _FakeKms()


@pytest.fixture()
def encryptor(kms: _FakeKms) -> KmsEnvelopeEncryptor:
    return KmsEnvelopeEncryptor(
        key_id="arn:aws:kms:ca-central-1:000000000000:key/test",
        region="ca-central-1",
        client=kms,
    )


def test_round_trip(encryptor):
    user = uuid4()
    blob = encryptor.encrypt(b'{"chest_cm":92}', user_id=user)
    assert blob != b'{"chest_cm":92}'
    assert encryptor.decrypt(blob, user_id=user) == b'{"chest_cm":92}'


def test_fresh_data_key_and_nonce_per_encrypt(encryptor, kms):
    user = uuid4()
    a = encryptor.encrypt(b"same", user_id=user)
    b = encryptor.encrypt(b"same", user_id=user)
    assert a != b  # new key + nonce every time; no deterministic ciphertext
    assert len(kms.generate_calls) == 2
    assert encryptor.decrypt(a, user_id=user) == b"same"
    assert encryptor.decrypt(b, user_id=user) == b"same"


def test_key_id_and_user_context_sent_to_kms(encryptor, kms):
    user = uuid4()
    blob = encryptor.encrypt(b"x", user_id=user)
    encryptor.decrypt(blob, user_id=user)
    assert kms.generate_calls[0]["KeyId"].endswith("key/test")
    assert kms.generate_calls[0]["EncryptionContext"] == {"user_id": str(user)}
    assert kms.decrypt_calls[0]["EncryptionContext"] == {"user_id": str(user)}


def test_wrong_user_rejected_at_kms_layer(encryptor):
    blob = encryptor.encrypt(b"secret", user_id=uuid4())
    with pytest.raises(_KmsContextError):
        encryptor.decrypt(blob, user_id=uuid4())


def test_tampered_ciphertext_rejected(encryptor):
    user = uuid4()
    blob = bytearray(encryptor.encrypt(b"secret", user_id=user))
    blob[-1] ^= 0x01  # flip a bit in the GCM tag
    with pytest.raises(InvalidTag):
        encryptor.decrypt(bytes(blob), user_id=user)


def test_unknown_version_rejected(encryptor):
    with pytest.raises(ValueError, match="version"):
        encryptor.decrypt(b"\x02" + b"garbage", user_id=uuid4())
    with pytest.raises(ValueError, match="version"):
        encryptor.decrypt(b"", user_id=uuid4())
