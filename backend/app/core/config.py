from typing import Literal

from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

Environment = Literal["dev", "tbd", "prd"]

_DEV_JWT_SECRET = "dev-only-do-not-use-in-tbd-or-prd-min-32-bytes"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_name: str = "Drape API"
    app_version: str = "0.1.0"
    api_v1_prefix: str = "/api/v1"

    environment: Environment = "dev"

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
    password_reset_url_template: str = "https://drape.local/reset?token={token}"

    anthropic_api_key: str | None = None

    measurement_dek_dev: str | None = None
    kms_key_id: str | None = None
    aws_region: str = "ca-central-1"
    image_bucket: str | None = None
    image_cdn_base_url: str | None = None

    # Dev-only (LocalFsStorage). Files land under `local_image_dir` and are
    # served back at `local_image_base_url` via FastAPI's StaticFiles mount.
    local_image_dir: str = "uploads"
    local_image_base_url: str = "http://localhost:8000/uploads"

    @model_validator(mode="after")
    def _validate(self) -> "Settings":
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
                "APPLE_CLIENT_ID": self.apple_client_id,
                "GOOGLE_CLIENT_ID": self.google_client_id,
                "SES_REGION": self.ses_region,
                "SES_FROM_ADDRESS": self.ses_from_address,
                "KMS_KEY_ID": self.kms_key_id,
                "IMAGE_BUCKET": self.image_bucket,
            }
            missing = [k for k, v in required.items() if not v]
            if missing:
                raise ValueError(
                    f"Missing required env vars when ENVIRONMENT={self.environment!r}: "
                    f"{', '.join(missing)}"
                )
        return self


settings = Settings()
