import structlog

from app.core.config import Settings, settings
from app.services.providers.ai.anthropic import AnthropicProvider
from app.services.providers.ai.base import AIProvider
from app.services.providers.crypto.base import Encryptor
from app.services.providers.crypto.kms_envelope import KmsEnvelopeEncryptor
from app.services.providers.crypto.local_aes import LocalAesEncryptor
from app.services.providers.email.base import EmailProvider
from app.services.providers.email.log import LogEmailProvider
from app.services.providers.email.ses import SesEmailProvider
from app.services.providers.hash.base import PasswordHasher
from app.services.providers.hash.bcrypt import BcryptPasswordHasher
from app.services.providers.image.base import ImageStorageProvider
from app.services.providers.image.local_noop import LocalNoopImageStorage
from app.services.providers.image.s3 import S3ImageStorage
from app.services.providers.oauth.base import OAuthVerifier
from app.services.providers.oauth.real import RealOAuthVerifier

_log = structlog.get_logger("providers")


class Providers:
    def __init__(self, s: Settings) -> None:
        self.password_hasher: PasswordHasher = BcryptPasswordHasher()
        self.email: EmailProvider = self._build_email(s)
        self.oauth: OAuthVerifier | None = self._build_oauth(s)
        self.encryptor: Encryptor = self._build_encryptor(s)
        self.image_storage: ImageStorageProvider = self._build_image_storage(s)
        self.ai: AIProvider | None = self._build_ai(s)
        _log.info(
            "providers.built",
            environment=s.environment,
            password_hasher=type(self.password_hasher).__name__,
            email=type(self.email).__name__,
            oauth=type(self.oauth).__name__ if self.oauth else None,
            encryptor=type(self.encryptor).__name__,
            image_storage=type(self.image_storage).__name__,
            ai=type(self.ai).__name__ if self.ai else None,
        )

    @staticmethod
    def _build_email(s: Settings) -> EmailProvider:
        if s.environment == "dev":
            return LogEmailProvider()
        assert s.ses_region and s.ses_from_address
        return SesEmailProvider(region=s.ses_region, from_address=s.ses_from_address)

    @staticmethod
    def _build_oauth(s: Settings) -> OAuthVerifier | None:
        if s.environment == "dev":
            return None
        assert s.apple_client_id and s.google_client_id
        return RealOAuthVerifier(
            apple_client_id=s.apple_client_id,
            google_client_id=s.google_client_id,
        )

    @staticmethod
    def _build_encryptor(s: Settings) -> Encryptor:
        if s.environment == "dev":
            assert s.measurement_dek_dev  # config validator guarantees this
            return LocalAesEncryptor(s.measurement_dek_dev)
        assert s.kms_key_id
        return KmsEnvelopeEncryptor(key_id=s.kms_key_id, region=s.aws_region)

    @staticmethod
    def _build_image_storage(s: Settings) -> ImageStorageProvider:
        if s.environment == "dev":
            return LocalNoopImageStorage()
        assert s.image_bucket
        return S3ImageStorage(bucket=s.image_bucket, region=s.aws_region)

    @staticmethod
    def _build_ai(s: Settings) -> AIProvider | None:
        if not s.anthropic_api_key:
            return None
        return AnthropicProvider(s.anthropic_api_key)


providers = Providers(settings)
