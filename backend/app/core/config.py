from typing import Literal

from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

Environment = Literal["dev", "tbd", "prd"]


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_name: str = "Drape API"
    app_version: str = "0.1.0"
    api_v1_prefix: str = "/api/v1"

    environment: Environment = "dev"

    database_url: str = "postgresql+psycopg2://admin:password@localhost:5433/drape"

    firebase_credentials_path: str | None = None

    @model_validator(mode="after")
    def _require_firebase_creds_in_deployed_envs(self) -> "Settings":
        if self.environment in ("tbd", "prd") and not self.firebase_credentials_path:
            raise ValueError(
                f"FIREBASE_CREDENTIALS_PATH is required when ENVIRONMENT={self.environment!r}"
            )
        return self


settings = Settings()
