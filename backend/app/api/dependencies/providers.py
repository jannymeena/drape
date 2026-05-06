from app.core.providers import providers
from app.services.providers.ai.base import AIProvider
from app.services.providers.crypto.base import Encryptor
from app.services.providers.email.base import EmailProvider
from app.services.providers.hash.base import PasswordHasher
from app.services.providers.image.base import ImageStorageProvider
from app.services.providers.oauth.base import OAuthVerifier


def get_password_hasher() -> PasswordHasher:
    return providers.password_hasher


def get_email_provider() -> EmailProvider:
    return providers.email


def get_oauth_verifier() -> OAuthVerifier | None:
    return providers.oauth


def get_encryptor() -> Encryptor:
    return providers.encryptor


def get_image_storage() -> ImageStorageProvider:
    return providers.image_storage


def get_ai_provider() -> AIProvider | None:
    return providers.ai
