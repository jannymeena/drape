from typing import Literal

from pydantic import ValidationError, field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

Environment = Literal["dev", "tbd", "prd"]

_DEV_JWT_SECRET = "dev-only-do-not-use-in-tbd-or-prd-min-32-bytes"

# Feature names DISABLED_FEATURES may reference. Grow this set as more
# switchable features land.
_KNOWN_FEATURES = {"apple_login", "google_login", "billing", "push", "affiliate"}


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_name: str = "Zoura API"
    app_version: str = "0.1.0"
    api_v1_prefix: str = "/api/v1"

    environment: Environment = "dev"

    # Comma-separated CORS origins. Unset → "*" in dev (browser tools, local
    # web builds), locked down (no CORS middleware at all) in tbd/prd — the
    # mobile app is not a browser and needs none. Set explicitly when a web
    # client appears (e.g. https://zoura.style).
    cors_allow_origins: str | None = None

    # Per-IP sliding-window limit for the credential-guessing surface
    # (/auth/login, /auth/forgot-password, /auth/reset-password), per minute
    # per endpoint. 0 = off; dev/tests default off, tbd/prd force a floor of
    # 10 (see _validate — disabling outside dev is not supported).
    auth_rate_limit_per_minute: int = 0

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
    # AWIN affiliate (11e). Publisher ID + feed key drive the product-feed
    # catalog — required outside dev unless `affiliate` is disabled; in dev,
    # both set = real feeds, otherwise the mock catalog. AWIN_API_KEY (Publisher
    # API token) is reserved for commission reporting and not read yet.
    awin_api_key: str | None = None
    awin_publisher_id: str | None = None
    awin_feed_api_key: str | None = None
    # Comma-separated advertiser allowlist; empty = every joined advertiser.
    awin_advertiser_ids: str = ""
    # advertiser_id:gender pairs (women|men|unisex), e.g. "60701:men,60703:women".
    # Unmapped advertisers get their gender from the AI tagger.
    awin_advertiser_genders: str = ""

    # Catalog worker: syncs the affiliate catalog on start + every 6 h and
    # AI-tags new products one at a time. Off in tests (they sync explicitly).
    catalog_worker_enabled: bool = True
    # Cheap model for the one-line-per-product tagging calls.
    catalog_tag_model: str = "claude-haiku-4-5-20251001"

    # Apple WeatherKit REST (weather). Required in tbd/prd; in dev, all four set
    # = WeatherKit, none set = Open-Meteo (free, non-commercial — dev only).
    # PRIVATE_KEY is the .p8 PEM, raw or base64-encoded (base64 survives the
    # one-line .env format).
    weatherkit_team_id: str | None = None
    weatherkit_service_id: str | None = None
    weatherkit_key_id: str | None = None
    weatherkit_private_key: str | None = None

    anthropic_api_key: str | None = None
    # Two models, split by job. Vision = every photo call (wardrobe scan, avatar
    # analysis, buy/don't-buy): narrow structured reads, so the cheap model.
    # Text = the reasoning calls over stored text (outfit building, AI advisor).
    # AI_TEXT_EFFORT sets output_config.effort on text calls; it must be empty
    # for a Haiku text model (Haiku 4.5 rejects effort).
    ai_vision_model: str = "claude-haiku-4-5"
    ai_text_model: str = "claude-sonnet-5-5"
    ai_text_effort: Literal["low", "medium", "high"] | None = "low"

    # Weekly trend brief (trend_service): a web-search research call per
    # audience, fed into the stylist prompts. The worker only runs with a real
    # ANTHROPIC_API_KEY; off in tests. Needs web search enabled for the org in
    # the Claude Console.
    trend_worker_enabled: bool = True
    ai_trend_model: str = "claude-sonnet-5-5"

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

    def advertiser_genders(self) -> dict[str, str]:
        pairs = (p.split(":", 1) for p in self.awin_advertiser_genders.split(",") if ":" in p)
        return {a.strip(): g.strip().lower() for a, g in pairs if a.strip() and g.strip()}

    def _weatherkit_keys(self) -> dict[str, str | None]:
        return {
            "WEATHERKIT_TEAM_ID": self.weatherkit_team_id,
            "WEATHERKIT_SERVICE_ID": self.weatherkit_service_id,
            "WEATHERKIT_KEY_ID": self.weatherkit_key_id,
            "WEATHERKIT_PRIVATE_KEY": self.weatherkit_private_key,
        }

    @property
    def weatherkit_configured(self) -> bool:
        return all(self._weatherkit_keys().values())

    def feature_enabled(self, feature: str) -> bool:
        return feature not in self._disabled_feature_set()

    @property
    def cors_origin_list(self) -> list[str]:
        """Resolved CORS origins; empty list means "don't mount CORS at all"."""
        raw = self.cors_allow_origins
        if raw is None:
            raw = "*" if self.environment == "dev" else ""
        return [o.strip() for o in raw.split(",") if o.strip()]

    @field_validator("ai_text_effort", mode="before")
    @classmethod
    def _blank_effort_is_none(cls, v: object) -> object:
        # `AI_TEXT_EFFORT=` in .env means "don't send effort".
        return None if v == "" else v

    @model_validator(mode="after")
    def _validate(self) -> "Settings":
        if self.ai_text_effort and self.ai_text_model.startswith("claude-haiku"):
            raise ValueError(
                "AI_TEXT_EFFORT must be empty when AI_TEXT_MODEL is a Haiku model "
                "(Haiku 4.5 does not support effort)"
            )
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
        weatherkit_set = [k for k, v in self._weatherkit_keys().items() if v]
        if weatherkit_set and not self.weatherkit_configured:
            missing = [k for k, v in self._weatherkit_keys().items() if not v]
            raise ValueError(
                f"WeatherKit is partially configured — also set: {', '.join(missing)}"
            )
        if self.environment in ("tbd", "prd"):
            if self.auth_rate_limit_per_minute <= 0:
                self.auth_rate_limit_per_minute = 10
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
                **self._weatherkit_keys(),
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
            if self.feature_enabled("affiliate"):
                required["AWIN_PUBLISHER_ID"] = self.awin_publisher_id
                required["AWIN_FEED_API_KEY"] = self.awin_feed_api_key
            missing = [k for k, v in required.items() if not v]
            if missing:
                raise ValueError(
                    f"Missing required env vars when ENVIRONMENT={self.environment!r}: "
                    f"{', '.join(missing)}"
                )
        return self


def sanitize_settings_error(exc: ValidationError) -> str:
    """Render a Settings ValidationError WITHOUT echoing input values.

    Pydantic's default rendering includes each field's input — for Settings
    that means secrets (DATABASE_URL, JWT_SECRET, API keys) land in the boot
    log/terminal on any bad config. Keep field names and messages only; our
    own validator messages never embed values.
    """
    lines = [
        f"  {'.'.join(str(p) for p in err['loc']) or '(settings)'}: {err['msg']}"
        for err in exc.errors(include_url=False, include_input=False)
    ]
    return (
        "Invalid configuration (values withheld — check backend/.env / SSM):\n"
        + "\n".join(lines)
    )


try:
    settings = Settings()
except ValidationError as exc:
    # `from None` drops the original exception (which carries the raw inputs)
    # from the traceback chain; SystemExit prints the message with no traceback.
    raise SystemExit(sanitize_settings_error(exc)) from None
