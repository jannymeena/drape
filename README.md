# Drape

Enterprise AI B2C application — Flutter mobile client + FastAPI backend + PostgreSQL, deployed on AWS in `ca-central-1` (PIPEDA compliant). Auth is own-issued JWT; the AI layer talks to Anthropic Claude through a provider interface.

**The four project docs:**

| Doc | Role |
|---|---|
| `README.md` (this file) | Orientation + the full local runbook: setup, run, test, reset, troubleshoot |
| [`BACKEND_CHANGES.md`](./BACKEND_CHANGES.md) | Backend task doc — open work by tier, deploy runbook, design notes |
| [`MOBILE_CHANGES.md`](./MOBILE_CHANGES.md) | Mobile task doc — gap-closure plan, release prep |
| [`PRD_MIGRATION_CHECKLIST.md`](./PRD_MIGRATION_CHECKLIST.md) | Every go-live shadow task: vendor dashboards, live keys, DNS, legal |
| [`CLAUDE.md`](./CLAUDE.md) | Conventions + commands for AI-assisted work |

Product/design specs live in `handoff/` (`CTO_Handoff_*.md` + screen mockups) — the authoritative contract per tab; the code implements those docs, it doesn't improvise on them.

> **Where we are (2026-07):** the backend API surface is shipped and the Flutter app is built and wired to it. The core happy path — signup → profile → measurements (encrypted) → avatar photo → wardrobe scan → Today outfits — runs end-to-end against real providers (Claude vision + chat, Open-Meteo weather); billing, shop, and push run on mock providers in dev. Backend suite: 198 pytest tests + 8 bash smoke scripts, green. Remaining work lives in the two task docs: backend Tier 3 (blocked on external keys: OAuth, Stripe, FCM/APNS, AWIN), Tier 4 (hardening + AWS deploy), and mobile release prep. **Current focus: the mobile app.** The product is rebranding to **Zoura** (`zoura.style`): the mobile client now carries the new display name, `style.zoura.mobile` bundle IDs, `zoura://` deep-link scheme, `zoura.style` links/emails, and Zoura user-facing copy (internal `Drape*` widget/class names deliberately kept). The matching backend/env/infra updates (`PASSWORD_RESET_URL_TEMPLATE`, `STRIPE_PORTAL_RETURN_URL`, SES sender, DNS/cert) come next.

---

## Repository layout

```text
drape/
├── backend/              # FastAPI app (routes → services → db)
├── mobile/               # Flutter app (modules/<feature>/ + shared/)
├── handoff/              # CTO handoff design specs + screen mockups (reference)
├── infra/                # test-deploy config (App Runner experiment)
├── docker-compose.yml    # Local Postgres (pgvector/pgvector:pg16, host port 5433)
├── BACKEND_CHANGES.md    # Backend task doc
├── MOBILE_CHANGES.md     # Mobile task doc
├── CLAUDE.md             # AI-assistant instructions
└── README.md
```

---

## Architecture principles

These are non-negotiable patterns — the FastAPI/Python equivalents of patterns used in Spring Boot:

1. **Provider pattern** — anything with a different impl per env (`AIProvider`, `EmailProvider`, `OAuthVerifier`, `Encryptor`, `PaymentProvider`, `PushProvider`, `AffiliateProvider`, …) lives behind an `abc.ABC` interface and is wired by a startup `Providers` factory (`app/core/providers.py`). Equivalent to `@Profile`-driven beans.
2. **Profile-specific config** — single `Settings` class via `pydantic-settings`; `ENVIRONMENT` selects which provider impls get registered.
3. **Structured logging** — `structlog` with per-request correlation IDs (`X-Request-ID` woven into every log line of that request).
4. **Three-tier separation** — `routes/` → `services/` → `db/`. Routes never call the DB; services never know about HTTP.
5. **Fail fast at startup** — required config / unreachable infra surfaces as a startup error, never as a 500 on first request.

### AI cost control (built)

Claude is billed per call, so repeat results are cached and every call is logged:

- **Vision cache** — `analyze_image` results are content-addressed in Postgres (`ai_response_cache`, key = `sha256(model + media_type + image_bytes + prompt)`) via the `CachingAIProvider` decorator (`app/services/providers/ai/caching.py`). The same garment photo never bills twice; DB errors degrade to a cache miss, never break a request.
- **Outfits** — `chat` is deliberately *not* cached: the Today dashboard generates the day's 3 outfits once and persists them in the `outfits` table; **Refresh** is an explicit regenerate (package-limited via usage tracking).
- **Usage log** — every AI call appends tokens/latency/cost to `backend/logs/ai_usage.jsonl` (`ai_usage_log.py`; per-model rates in `ai_pricing.py` — flip `ANTHROPIC_MODEL` and cost stays correct).
- Anthropic native prompt caching (`cache_control`) is deferred — see the BACKEND_CHANGES parking lot.

---

## Prerequisites

| Tool             | Version | Notes                                                  |
|------------------|---------|--------------------------------------------------------|
| Python           | 3.11+   | Backend runtime                                        |
| Docker + Compose | latest  | Runs local Postgres (`pgvector/pgvector:pg16`)         |
| Flutter          | stable  | Mobile app                                             |
| Git              | any     | —                                                      |

Optional: `jq` (bash smoke tests), `psql` or DBeaver (poking at the DB), `direnv` (the repo ships an `.envrc`).

---

## Quick start (backend)

### 1. Clone and set up

```bash
git clone <repo-url> drape
cd drape

python -m venv .venv                       # venv lives at the repo root
source .venv/bin/activate                  # Windows: .venv\Scripts\activate
pip install -r backend/requirements.txt

cp backend/.env.example backend/.env       # then fill in values (see below)
```

`.env` needs at minimum `ANTHROPIC_API_KEY` and `MEASUREMENT_DEK_DEV`. Generate a DEK:

```bash
python -c 'import os, base64; print(base64.b64encode(os.urandom(32)).decode())'
```

### 2. Start Postgres, migrate, seed

```bash
docker compose up -d                       # from repo root; Postgres on host port 5433
cd backend
alembic upgrade head                       # the squashed init migration also seeds starter-wardrobe templates
python scripts/seed_dev_user.py            # dev@example.com / password1 (idempotent); prints a 24h access token
```

### 3. Run

```bash
uvicorn app.main:app --reload              # must run from backend/ so app.main resolves and .env loads
```

| URL                                 | What it is                                        |
|-------------------------------------|---------------------------------------------------|
| http://localhost:8000/docs          | Swagger UI — primary tool for exercising the API  |
| http://localhost:8000/redoc         | ReDoc — same spec, alt presentation               |
| http://localhost:8000/openapi.json  | OpenAPI spec                                      |
| http://localhost:8000/api/v1/health | Healthcheck                                       |

**Authenticating in Swagger:** run `seed_dev_user.py` (or `POST /auth/signup` from the docs UI), copy the access token, click **Authorize**, paste it *without* the `Bearer ` prefix — Swagger adds it.

---

## Running the Flutter app

```bash
cd mobile
flutter run          # keep uvicorn --reload running in another terminal
```

Base URL per target:

| Target | Base URL | Notes |
|---|---|---|
| iOS simulator | `http://localhost:8000/api/v1` | simulator shares the host network |
| Android emulator | `http://10.0.2.2:8000/api/v1` | `10.0.2.2` = emulator's alias for host `localhost` |
| Physical device | `http://<your-LAN-ip>:8000/api/v1` | run uvicorn with `--host 0.0.0.0`; device + machine on the same Wi-Fi |

The auth handshake: `POST /auth/signup` or `/auth/login` → `{access_token, refresh_token}`; `Authorization: Bearer <access>` on every call; on 401 the dio interceptor calls `POST /auth/refresh-token` (rotates — store the new one), retries once, then routes to login. Tokens live in `flutter_secure_storage`. DTOs are hand-written (OpenAPI codegen is parked — see MOBILE_CHANGES).

---

## Environments and configuration

Three environments, modeled after the Java/Spring Boot `dev` / `tbd` / `prd` convention:

| Env   | Default? | Auth                                                     | DB                                               |
|-------|----------|----------------------------------------------------------|--------------------------------------------------|
| `dev` | yes      | Own-JWT (signup/login/refresh); OAuth routes don't mount | Local docker-compose Postgres (`localhost:5433`) |
| `tbd` | no       | Own-JWT + Apple/Google OAuth                             | Testbed RDS in `ca-central-1`                    |
| `prd` | no       | Own-JWT + Apple/Google OAuth                             | Production RDS in `ca-central-1`                 |

Set via `ENVIRONMENT`. Pydantic validates at startup — anything other than `dev` / `tbd` / `prd` fails fast.

### `.env` policy (same across all environments)

- `backend/.env` is **always gitignored** — it contains secrets.
- `backend/.env.example` is the canonical list of every key the app reads.
- In `dev`: developers author `.env` locally.
- In `tbd` / `prd`: a deploy step materializes `.env` from Secrets Manager on the container before the app starts (see BACKEND_CHANGES Tier 4). The Docker image itself never ships secrets.

### Variable reference

| Variable                     | Required in            | Purpose                                                |
|------------------------------|------------------------|--------------------------------------------------------|
| `ENVIRONMENT`                | all (default `dev`)    | One of `dev`, `tbd`, `prd`.                            |
| `DISABLED_FEATURES`          | optional               | Comma-separated feature switches to turn **off**: `apple_login`, `google_login`, `billing`, `push`. See below. |
| `DATABASE_URL`               | all                    | Postgres connection string.                            |
| `JWT_SECRET`                 | all *(default in dev)* | HS256 signing secret. From Secrets Manager in tbd/prd. |
| `JWT_ACCESS_TTL_MINUTES`     | optional               | Default 60.                                            |
| `JWT_REFRESH_TTL_DAYS`       | optional               | Default 30.                                            |
| `ANTHROPIC_API_KEY`          | all                    | Claude API key (used by `AIProvider`).                 |
| `ANTHROPIC_MODEL`            | optional               | Model override (dev default: Haiku).                   |
| `MEASUREMENT_DEK_DEV`        | `dev` only             | base64 32-byte AES key for `LocalAesEncryptor`.        |
| `PASSWORD_RESET_URL_TEMPLATE`| optional               | Dev: `drape://drape.app/auth/reset-password?token={token}`; https App/Universal Links in prod. |
| `KMS_KEY_ID`                 | `tbd`, `prd`           | KMS CMK ARN for measurement envelope encryption.       |
| `AWS_REGION`                 | `tbd`, `prd`           | Defaults to `ca-central-1`.                            |
| `SES_REGION`, `SES_FROM_ADDRESS` | `tbd`, `prd`       | Password-reset emails (`SesEmailProvider`).            |
| `APPLE_CLIENT_ID`, `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY_PATH` | `tbd`, `prd` — unless `apple_login` is disabled | Apple Sign-In server-side verification. `APPLE_CLIENT_ID` may be comma-separated (bundle ID + Service ID). |
| `GOOGLE_CLIENT_ID`           | `tbd`, `prd` — unless `google_login` is disabled | Google ID token audience. May be comma-separated (iOS + Android client IDs). |
| `STRIPE_API_KEY`, `STRIPE_WEBHOOK_SECRET`, `STRIPE_PRICE_ID_PRO_MONTHLY`, `STRIPE_PRICE_ID_PRO_YEARLY` | `tbd`, `prd` — unless `billing` is disabled | Real payments (`StripeProvider`). Dev: keyless → `MockPaymentProvider`; full key set → real sandbox Stripe (see "Real Stripe billing in dev"). Webhook: `POST /api/v1/billing/webhook/stripe` (subscribe `invoice.paid`, `invoice.payment_failed`, `customer.subscription.deleted`). |
| `STRIPE_PORTAL_RETURN_URL`   | optional               | Customer-portal return target (default: `drape://drape.app/billing`). |
| `FCM_CREDENTIALS_JSON`       | `tbd`, `prd` — unless `push` is disabled | Firebase service-account JSON (raw or base64) for FCM HTTP v1; FCM relays iOS to APNS via the `.p8` uploaded to the Firebase project. Dev logs via `LogPushProvider`. |

The same `uvicorn app.main:app` command runs in every env — only the `.env` values change. Sanity checks: `ENVIRONMENT=staging` → fails at startup; `ENVIRONMENT=tbd` with no `JWT_SECRET` → fails at startup, not at first request.

### Feature switches (`DISABLED_FEATURES`)

Per-feature kill switches, Spring `@ConditionalOnProperty`-style. Known names: `apple_login`, `google_login`, `billing`, `push` (an unknown name refuses to boot, so typos can't silently leave a feature on). Default: empty — everything enabled.

```bash
DISABLED_FEATURES=apple_login,google_login   # OAuth off
DISABLED_FEATURES=billing,push               # Stripe off (endpoints answer 400) + push off (sends become logged no-ops)
```

Semantics:
- A disabled feature's config keys are **not required at startup** — e.g. `tbd` can boot without `APPLE_CLIENT_ID`, the `STRIPE_*` keys, or `FCM_CREDENTIALS_JSON` while those accounts are pending.
- User-facing endpoints answer **400** with a typed code (`oauth_unavailable` / `billing_unavailable` — the same contract mobile already handles in dev). `push` is the exception: sends are server-initiated, so disabling it turns the `notify_user` fan-out into a logged no-op while device registration keeps collecting tokens.
- Dev is not affected by the switches for providers it already mocks (`MockPaymentProvider` and `LogPushProvider` stay; OAuth stays off).
- Read **once at boot**: flipping a flag means restarting the server (dev) or updating the secret + `aws ecs update-service --force-new-deployment` (tbd/prd — rolling, zero downtime).

### Mobile build-time keys (`--dart-define`)

Client config is injected at **build time** (`String.fromEnvironment`), sourced from a gitignored `mobile/.env` passed with `--dart-define-from-file=.env` — the mobile mirror of the backend `.env` convention (`mobile/.env.example` is the canonical key list; CI materializes the real file from the secrets manager). All keys are **optional**; each is gated by key presence, so a plain `flutter run` without the flag is a valid keyless build (analytics log to the console, OAuth buttons stay hidden). Feature names in `DISABLED_FEATURES` mirror the backend's.

| Key                       | Purpose                                                                                                   |
|---------------------------|-----------------------------------------------------------------------------------------------------------|
| `POSTHOG_API_KEY`         | PostHog project key. Absent → the debug/log sink is used and **nothing leaves the device**. Present → the real `PosthogAnalyticsService`. |
| `POSTHOG_HOST`            | PostHog ingestion host. Defaults to `https://us.i.posthog.com`; set for EU/self-host.                     |
| `SENTRY_DSN`              | Sentry DSN. Absent → the no-op crash sink is used (**nothing leaves the device**; uncaught errors still print). Present → uncaught errors are reported to Sentry. |
| `SENTRY_ENVIRONMENT`      | Deployment tag on Sentry events. Defaults by build mode (`release`/`debug`); set to `tbd`/`prd` per backend target. |
| `GOOGLE_SERVER_CLIENT_ID` | Google OAuth server client ID; must equal one of the backend's `GOOGLE_CLIENT_ID` audiences. Absent → the Google button is hidden. |
| `DISABLED_FEATURES`       | Client mirror of the backend switch: `apple_login`, `google_login` hide their buttons (and the divider).  |

```bash
# Keyed build (real analytics + crash reporting + OAuth): put keys in
# mobile/.env (copy from .env.example, gitignored) and pass the file
flutter run --dart-define-from-file=.env
flutter build apk --release --dart-define-from-file=.env

# Individual --dart-define flags still work and override the file
flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=xxx.apps.googleusercontent.com
```

---

## Authentication flow

When `ENVIRONMENT=dev`:
- No Firebase, no OAuth, no real email. `auth_method=apple|google` returns 400 `oauth_unavailable`; password-reset links land in the console via `LogEmailProvider`.
- Sign up via `POST /api/v1/auth/signup`, log in via `POST /api/v1/auth/login` (`auth_method=email`) to get an access + refresh token pair.
- Access = JWT (HS256, 60 min TTL). Refresh = opaque random string, hashed in `refresh_tokens`, **rotates on every refresh** (old one revoked) — that's why it isn't a JWT: revocation must work.

When `ENVIRONMENT=tbd` / `prd`:
- `/auth/signup` and `/auth/login` also accept `auth_method=apple|google` with the platform-issued `id_token`; the server verifies it against the platform's JWKS and returns our own JWT pair. OAuth signup and login are idempotent get-or-create — the client picks the endpoint by which screen fired.
- Either provider can be switched off via `DISABLED_FEATURES` (see Feature switches above) — its sign-in then answers 400 `oauth_unavailable` while the other provider and email auth keep working.

---

## Resetting the dev DB

Two flavors — use the lightest one that fixes your problem:

**Routine cleanup** (fastest; no docker churn):

```bash
cd backend && python scripts/reset_dev_db.py
```

Truncates every app table (CASCADE, RESTART IDENTITY), re-seeds the 6 starter-wardrobe templates + dev user, prints a fresh token. Preserves schema, indexes, enum types, and `alembic_version`. Refuses to run unless `ENVIRONMENT=dev`. Note: previously issued tokens belong to users that no longer exist — re-run `seed_dev_user.py`.

**Full wipe** (schema drift, Alembic debugging, or after squashing the init migration):

```bash
docker compose down -v && docker compose up -d       # nukes the drape_pgdata volume
cd backend && alembic upgrade head && python scripts/seed_dev_user.py
```

---

## Testing

Three complementary backend layers plus the Flutter suite:

| Layer | Question it answers | Where |
|---|---|---|
| **Pytest suite** (198 tests) | "Did I break the API contract?" — error codes, body shapes, edge cases | `backend/tests/` |
| **Bash + curl smoke tests** | "Does this endpoint work end-to-end?" — doubles as living docs | `backend/api_tests/` |
| **Per-phase verify scripts** | "Does the provider integration contract still pass?" | `backend/scripts/verify_phase_*.py` |
| **Flutter tests** | Widget/controller regressions | `mobile/test/` |

**One-time setup** (creates the `drape_test` DB):

```bash
cd backend
pip install -r requirements-dev.txt
bash tests/init_test_db.sh
```

**Pytest cookbook** (from `backend/` with the venv active):

```bash
pytest                                     # whole suite
pytest tests/api/routes/test_outfits.py   # one file
pytest -k "log_worn or favorite"          # name pattern
pytest -x                                 # stop on first failure
pytest --lf                               # only last run's failures
pytest -s                                 # show stdout/log even on pass
pytest --cov=app --cov-report=term-missing            # coverage
pytest --cov=app --cov-report=html && open htmlcov/index.html
```

How tests stay isolated: a separate `drape_test` DB (`conftest.py` sets `DATABASE_URL` before app imports and refuses URLs without "test" in them); every table is truncated after each test; AI/weather/image providers are swapped via `app.dependency_overrides` (`_CannedAIProvider` — offline, deterministic); tokens are minted directly via `create_access_token` for speed. After squashing migrations, re-init the schema: `psql "postgresql://admin:password@localhost:5433/postgres" -c "DROP DATABASE drape_test"` then `bash tests/init_test_db.sh`.

**Smoke tests** (need a running server; `curl` + `jq`):

```bash
bash api_tests/run_all.sh             # resets the DB, runs 01–08, exits non-zero on first failure
bash api_tests/04_wardrobe.sh         # one resource group (after `bash api_tests/reset.sh` once)
```

Scripts: `01_auth` `02_profile` `03_starter_wardrobe` `04_wardrobe` `05_today` `06_outfits` `07_usage` `08_analytics`. Read one and you've learned that resource's API — the request bodies are the canonical examples. Full reference: `backend/api_tests/README.md`.

**Verify scripts** (offline, canned providers): `python scripts/verify_phase_6a.py` … `6d.py` — AI/weather providers, scanner, outfit generation, usage limits.

**Flutter:**

```bash
cd mobile
flutter analyze && flutter test
```

**Tip — flip the dev user to Pro** (to exercise Pro-gated UI without the paywall):

```bash
docker compose exec db psql -U admin -d drape -c "UPDATE users SET subscription_tier='pro' WHERE email='dev@example.com'"
```

### Real Stripe billing in dev (sandbox)

Dev selects the payment provider by key presence (same rule as OAuth): a keyless
`.env` keeps `MockPaymentProvider`; setting `STRIPE_API_KEY` + both
`STRIPE_PRICE_ID_*` wires the real `StripeProvider` against the sandbox. The
first charge needs a card on file — the app's card form is mock-era, so attach
Stripe's test card via the API:

```bash
# terminal 1 — webhook bridge (prints the whsec_… for STRIPE_WEBHOOK_SECRET)
stripe listen --forward-to localhost:8000/api/v1/billing/webhook/stripe

# terminal 2 — card on file, then upgrade (or upgrade from the app)
TOKEN=<seed_dev_user token>
curl -X POST localhost:8000/api/v1/payment-methods -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" -d '{"token": "pm_card_visa"}'
curl -X POST localhost:8000/api/v1/subscription/upgrade -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" -d '{"plan": "pro_monthly"}'
```

**Renewal / dunning webhooks — `scripts/stripe_test_clock.py`** (dev-only). The
interesting lifecycle (`invoice.paid` renewals, `invoice.payment_failed`,
`customer.subscription.deleted`) only fires as time passes, and a customer can
only join a Stripe *test clock* at creation — so the script builds a clocked
twin of the dev user and repoints the local subscription row at it:

```bash
python scripts/stripe_test_clock.py setup --plan pro_monthly   # clock + clocked customer/sub; cancels the app-created Stripe sub
python scripts/stripe_test_clock.py advance --days 31          # renewal invoice is CREATED (draft)…
python scripts/stripe_test_clock.py advance --days 1           # …and finalized + charged (Stripe's ~1h finalization lag)
python scripts/stripe_test_clock.py fail-next                  # swap in a declining card; next advance = payment_failed path
```

Needs uvicorn + `stripe listen` running. After the two advances, expect
`invoice.paid → 200` in the listener, `billing.webhook.renewed` in the server
log, a "Zoura Pro renewal" row in `GET /billing/history`, and
`current_period_end` extended. Everything the clock creates is sandbox junk
tied to the dev user; `reset_dev_db.py` + a fresh `setup` starts over.

---

## Adding a backend feature

The stack is strictly **routes → services → db**; adding a feature means walking it:

1. **Needs a per-env impl** (external provider)? Add an interface under `app/services/providers/<area>/base.py` + per-env impls, wire in `app/core/providers.py`. See `email/`, `oauth/`, `crypto/`, `ai/` for the shape.
2. **Schema** — edit `app/db/models.py`. Pre-prod convention: **squash, don't ALTER** — fold the change into the single init migration and wipe/regenerate the local DBs (dev + test). Once prd has real users, switch to additive forward-only migrations.
3. **Pydantic schemas** — request/response shapes under `app/schemas/<area>.py`; `Field(...)` constraints give free 422s.
4. **Service** — `app/services/<area>_service.py`: plain functions taking a `Session` + domain inputs, raising typed domain exceptions (`auth_service.py` with `AuthError(code, message)` is the canonical template).
5. **Route** — `app/api/routes/<area>.py`, registered in `app/main.py`. `Depends(get_current_user)` on every authed route; `require_role(Role.admin)` for admin.
6. **Providers via DI** — services take providers as kwargs; routes inject via `Depends(get_<provider>)`. Never reach into `app.core.providers.providers` from a service — it kills testability.
7. **Verify** — exercise via Swagger with the seeded token, inspect rows via `psql`, add pytest coverage.

Other conventions: no DB calls in routes; domain errors not HTTP in services; never log secrets; live endpoint list is Swagger (`/docs`), not a doc.

---

## Where things live

| What | Where |
|---|---|
| Route handlers | `backend/app/api/routes/` |
| Service layer | `backend/app/services/` |
| Provider interfaces + impls | `backend/app/services/providers/<area>/` |
| Provider container (env wiring) | `backend/app/core/providers.py` |
| Config + fail-fast validation | `backend/app/core/config.py` |
| SQLAlchemy models | `backend/app/db/models.py` |
| Alembic migrations | `backend/alembic/versions/` (one squashed init while pre-prod) |
| Pydantic schemas | `backend/app/schemas/` |
| AI usage/cost log | `backend/logs/ai_usage.jsonl` |
| Flutter feature modules | `mobile/lib/modules/<feature>/` |
| Flutter shared widgets/services/providers | `mobile/lib/shared/` |
| All Flutter routes | `mobile/lib/shared/providers/router_provider.dart` |

---

## Common commands

```bash
# Run the API with auto-reload (from backend/, venv active)
uvicorn app.main:app --reload

# New migration after editing models (pre-prod: squash into the init migration — see CLAUDE.md)
alembic revision --autogenerate -m "describe the change"
alembic upgrade head

# Wipe + reseed dev data (preferred over `alembic downgrade` while pre-prod)
python scripts/reset_dev_db.py

# Seed dev user (idempotent; prints a fresh 24h access token)
python scripts/seed_dev_user.py

# Postgres logs / shell
docker compose logs -f db
docker compose exec db psql -U admin -d drape

# Flutter
cd mobile && flutter run
cd mobile && flutter analyze && flutter test
```

---

## Troubleshooting

**`alembic upgrade head` fails with `relation already exists` / `type "user_role" already exists`**
Postgres enum types survive `op.drop_table` — common after a `downgrade`, and DB/migration history drift generally. Quickest dev fix is the full wipe (`docker compose down -v && docker compose up -d`, then migrate + seed). Less-nuclear: drop the enums manually (`DROP TYPE IF EXISTS user_role CASCADE; DROP TYPE IF EXISTS auth_method CASCADE;` via psql), then retry.

**Startup fails with a pydantic validation error about missing keys**
Some env-required key isn't set — the message names it. Set it or drop back to `ENVIRONMENT=dev`. `MEASUREMENT_DEK_DEV` missing → generate one (command in Quick start). `ENVIRONMENT=staging` (or anything not `dev`/`tbd`/`prd`) is rejected by design.

**`401 Unauthorized` on every authed endpoint**
Either the access token expired (60 min — refresh via `POST /api/v1/auth/refresh-token`), or `JWT_SECRET` differs between issuing and verifying processes, or you ran `reset_dev_db.py` and the token's user no longer exists (re-run `seed_dev_user.py`).

**Swagger rejects the token**
Don't paste the `Bearer ` prefix into the Authorize box — Swagger adds it.

**Signup returns 400 `consent_required`**
`agreed_to_terms` and `agreed_to_privacy` must both be `true`.

**EmailStr rejects `dev@drape.local`**
`.local` / `.test` are reserved TLDs — use `example.com` in fixtures.

**pyjwt warns "HMAC key is N bytes, below the minimum 32"**
Locally overridden `JWT_SECRET` is too short; use ≥ 32 bytes.

**Port 5433 already in use**
Another local Postgres is bound (compose maps 5433, not 5432, to avoid the default). Edit the left side of `ports:` in `docker-compose.yml` and update `DATABASE_URL`.

**Server won't reload on file changes**
Confirm `--reload` and that you launched from `backend/` — the watch path is the cwd.

**A script says "refusing to seed" / "refusing to reset"**
`ENVIRONMENT` isn't `dev` — the destructive scripts are dev-only by design. Check `backend/.env`.

**Logs are JSON in dev (or pretty in tbd/prd)**
The structlog renderer is selected by `ENVIRONMENT` — confirm it's set to what you expect.
