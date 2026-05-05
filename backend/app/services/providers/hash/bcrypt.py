import bcrypt as _bcrypt

from app.services.providers.hash.base import PasswordHasher


class BcryptPasswordHasher(PasswordHasher):
    def __init__(self, rounds: int = 12) -> None:
        self._rounds = rounds

    def hash(self, plaintext: str) -> str:
        salt = _bcrypt.gensalt(rounds=self._rounds)
        return _bcrypt.hashpw(plaintext.encode("utf-8"), salt).decode("utf-8")

    def verify(self, plaintext: str, hashed: str) -> bool:
        return _bcrypt.checkpw(plaintext.encode("utf-8"), hashed.encode("utf-8"))
