from app.core.providers import providers
from app.services.providers.ai.base import AIProvider
from app.services.providers.crypto.base import Encryptor
from app.services.providers.email.base import EmailProvider
from app.services.providers.hash.base import PasswordHasher
from app.services.providers.image.base import ImageStorageProvider
from app.services.providers.oauth.base import OAuthVerifier
from app.services.providers.affiliate.base import AffiliateProvider
from app.services.providers.payment.base import PaymentProvider
from app.services.providers.push.base import PushProvider
from app.services.providers.weather.base import WeatherProvider


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


def get_ai_provider() -> AIProvider:
    return providers.ai


def get_weather_provider() -> WeatherProvider:
    return providers.weather


def get_payment_provider() -> PaymentProvider:
    return providers.payment


def get_push_provider() -> PushProvider:
    return providers.push


def get_affiliate_provider() -> AffiliateProvider:
    return providers.affiliate
