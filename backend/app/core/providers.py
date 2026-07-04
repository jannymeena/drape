import structlog

from app.core.config import Settings, settings
from app.services.providers.ai.anthropic import AnthropicProvider
from app.services.providers.ai.base import AIProvider
from app.services.providers.ai.caching import CachingAIProvider
from app.services.providers.ai.mock import MockAIProvider
from app.services.providers.crypto.base import Encryptor
from app.services.providers.crypto.kms_envelope import KmsEnvelopeEncryptor
from app.services.providers.crypto.local_aes import LocalAesEncryptor
from app.services.providers.email.base import EmailProvider
from app.services.providers.email.log import LogEmailProvider
from app.services.providers.email.ses import SesEmailProvider
from app.services.providers.hash.base import PasswordHasher
from app.services.providers.hash.bcrypt import BcryptPasswordHasher
from app.services.providers.image.base import ImageStorageProvider
from app.services.providers.image.local_fs import LocalFsStorage
from app.services.providers.image.s3 import S3ImageStorage
from app.services.providers.payment.base import PaymentProvider
from app.services.providers.payment.mock import MockPaymentProvider
from app.services.providers.payment.stripe import StripeProvider
from app.services.providers.oauth.base import OAuthVerifier
from app.services.providers.oauth.real import RealOAuthVerifier
from app.services.providers.weather.base import WeatherProvider
from app.services.providers.weather.open_meteo import OpenMeteoProvider

_log = structlog.get_logger("providers")


class Providers:
    def __init__(self, s: Settings) -> None:
        self.password_hasher: PasswordHasher = BcryptPasswordHasher()
        self.email: EmailProvider = self._build_email(s)
        self.oauth: OAuthVerifier | None = self._build_oauth(s)
        self.encryptor: Encryptor = self._build_encryptor(s)
        self.image_storage: ImageStorageProvider = self._build_image_storage(s)
        self.ai: AIProvider = self._build_ai(s)
        self.weather: WeatherProvider = self._build_weather(s)
        self.payment: PaymentProvider = self._build_payment(s)
        _log.info(
            "providers.built",
            environment=s.environment,
            password_hasher=type(self.password_hasher).__name__,
            email=type(self.email).__name__,
            oauth=type(self.oauth).__name__ if self.oauth else None,
            encryptor=type(self.encryptor).__name__,
            image_storage=type(self.image_storage).__name__,
            ai=type(self.ai).__name__,
            weather=type(self.weather).__name__,
            payment=type(self.payment).__name__,
        )

    @staticmethod
    def _build_email(s: Settings) -> EmailProvider:
        if s.environment == "dev":
            return LogEmailProvider()
        assert s.ses_region and s.ses_from_address
        return SesEmailProvider(region=s.ses_region, from_address=s.ses_from_address)

    @staticmethod
    def _build_payment(s: Settings) -> PaymentProvider:
        if s.environment == "dev":
            return MockPaymentProvider()
        assert s.stripe_api_key, "stripe_api_key required outside dev"
        return StripeProvider(api_key=s.stripe_api_key)

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
            from pathlib import Path
            return LocalFsStorage(
                root=Path(s.local_image_dir),
                base_url=s.local_image_base_url,
            )
        assert s.image_bucket
        return S3ImageStorage(
            bucket=s.image_bucket,
            region=s.aws_region,
            cdn_base_url=s.image_cdn_base_url,
        )

    @staticmethod
    def _build_ai(s: Settings) -> AIProvider:
        if s.anthropic_api_key:
            model = s.anthropic_model or AnthropicProvider.DEFAULT_MODEL
            base: AIProvider = AnthropicProvider(s.anthropic_api_key, default_model=model)
            # Wrap real Anthropic calls in the analyze_image cache (§5.1).
            if s.ai_cache_enabled:
                return CachingAIProvider(base, default_model=model)
            return base
        if s.environment == "dev":
            return MockAIProvider()
        # Unreachable: config validator requires ANTHROPIC_API_KEY in tbd/prd.
        raise RuntimeError("ANTHROPIC_API_KEY is required outside dev")

    @staticmethod
    def _build_weather(_s: Settings) -> WeatherProvider:
        return OpenMeteoProvider()


providers = Providers(settings)
