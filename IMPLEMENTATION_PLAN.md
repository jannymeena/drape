# Drape Implementation Plan: Enterprise AI B2C Application

> **Status:** Phases 1–3 are built. Phase 3's Firebase auth is being **replaced** in Phase 4 by an own-JWT flow (PIPEDA / `ca-central-1` residency requirement from `CTO_Handoff_Onboarding_Flow.md`). Active focus is the architectural foundation (Phase 4) before the onboarding domain (Phase 5). See [`PHASE_PLAN.md`](./PHASE_PLAN.md) for step-by-step detail. New contributors should start with [`README.md`](./README.md). The CTO onboarding spec at [`CTO_Handoff_Onboarding_Flow.md`](./CTO_Handoff_Onboarding_Flow.md) is the authoritative product contract — backend implements it, doesn't improvise on it.

---

## 🏗️ Technology Stack

* **Monorepo Strategy:** Folder-based.
* **Backend:** Python 3.11+, FastAPI, Pydantic v2, SQLAlchemy 2, Alembic.
* **Mobile:** Flutter (Dart).
* **Database:** PostgreSQL 16 (`pgvector/pgvector:pg16` image — extension reserved for Future Plans, not enabled yet).
* **Auth:** **Own-issued JWT** (HS256). Apple + Google Sign-In in tbd/prd via an `OAuthVerifier` provider that validates platform ID tokens against their public JWKS. *No Firebase.*
* **AI:** Anthropic Claude (`claude-sonnet-4-6` default) accessed through an `AIProvider` interface. *No LangGraph.*
* **Encryption:** AES-256 for `user_measurements` at rest. `Encryptor` interface — local key in dev, AWS KMS envelope encryption in tbd/prd.
* **Email:** `EmailProvider` interface — `LogEmailProvider` (dev, writes to logs) and `SesEmailProvider` (tbd/prd, AWS SES).
* **Logging:** `structlog` — pretty console in dev, JSON in tbd/prd. Per-request correlation IDs.
* **Cloud Infrastructure:** AWS `ca-central-1` (PIPEDA / Canada residency). ECS Fargate + ALB + RDS + KMS + SES + S3.

---

## 🧱 Architecture Principles

These are non-negotiable patterns for every new feature. They are the FastAPI/Python equivalents of patterns the team already uses in Spring Boot.

### 1. Provider pattern (interface + per-env impl)

Anything with a different implementation per environment lives behind an abstract interface (`abc.ABC`) and is wired by a startup `Providers` factory. This is the FastAPI equivalent of Spring's `@Profile`-driven beans.

| Interface         | dev impl                  | tbd / prd impl              |
|-------------------|---------------------------|-----------------------------|
| `AIProvider`      | `AnthropicProvider`       | `AnthropicProvider`         |
| `EmailProvider`   | `LogEmailProvider`        | `SesEmailProvider`          |
| `OAuthVerifier`   | *(not registered; OAuth routes don't mount in dev)* | `RealOAuthVerifier` |
| `Encryptor`       | `LocalAesEncryptor`       | `KmsEnvelopeEncryptor`      |
| `PasswordHasher`  | `BcryptPasswordHasher`    | `BcryptPasswordHasher`      |

Routes and services receive providers via FastAPI `Depends(...)` — never instantiate SDK clients directly.

### 2. Profile-specific configuration (`pydantic-settings`)

Single `Settings` class loads `.env` in every env. `ENVIRONMENT` (`Literal["dev", "tbd", "prd"]`) drives provider selection. A `model_validator` enforces "required keys per env" at startup — fail fast, never on first request.

### 3. Structured logging (`structlog`)

- Pretty console in dev; JSON output in tbd/prd for ingestion into CloudWatch.
- Request middleware injects `request_id` (UUID4) into log context — a single user action is traceable across DB / AI / email / encryption boundaries.
- Standard fields: `request_id`, `user_id`, `route`, `latency_ms`, `provider` (when crossing a provider boundary), `model_id` (AI calls), `event` (the canonical name of what happened).

### 4. Three-tier separation

`routes/` (HTTP, validation) → `services/` (business logic, calls providers) → `db/` (ORM, queries). Routes never call DB directly; services never know about HTTP.

### 5. Fail fast at startup

Missing required config, unreachable DB, malformed KMS key, invalid OAuth client config — all surface as a startup error, never as a 500 on the first request that touches them.

---

## 📂 Folder Structure

```text
drape/
├── backend/                     # FastAPI Application
│   ├── app/
│   │   ├── api/
│   │   │   ├── dependencies/    # Auth, DB session, provider injectors
│   │   │   └── routes/
│   │   │       ├── auth/        # signup, login, refresh, forgot/reset, oauth (oauth only mounts in tbd/prd)
│   │   │       ├── profile/     # shopping-style, age-range, style-goals, measurements, save-progress
│   │   │       ├── avatar/
│   │   │       ├── outfits/     # AI outfit generation
│   │   │       ├── starter_wardrobe/
│   │   │       ├── users.py
│   │   │       └── health.py
│   │   ├── core/
│   │   │   ├── config.py        # pydantic-settings, Literal env type, model_validator
│   │   │   ├── providers.py     # Providers container, built once at startup
│   │   │   ├── logging.py       # structlog config + RequestIdMiddleware
│   │   │   └── security.py      # JWT encode/decode helpers
│   │   ├── schemas/             # Pydantic DTOs
│   │   ├── services/
│   │   │   ├── providers/       # interface + impls per domain
│   │   │   │   ├── ai/          # base.py, anthropic.py
│   │   │   │   ├── email/       # base.py, log.py, ses.py
│   │   │   │   ├── oauth/       # base.py, real.py
│   │   │   │   ├── crypto/      # base.py, local_aes.py, kms_envelope.py
│   │   │   │   └── hash/        # base.py, bcrypt.py
│   │   │   ├── auth_service.py
│   │   │   ├── profile_service.py
│   │   │   ├── measurement_service.py
│   │   │   ├── avatar_service.py
│   │   │   ├── outfit_service.py
│   │   │   └── starter_wardrobe_service.py
│   │   ├── db/                  # Base, session, models
│   │   └── main.py              # FastAPI app, router includes (oauth conditional), middleware
│   ├── alembic/                 # Migration history
│   ├── data/                    # Seed data (starter wardrobe templates JSON)
│   ├── scripts/                 # seed_dev_user.py, etc.
│   ├── requirements.txt
│   └── Dockerfile
│
├── mobile/                      # Flutter app (Phase 8)
├── docker-compose.yml
├── IMPLEMENTATION_PLAN.md
├── PHASE_PLAN.md
├── CTO_Handoff_Onboarding_Flow.md
└── README.md
```

---

## ✅ Phase 1: API Skeleton (DONE)

Pydantic schemas, dummy CRUD routes, Swagger live at `/docs`. No DB, no auth.

## ✅ Phase 2: Relational DB Foundation (DONE — schema reshape coming in Phase 5)

`pgvector/pgvector:pg16` via docker-compose (host port 5433). SQLAlchemy 2 + Alembic. Initial `users` and `profiles` tables.

> **Note:** This schema is a foundation, not the final shape. Phase 4 will modify `users` for own-JWT auth (drop `firebase_uid`, add `password_hash` + OAuth columns). Phase 5 will fully reshape `users` to match the CTO doc and add `user_measurements`, `starter_wardrobe_templates`, `user_starter_wardrobes`, `user_avatars`, `outfit_generations`.

## ⚠️ Phase 3: Authentication (Firebase) — SUPERSEDED

Firebase JWT verification + dev mock-user shipped. **Replaced in Phase 4.** Reason: Firebase Auth stores identity data in Google's US infrastructure with no Canadian-only option, which contradicts the PIPEDA / `ca-central-1` residency promise made to users on the measurements privacy modal.

---

## 🔧 Phase 4: Cross-Cutting Foundation — Providers, Logging, Own-JWT Auth

**Goal:** Lay down the architectural primitives every later phase depends on, and replace Firebase with an own-JWT flow that keeps identity data in `ca-central-1`.

### 4.1 Provider interfaces and container
- Abstract bases under `app/services/providers/<domain>/base.py`.
- Concrete impls per env, side-by-side.
- `app/core/providers.py::Providers` factory wires the right impl based on `settings.environment`.
- Exposed as FastAPI dependencies (`Depends(get_ai_provider)` etc.).

### 4.2 Structured logging
- `app/core/logging.py` configures `structlog` (pretty console in dev, JSON in tbd/prd).
- `RequestIdMiddleware` injects `request_id` into log context per request; echoes `X-Request-ID` response header.
- Provider boundaries get bound loggers (`logger = structlog.get_logger("provider.email.ses")`).

### 4.3 Roll-your-own JWT auth
- Endpoints (all under `/api/v1/auth`):
  - `POST /signup` — email + password (bcrypt cost 12), terms-agreed required.
  - `POST /login` — returns `access_token` + `refresh_token`.
  - `POST /refresh` — exchange refresh token for a new access token.
  - `POST /logout` — revokes the refresh token.
  - `POST /forgot-password` → calls `EmailProvider.send_password_reset(...)`.
  - `POST /reset-password`.
  - `POST /oauth/apple` and `POST /oauth/google` — **only mounted when `environment != "dev"`**.
- JWT: HS256, `JWT_SECRET` from env. Defaults: 60-min access, 30-day refresh (configurable).
- Schema migration: drop `firebase_uid`, add `password_hash`, `auth_method` (`email`/`apple`/`google`), `apple_id`, `google_id`, `agreed_to_terms`, `agreed_to_privacy`, `terms_agreed_at`.
- Replace `app/api/dependencies/auth.py`: verifies own JWT; deletes Firebase init and the dev mock-user shortcut.

### 4.4 Dev quality-of-life
- `scripts/seed_dev_user.py` — creates `dev@drape.local` / `password` so contributors can `docker-compose down -v` without losing their dev account every time.

### 4.5 Verify
- Dev: `POST /signup` → `POST /login` → `GET /users/me` round-trip works.
- Tbd: same plus a real Apple/Google ID token verifies via `OAuthVerifier` and JIT-creates the user.
- `ENVIRONMENT=tbd uvicorn ...` without `JWT_SECRET` → fails at startup with a pydantic validation error.
- Pretty logs in dev; switch to `ENVIRONMENT=tbd` and logs become JSON.
- `X-Request-ID` round-trips on every request.

---

## 🧬 Phase 5: Onboarding Domain — Schema, Profile, Measurements, Avatar, Starter Wardrobe

**Goal:** Implement the data model and APIs the CTO onboarding flow needs.

### 5.1 Schema reshape (Alembic migration)
- Reshape `users` to match the CTO doc: drop the separate `profiles` table; merge `first_name`, `last_name`, `shopping_style`, `age_range`, `style_goals` (JSONB), `onboarding_completed`, `onboarding_last_step`, `onboarding_started_at`, `onboarding_completed_at` into `users`.
- New tables: `user_measurements`, `starter_wardrobe_templates`, `user_starter_wardrobes`, `user_avatars`. Column-level detail in CTO doc.

### 5.2 Profile API
- `POST /profile/shopping-style`, `POST /profile/age-range` (optional), `POST /profile/style-goals` (multi-select, min 1).
- `GET /profile/onboarding-status` — returns last completed step + next step.
- `POST /profile/save-progress` — checkpoint mid-flow.

### 5.3 Measurements API + encryption
- `POST /profile/measurements` — accepts metric or imperial; service normalizes to cm/kg.
- `Encryptor` interface (AES-256-GCM):
  - Dev: key from `MEASUREMENT_DEK_DEV`.
  - Tbd/prd: KMS envelope encryption with per-user DEK; wrapped DEK stored in `user_measurements.encryption_key_id`.
- Service encrypts before insert, decrypts on read; routes never see ciphertext.

### 5.4 Avatar
- `POST /avatar/generate` — synthesizes parametric 2D avatar from measurements + shopping_style; uploads to S3 in `ca-central-1`; returns CDN URL.

### 5.5 Starter wardrobe
- Seed `starter_wardrobe_templates` from `backend/data/starter_wardrobe_templates.json`.
- `POST /starter-wardrobe/assign` — picks a template based on `shopping_style` × `age_range`.
- `GET /starter-wardrobe/user/{user_id}` — returns the assigned template's items.

### 5.6 Verify
- End-to-end: `signup` → `shopping-style` → `style-goals` → `measurements` → `avatar` → `onboarding-status` returns `next_step: today_dashboard`.
- Inspect DB: `user_measurements` ciphertext columns are not readable as plaintext.

---

## 🧠 Phase 6: AI Service Layer — Outfit Generation

**Goal:** First Claude-powered feature — outfit recommendations for the Today Dashboard.

### 6.1 `AIProvider` interface
```python
class AIProvider(ABC):
    @abstractmethod
    async def generate_outfits(
        self, profile: ProfileContext, wardrobe: list[Item], context: OutfitContext
    ) -> OutfitSet: ...

    @abstractmethod
    async def chat(self, messages: list[Message], *, model: str | None = None) -> str: ...
```

### 6.2 `AnthropicProvider`
- Uses official `anthropic` SDK (`pip install anthropic`).
- Default model `claude-sonnet-4-6`; switch to `claude-opus-4-7` per request when intelligence > latency.
- System prompt for fashion-stylist persona; uses Anthropic tool-use for structured output.
- Token usage logged (`input_tokens`, `output_tokens`, `model_id`) on every call.

### 6.3 Outfit Generation API
- `POST /outfits/generate` — authed; optional `OutfitContext` (weather, occasion, dress code); returns 3 outfits drawn from the user's wardrobe + starter wardrobe.
- `GET /outfits/{id}` (self-or-admin), `GET /outfits` (paginated history).

### 6.4 Persistence (`outfit_generations` table)
`user_id` FK, `context_json`, `response_json`, `model_id`, `input_tokens`, `output_tokens`, timestamps.

### 6.5 Verify
- Local request to `POST /outfits/generate` returns 3 outfit objects, each grounded in the user's actual wardrobe items.
- Token usage logged with `request_id` + `user_id`.

---

## ☁️ Phase 7: Cloud Deployment (AWS, `ca-central-1`)

1. **RDS for PostgreSQL** in `ca-central-1`.
2. **KMS** key for measurement encryption (per-user DEKs).
3. **SES** in `ca-central-1` for password-reset emails.
4. **S3** in `ca-central-1` for avatar images; CloudFront in front.
5. **ECR + ECS Fargate + ALB** for the API.
6. **Secrets Manager** for `JWT_SECRET`, `ANTHROPIC_API_KEY`, OAuth client secrets, DB credentials. Materialized into `.env` by the ECS task entrypoint before the container starts.
7. **CloudWatch Logs** for the JSON output from `structlog`.

---

## 📱 Phase 8: Mobile Client Integration (Flutter)

1. **Flutter setup:** create app under `/mobile`.
2. **Auto-generate API client** from the backend's `openapi.json` (e.g. `swagger_dart_code_generator`).
3. **Authentication UI:**
   - Native Apple Sign-In + Google Sign-In SDKs.
   - Email/password form for users not on iOS/Android social auth.
   - Token storage via `flutter_secure_storage`.
4. **Connect:** pass JWT in `Authorization: Bearer <token>` to every API call.

---

## 🔮 Future Plans

### pgvector & semantic search
Enable when a feature actually needs vector similarity (style-similar items, image-based search).
1. `CREATE EXTENSION IF NOT EXISTS vector;` on RDS.
2. Pick an embeddings provider — Anthropic doesn't host embeddings; pair Claude with [Voyage AI](https://www.voyageai.com/) (Anthropic's recommended companion) or self-host `sentence-transformers`.
3. Add `embedding` columns + Alembic migration; add an `EmbeddingProvider` interface alongside the existing providers.
4. Similarity queries via `Document.embedding.l2_distance(query_vec)`.

### Multi-region / DR
ca-central-1 → ca-west-1 read replicas; cross-region S3 replication for avatars; Route53 health-checked failover.

### MFA
TOTP (Authenticator app) on top of own-JWT, gated by user preference; new `MfaProvider` interface to also support WebAuthn later.

### Wardrobe scanning + image processing
Scanner UI is in the CTO doc but deferred from onboarding. Adds an `ImageProvider` (e.g. Rekognition or self-hosted CLIP) for clothing categorization, color extraction, fit detection.
