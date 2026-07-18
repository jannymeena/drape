from typing import Literal

from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

Environment = Literal["dev", "tbd", "prd"]

_DEV_JWT_SECRET = "dev-only-do-not-use-in-tbd-or-prd-min-32-bytes"

# Feature names DISABLED_FEATURES may reference. Grow this set as more
# switchable features land.
_KNOWN_FEATURES = {"apple_login", "google_login", "billing", "push"}


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_name: str = "Zoura API"
    app_version: str = "0.1.0"
    api_v1_prefix: str = "/api/v1"

    environment: Environment = "dev"

    # Comma-separated feature names to turn OFF (see _KNOWN_FEATURES), e.g.
    # DISABLED_FEATURES=apple_login,billing. A disabled feature's config keys
    # are not required at startup and its endpoints answer 400
    # (oauth_unavailable / billing_unavailable). Read once at boot — flipping
    # it means a restart (redeploy in tbd/prd). Unknown names fail at startup.
    disabled_features: str = ""

    database_url: str = "postgresql+psycopg2://admin:password@localhost:5433/drape"

    jwt_secret: str = _DEV_JWT_SECRET
    # Short-lived access token; the client silently refreshes it via the
    # 30-day rotating refresh token. Override per env with JWT_ACCESS_TTL_MINUTES
    # (dev .env already sets 60). Keep this default short so any env that omits
    # the override doesn't inherit a long-lived token.
    jwt_access_ttl_minutes: int = 60
    jwt_refresh_ttl_days: int = 30

    apple_client_id: str | None = None
    apple_team_id: str | None = None
    apple_key_id: str | None = None
    apple_private_key_path: str | None = None
    google_client_id: str | None = None

    ses_region: str | None = None
    ses_from_address: str | None = None
    password_reset_url_template: str = "zoura://zoura.style/auth/reset-password?token={token}"
    # Stripe (11c) — required outside dev unless `billing` is disabled.
    stripe_api_key: str | None = None
    stripe_webhook_secret: str | None = None  # whsec_... for /billing/webhook/stripe
    stripe_price_id_pro_monthly: str | None = None
    stripe_price_id_pro_yearly: str | None = None
    # Where the Stripe customer portal sends the user back; deep link in prod.
    stripe_portal_return_url: str = "zoura://zoura.style/billing"
    # FCM service-account JSON, raw or base64-encoded (11d) — required outside
    # dev unless `push` is disabled. Dev logs via LogPushProvider.
    fcm_credentials_json: str | None = None
    awin_api_key: str | None = None  # required outside dev (11e)

    anthropic_api_key: str | None = None
    # Claude model id for the AI provider. Override per env with ANTHROPIC_MODEL
    # (e.g. a cheaper model in dev). None falls back to AnthropicProvider.DEFAULT_MODEL.
    anthropic_model: str | None = None

    # Dev AI usage/cost log (§5.3) — one JSONL line per AI call (model, tokens,
    # cost, latency, image meta, actual output). A dev exploration tool; turn off
    # in prd (prod analytics get a DB table later).
    ai_usage_log_enabled: bool = True
    ai_usage_log_path: str = "logs/ai_usage.jsonl"

    # AI response cache (§5.1) — content-addressed memoization of analyze_image
    # in Postgres (ai_response_cache). Identical garment photos always yield the
    # same detection, so a cache hit serves the stored result for free. Durable
    # (not volatile): an eviction means re-paying Claude. Only analyze_image is
    # cached; chat/outfit-gen passes through. Safe to leave on in every env.
    ai_cache_enabled: bool = True

    measurement_dek_dev: str | None = None
    kms_key_id: str | None = None
    aws_region: str = "ca-central-1"
    image_bucket: str | None = None
    image_cdn_base_url: str | None = None

    # Dev-only (LocalFsStorage). Files land under `local_image_dir` and are
    # served back at `local_image_base_url` via FastAPI's StaticFiles mount.
    local_image_dir: str = "uploads"
    local_image_base_url: str = "http://localhost:8000/uploads"

    def _disabled_feature_set(self) -> set[str]:
        return {f.strip() for f in self.disabled_features.split(",") if f.strip()}

    def feature_enabled(self, feature: str) -> bool:
        return feature not in self._disabled_feature_set()

    @model_validator(mode="after")
    def _validate(self) -> "Settings":
        unknown = self._disabled_feature_set() - _KNOWN_FEATURES
        if unknown:
            raise ValueError(
                f"Unknown feature name(s) in DISABLED_FEATURES: {', '.join(sorted(unknown))}. "
                f"Known: {', '.join(sorted(_KNOWN_FEATURES))}"
            )
        if self.environment == "dev":
            if not self.measurement_dek_dev:
                raise ValueError(
                    "MEASUREMENT_DEK_DEV is required when ENVIRONMENT=dev "
                    "(Phase 5b — measurements encryption). Generate one with: "
                    'python -c "import os, base64; print(base64.b64encode(os.urandom(32)).decode())"'
                )
        if self.environment in ("tbd", "prd"):
            if self.jwt_secret == _DEV_JWT_SECRET:
                raise ValueError(
                    f"JWT_SECRET must be overridden when ENVIRONMENT={self.environment!r}"
                )
            required = {
                "ANTHROPIC_API_KEY": self.anthropic_api_key,
                "SES_REGION": self.ses_region,
                "SES_FROM_ADDRESS": self.ses_from_address,
                "KMS_KEY_ID": self.kms_key_id,
                "IMAGE_BUCKET": self.image_bucket,
            }
            if self.feature_enabled("apple_login"):
                required["APPLE_CLIENT_ID"] = self.apple_client_id
            if self.feature_enabled("google_login"):
                required["GOOGLE_CLIENT_ID"] = self.google_client_id
            if self.feature_enabled("billing"):
                required["STRIPE_API_KEY"] = self.stripe_api_key
                required["STRIPE_WEBHOOK_SECRET"] = self.stripe_webhook_secret
                required["STRIPE_PRICE_ID_PRO_MONTHLY"] = self.stripe_price_id_pro_monthly
                required["STRIPE_PRICE_ID_PRO_YEARLY"] = self.stripe_price_id_pro_yearly
            if self.feature_enabled("push"):
                required["FCM_CREDENTIALS_JSON"] = self.fcm_credentials_json
            missing = [k for k, v in required.items() if not v]
            if missing:
                raise ValueError(
                    f"Missing required env vars when ENVIRONMENT={self.environment!r}: "
                    f"{', '.join(missing)}"
                )
        return self


settings = Settings()
