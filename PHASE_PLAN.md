# Drape — Detailed Phase Plan

This document expands [`IMPLEMENTATION_PLAN.md`](./IMPLEMENTATION_PLAN.md) into actionable, step-by-step instructions. New contributors should start with [`README.md`](./README.md). The product contract for everything from Phase 5 onward is [`CTO_Handoff_Onboarding_Flow.md`](./CTO_Handoff_Onboarding_Flow.md).

## Status snapshot

| Phase | Description                                                  | Status                            |
|-------|--------------------------------------------------------------|-----------------------------------|
| 1     | API skeleton (no DB, no auth)                                | ✅ Built                          |
| 2     | Relational DB foundation (initial users + profiles tables)   | ✅ Built (schema reshape in Phase 5) |
| 3     | Firebase auth                                                | ⚠️ Built but **superseded** in Phase 4 |
| 4     | Cross-cutting foundation: providers, logging, own-JWT        | 🚧 Active                         |
| 5     | Onboarding domain: schema, profile, measurements, avatar     | ⏳ Next                           |
| 6     | AI service layer + outfit generation                         | ⏳                                |
| 7     | AWS deployment (`ca-central-1`)                              | ⏳                                |
| 8     | Flutter client                                               | ⏳                                |

---

## Cross-cutting concerns (used by every phase from 4 onward)

### Provider container (`app/core/providers.py`)

Built once at startup; exposed to routes via `Depends(...)`. The FastAPI equivalent of Spring's `@Profile`-conditioned `@Service` beans.

```python
class Providers:
    def __init__(self, settings: Settings):
        self.password_hasher = BcryptPasswordHasher()
        self.ai = AnthropicProvider(settings.anthropic_api_key)
        self.email = self._build_email(settings)
        self.oauth = self._build_oauth(settings)
        self.encryptor = self._build_encryptor(settings)

    def _build_email(self, s: Settings) -> EmailProvider:
        if s.environment == "dev":
            return LogEmailProvider()
        return SesEmailProvider(region=s.ses_region, from_address=s.ses_from_address)

    def _build_oauth(self, s: Settings) -> OAuthVerifier | None:
        if s.environment == "dev":
            return None  # OAuth routes don't mount in dev
        return RealOAuthVerifier(
            apple_client_id=s.apple_client_id,
            google_client_id=s.google_client_id,
        )

    def _build_encryptor(self, s: Settings) -> Encryptor:
        if s.environment == "dev":
            return LocalAesEncryptor(s.measurement_dek_dev)
        return KmsEnvelopeEncryptor(key_id=s.kms_key_id, region=s.aws_region)
```

### Structured logging (`app/core/logging.py`)

```python
def configure_logging(settings: Settings) -> None:
    processors = [
        structlog.contextvars.merge_contextvars,
        structlog.processors.add_log_level,
        structlog.processors.TimeStamper(fmt="iso"),
    ]
    if settings.environment == "dev":
        processors.append(structlog.dev.ConsoleRenderer())
    else:
        processors.append(structlog.processors.JSONRenderer())
    structlog.configure(processors=processors)


class RequestIdMiddleware:
    async def __call__(self, request, call_next):
        request_id = request.headers.get("X-Request-ID") or str(uuid.uuid4())
        structlog.contextvars.bind_contextvars(request_id=request_id)
        try:
            response = await call_next(request)
            response.headers["X-Request-ID"] = request_id
            return response
        finally:
            structlog.contextvars.clear_contextvars()
```

Every provider gets a bound logger (`logger = structlog.get_logger("provider.email.ses")`) so every log line has the provider boundary, the request ID, and the user ID in context.

---

## Phase 1: API Skeleton (built — for reference)

Pydantic schemas under `app/schemas/`, dummy CRUD routes under `app/api/routes/`, FastAPI app in `app/main.py`. Swagger live at `/docs`. Exit criteria met: every endpoint returns a 200/204 with the right shape.

## Phase 2: Relational DB Foundation (built — schema reshape coming)

`pgvector/pgvector:pg16` via docker-compose on host port 5433. SQLAlchemy 2 + Alembic. Initial `users` and `profiles` tables. `Role` enum (`customer`, `admin`) lives in `app/schemas/user.py` and is imported by `app/db/models.py`.

## Phase 3: Firebase Auth (built — superseded)

Firebase JWT verification with JIT user provisioning landed under `app/api/dependencies/auth.py`, plus a dev mock-user shortcut. **Being replaced in Phase 4** — see [auth decision rationale in `IMPLEMENTATION_PLAN.md`](./IMPLEMENTATION_PLAN.md#%EF%B8%8F-phase-3-authentication-firebase--superseded).

---

## Phase 4: Cross-Cutting Foundation — Providers, Logging, Own-JWT Auth

**Goal:** Replace Firebase with own-JWT, lay down providers + logging, and keep identity data in `ca-central-1`.

### 4.1 New dependencies (`requirements.txt`)
- `pyjwt` — JWT encode/decode
- `passlib[bcrypt]` — password hashing
- `structlog` — structured logging
- `httpx` — for OAuth verification calls (Apple/Google JWKS)
- `boto3` — for KMS/SES (used in tbd/prd)
- `cryptography` — for AES-256-GCM in `LocalAesEncryptor`

Remove: `firebase-admin`.

### 4.2 Provider scaffolding

Create `app/services/providers/<domain>/` for each domain. Each domain has:
- `base.py` — `abc.ABC` interface
- `<impl>.py` — one or more concrete impls

Domains in this phase:
| Domain    | Interface         | Impls                                 |
|-----------|-------------------|---------------------------------------|
| `hash`    | `PasswordHasher`  | `BcryptPasswordHasher`                |
| `email`   | `EmailProvider`   | `LogEmailProvider`, `SesEmailProvider` |
| `oauth`   | `OAuthVerifier`   | `RealOAuthVerifier`                   |

`AIProvider` and `Encryptor` interfaces also stub here but full impls land in Phase 6 / Phase 5 respectively.

### 4.3 Settings updates (`app/core/config.py`)

```python
class Settings(BaseSettings):
    # ... existing ...
    jwt_secret: str | None = None
    jwt_access_ttl_minutes: int = 60
    jwt_refresh_ttl_days: int = 30

    apple_client_id: str | None = None
    apple_team_id: str | None = None
    apple_key_id: str | None = None
    apple_private_key_path: str | None = None
    google_client_id: str | None = None

    ses_region: str | None = None
    ses_from_address: str | None = None

    anthropic_api_key: str | None = None

    measurement_dek_dev: str | None = None
    kms_key_id: str | None = None
    aws_region: str = "ca-central-1"

    @model_validator(mode="after")
    def _validate_env_keys(self) -> "Settings":
        if self.environment in ("tbd", "prd"):
            required = {
                "JWT_SECRET": self.jwt_secret,
                "APPLE_CLIENT_ID": self.apple_client_id,
                "GOOGLE_CLIENT_ID": self.google_client_id,
                "SES_REGION": self.ses_region,
                "SES_FROM_ADDRESS": self.ses_from_address,
                "KMS_KEY_ID": self.kms_key_id,
                "ANTHROPIC_API_KEY": self.anthropic_api_key,
            }
            missing = [k for k, v in required.items() if not v]
            if missing:
                raise ValueError(f"Missing required env vars in {self.environment}: {missing}")
        if self.environment == "dev" and not self.measurement_dek_dev:
            raise ValueError("MEASUREMENT_DEK_DEV is required in dev")
        return self
```

`firebase_credentials_path` is removed.

### 4.4 Own-JWT auth implementation

#### Routes (`app/api/routes/auth/`)
- `signup.py` — `POST /signup`
- `login.py` — `POST /login`
- `tokens.py` — `POST /refresh`, `POST /logout`
- `password_reset.py` — `POST /forgot-password`, `POST /reset-password`
- `oauth.py` — `POST /oauth/apple`, `POST /oauth/google` (mounted only when `environment != "dev"`)

#### Service (`app/services/auth_service.py`)
Holds the orchestration:
```python
class AuthService:
    def __init__(self, db: Session, hasher: PasswordHasher, email: EmailProvider, oauth: OAuthVerifier | None):
        ...

    async def signup(self, email: str, password: str, agreed_to_terms: bool) -> User: ...
    async def login(self, email: str, password: str) -> TokenPair: ...
    async def refresh(self, refresh_token: str) -> TokenPair: ...
    async def forgot_password(self, email: str) -> None: ...
    async def reset_password(self, token: str, new_password: str) -> None: ...
    async def oauth_login(self, provider: str, id_token: str) -> TokenPair: ...
```

#### Security helpers (`app/core/security.py`)
- `create_access_token(user_id, role)` — returns HS256 JWT, TTL from settings
- `create_refresh_token(user_id)` — returns opaque token; persist in `refresh_tokens` table for revocation
- `decode_token(token)` — raises `InvalidToken` on failure

#### Auth dependency (`app/api/dependencies/auth.py`)
Replace existing Firebase logic with own-JWT verification. JIT-provisioning logic for OAuth callers stays in `auth_service.oauth_login`.

#### Schema migration (Alembic)
- Drop `users.firebase_uid`
- Add `users.password_hash` (NULL for OAuth-only)
- Add `users.auth_method` (VARCHAR(20))
- Add `users.apple_id`, `users.google_id` (UNIQUE NULL)
- Add `users.agreed_to_terms`, `users.agreed_to_privacy`, `users.terms_agreed_at`
- New table `refresh_tokens` (`id`, `user_id`, `token_hash`, `expires_at`, `revoked_at`)
- New table `password_reset_tokens` (similar shape)

### 4.5 Conditional OAuth router mount (`app/main.py`)
```python
app.include_router(auth_router, prefix="/api/v1/auth")
if settings.environment != "dev":
    from app.api.routes.auth.oauth import router as oauth_router
    app.include_router(oauth_router, prefix="/api/v1/auth/oauth")
```

### 4.6 Dev seed script (`scripts/seed_dev_user.py`)
Creates `dev@drape.local` / `password` directly via `AuthService.signup`. Idempotent.

### 4.7 Verify
- `python scripts/seed_dev_user.py` then `POST /auth/login` → returns tokens.
- `GET /users/me` with the access token → 200.
- `ENVIRONMENT=staging uvicorn ...` → fails at startup.
- `ENVIRONMENT=tbd uvicorn ...` without `JWT_SECRET` → fails at startup.
- Pretty logs in dev; flip `ENVIRONMENT=tbd` and logs become JSON.
- `X-Request-ID` is present on every response and threaded through every log line for the request.
- `firebase-admin` is no longer in `requirements.txt`; no `firebase_admin` imports anywhere.

---

## Phase 5: Onboarding Domain

**Goal:** Implement what the CTO onboarding flow needs end-to-end.

### 5.1 Schema reshape (Alembic migration)

Drop `profiles` table (its content moves into `users`). Final `users` columns:

| Column                        | Type             | Notes                                       |
|-------------------------------|------------------|---------------------------------------------|
| `id`                          | UUID PK          |                                             |
| `email`                       | VARCHAR(255) UNIQUE NOT NULL |                                  |
| `password_hash`               | VARCHAR(255) NULL| Phase 4                                     |
| `auth_method`                 | VARCHAR(20)      | `email` / `apple` / `google`                |
| `apple_id`                    | VARCHAR(255) UNIQUE NULL |                                     |
| `google_id`                   | VARCHAR(255) UNIQUE NULL |                                     |
| `first_name`, `last_name`     | VARCHAR(100) NULL|                                             |
| `role`                        | ENUM             | `customer` / `admin`                        |
| `shopping_style`              | VARCHAR(20) NULL | check: `womens`/`mens`/`both`/`prefer_not_to_say` |
| `age_range`                   | VARCHAR(20) NULL | check: `18-24`/`25-34`/`35-44`/`45-54`/`55+`/`prefer_not_to_say` |
| `style_goals`                 | JSONB NULL       |                                             |
| `onboarding_completed`        | BOOLEAN DEFAULT FALSE |                                        |
| `onboarding_last_step`        | VARCHAR(50) NULL |                                             |
| `onboarding_started_at`       | TIMESTAMP NULL   |                                             |
| `onboarding_completed_at`     | TIMESTAMP NULL   |                                             |
| `agreed_to_terms`, `agreed_to_privacy` | BOOLEAN | Phase 4                                     |
| `terms_agreed_at`             | TIMESTAMP NULL   | Phase 4                                     |
| `is_active`                   | BOOLEAN DEFAULT TRUE |                                         |
| `created_at`, `updated_at`, `last_login` | TIMESTAMP |                                          |

New tables (column-level shape in `CTO_Handoff_Onboarding_Flow.md`):
- `user_measurements` — encrypted columns `bytea`, `unit_system`, `is_complete`, `encryption_key_id`, timestamps
- `starter_wardrobe_templates` — `name`, `gender`, `age_range`, `style_profile`, `items` JSONB
- `user_starter_wardrobes` — `user_id`, `template_id`, `is_active`, timestamps
- `user_avatars` — `user_id`, `avatar_url`, `parameters` JSONB, `generation_method`, `is_current`

### 5.2 Profile API

| Endpoint                           | Method | Purpose                                |
|------------------------------------|--------|----------------------------------------|
| `/api/v1/profile/shopping-style`   | POST   | Single-select; persists; returns next step |
| `/api/v1/profile/age-range`        | POST   | Optional; nullable                     |
| `/api/v1/profile/style-goals`      | POST   | Multi-select; min 1                    |
| `/api/v1/profile/onboarding-status`| GET    | Returns last completed + next step     |
| `/api/v1/profile/save-progress`    | POST   | Mid-flow checkpoint                    |

`profile_service.py` orchestrates; routes are thin.

### 5.3 Measurements API + encryption

`Encryptor` interface:
```python
class Encryptor(ABC):
    @abstractmethod
    def encrypt(self, plaintext: bytes, *, user_id: UUID) -> bytes: ...

    @abstractmethod
    def decrypt(self, ciphertext: bytes, *, user_id: UUID) -> bytes: ...
```

- `LocalAesEncryptor` — AES-256-GCM with key from `MEASUREMENT_DEK_DEV` (base64-encoded 32 bytes). Nonce is random per encrypt; stored prepended to ciphertext.
- `KmsEnvelopeEncryptor` — calls `kms.generate_data_key` to get a per-user DEK on first write; encrypts plaintext with the DEK; persists the wrapped DEK alongside ciphertext (so decrypt flow is `kms.decrypt(wrapped_dek)` then AES-GCM decrypt).

`POST /api/v1/profile/measurements`:
- Accepts metric or imperial.
- Service normalizes to cm/kg, encrypts, persists. Decrypt path symmetric.
- Routes never see ciphertext — they call `MeasurementService` which deals with the `Encryptor` provider.

### 5.4 Avatar

`POST /api/v1/avatar/generate`:
- Sync; CTO doc says <3s target.
- Generates parametric 2D avatar from measurements + shopping_style. Implementation pluggable; start with a simple SVG renderer behind an interface so a richer renderer can drop in later.
- Uploads to S3 in `ca-central-1`; returns CDN URL.

### 5.5 Starter wardrobe

- Seed `starter_wardrobe_templates` from `backend/data/starter_wardrobe_templates.json` (committed; not user data).
- Assignment logic mirrors CTO doc Screen 7:
  - `shopping_style` × `age_range` → template ID
  - Default templates for missing age range
- `POST /api/v1/starter-wardrobe/assign` and `GET /api/v1/starter-wardrobe/user/{user_id}`.

### 5.6 Verify

- End-to-end onboarding: signup → shopping-style → goals → measurements → avatar → `onboarding-status` returns `next_step: today_dashboard`.
- `psql` shows `user_measurements.height_cm` (or its replacement encrypted column) as bytes — not readable plaintext.
- Switching `ENVIRONMENT` from dev to tbd swaps `LocalAesEncryptor` → `KmsEnvelopeEncryptor` with no code change in services.

---

## Phase 6: AI Service Layer + Outfit Generation

**Goal:** First Claude-powered feature.

### 6.1 `AIProvider` interface

```python
class AIProvider(ABC):
    @abstractmethod
    async def generate_outfits(
        self,
        profile: ProfileContext,
        wardrobe: list[Item],
        context: OutfitContext,
    ) -> OutfitSet: ...

    @abstractmethod
    async def chat(self, messages: list[Message], *, model: str | None = None) -> str: ...
```

### 6.2 `AnthropicProvider`

- Uses official `anthropic` SDK.
- Default model `claude-sonnet-4-6`; per-request override to `claude-opus-4-7`.
- Fashion-stylist system prompt.
- Uses Anthropic's tool-use feature for structured output (forces the model to emit a valid `OutfitSet` JSON shape — no fragile text parsing).
- Logs `model_id`, `input_tokens`, `output_tokens`, `latency_ms`, `request_id`, `user_id`.

### 6.3 Outfit Generation API

| Endpoint                        | Method | Purpose                                        |
|---------------------------------|--------|------------------------------------------------|
| `/api/v1/outfits/generate`      | POST   | Optional `OutfitContext`; returns 3 outfits    |
| `/api/v1/outfits/{id}`          | GET    | Self-or-admin                                  |
| `/api/v1/outfits`               | GET    | Paginated history                              |

### 6.4 Persistence (`outfit_generations` table)

`id`, `user_id` FK, `context_json` JSONB, `response_json` JSONB, `model_id`, `input_tokens`, `output_tokens`, `created_at`.

### 6.5 Verify

- `POST /api/v1/outfits/generate` returns 3 outfit objects, each grounded in items from the user's wardrobe + starter wardrobe.
- Token usage logged with `request_id` + `user_id`.
- Swapping the AI provider (e.g. to a mock for tests) is a one-line change in `Providers._build_ai`.

---

## Phase 7: Cloud Deployment (AWS, `ca-central-1`)

| Resource          | Purpose                                        |
|-------------------|------------------------------------------------|
| RDS Postgres 16   | Primary DB; same image family as docker-compose |
| KMS               | Per-user DEKs for measurement encryption       |
| SES               | Password-reset emails                          |
| S3 + CloudFront   | Avatar image storage and delivery              |
| ECR + ECS Fargate | Containerized FastAPI app                      |
| ALB               | TLS termination, routing                       |
| Secrets Manager   | `JWT_SECRET`, `ANTHROPIC_API_KEY`, OAuth secrets, DB creds |
| CloudWatch Logs   | JSON log ingestion from `structlog`            |

ECS task entrypoint materializes `.env` from Secrets Manager before launching uvicorn — same `.env` loading mechanism as dev, just a different source.

---

## Phase 8: Mobile Client Integration (Flutter)

1. Create app under `/mobile`.
2. Auto-generate API client from `openapi.json` (e.g. `swagger_dart_code_generator`).
3. Native Apple Sign-In + Google Sign-In SDKs → exchange the platform ID token at `POST /auth/oauth/{provider}` for our JWT.
4. Email/password form for the long tail.
5. `flutter_secure_storage` for tokens; refresh-token rotation handled by an HTTP interceptor.

---

## Cross-cutting suggestions

- **Tests:** `pytest` + `httpx.AsyncClient` smoke tests per phase. A handful of integration tests against the real DB (no mock-DB) per the user's general preference for catching schema drift early.
- **Dockerfile:** lock down at the end of Phase 4 (own-JWT shipped) so Phase 7 has less to do.
- **OpenAPI:** treat `openapi.json` as a release artifact; the Flutter client generates from it.
