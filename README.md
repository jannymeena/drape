# Drape

Enterprise AI B2C application — Flutter mobile client + FastAPI backend + PostgreSQL, deployed on AWS in `ca-central-1` (PIPEDA compliant). Auth is own-issued JWT; the AI layer talks to Anthropic Claude through a provider interface.

For the full roadmap see [`IMPLEMENTATION_PLAN.md`](./IMPLEMENTATION_PLAN.md). For step-by-step build instructions see [`PHASE_PLAN.md`](./PHASE_PLAN.md). The product contract for onboarding lives in [`CTO_Handoff_Onboarding_Flow.md`](./CTO_Handoff_Onboarding_Flow.md) — the backend implements that doc, doesn't improvise on it.

> **Current implementation state (May 2026):** Phases 1–3 are built, with Phase 3 using Firebase auth as scaffolding. Phase 4 will replace Firebase with own-JWT (PIPEDA / `ca-central-1` residency requirement). If you're contributing right now, the code uses Firebase; the architecture docs describe the target state we're moving toward in Phase 4.

---

## Repository layout

```text
drape/
├── backend/                  # FastAPI app
├── mobile/                   # Flutter app (Phase 8, not started)
├── docker-compose.yml        # Local Postgres
├── IMPLEMENTATION_PLAN.md    # Master plan (8 phases + Future Plans)
├── PHASE_PLAN.md             # Step-by-step build plan
├── CTO_Handoff_Onboarding_Flow.md  # Authoritative product contract
└── README.md
```

---

## Architecture principles

These are non-negotiable patterns. They are the FastAPI/Python equivalents of patterns used in Spring Boot:

1. **Provider pattern** — anything with a different impl per env (`AIProvider`, `EmailProvider`, `OAuthVerifier`, `Encryptor`, `PasswordHasher`) lives behind an `abc.ABC` interface and is wired by a startup `Providers` factory. Equivalent to `@Profile`-driven beans.
2. **Profile-specific config** — single `Settings` class via `pydantic-settings`; `ENVIRONMENT` selects which provider impls get registered.
3. **Structured logging** — `structlog` with per-request correlation IDs (`X-Request-ID`).
4. **Three-tier separation** — `routes/` → `services/` → `db/`. Routes never call DB; services never know about HTTP.
5. **Fail fast at startup** — required config / unreachable infra surfaces as a startup error, never as a 500 on first request.

See [`IMPLEMENTATION_PLAN.md`](./IMPLEMENTATION_PLAN.md#-architecture-principles) for detail.

---

## Prerequisites

| Tool             | Version | Notes                                                   |
|------------------|---------|---------------------------------------------------------|
| Python           | 3.11+   | Backend runtime                                         |
| Docker + Compose | latest  | Runs local Postgres (`pgvector/pgvector:pg16`)          |
| Git              | any     | —                                                       |
| Flutter          | stable  | Only needed for Phase 8                                 |

Optional:
- `direnv` — repo ships an `.envrc` that points `CLAUDE_CONFIG_DIR` at a project-local Claude Code config.
- `psql` or DBeaver — handy for poking at the local DB.

---

## Quick start (local development)

If a step references a file or folder that doesn't exist yet, that phase hasn't been built — check `PHASE_PLAN.md` for current status.

### 1. Clone and enter the repo
```bash
git clone <repo-url> drape
cd drape
```

### 2. Set up the backend
```bash
cd backend
python -m venv .venv
source .venv/bin/activate          # Windows: .venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env               # then edit values as needed
```

### 3. Start Postgres
```bash
# from repo root
docker-compose up -d
```

### 4. Run migrations
```bash
cd backend
alembic upgrade head
```

### 5. Seed a dev user (Phase 4+)
```bash
python scripts/seed_dev_user.py
# creates dev@drape.local / password
```

### 6. Start the API
```bash
uvicorn app.main:app --reload
```

Open http://localhost:8000/docs — that's Swagger UI, your primary tool for exercising the API.

---

## Environments and configuration

The app supports three environments, modeled after the Java/Spring Boot `dev` / `tbd` / `prd` convention:

| Env   | Default? | Auth                              | DB                                                |
|-------|----------|-----------------------------------|---------------------------------------------------|
| `dev` | yes      | Own-JWT (signup/login/refresh); OAuth routes don't mount | Local docker-compose Postgres (`localhost:5433`) |
| `tbd` | no       | Own-JWT + Apple/Google OAuth      | Testbed RDS in `ca-central-1`                     |
| `prd` | no       | Own-JWT + Apple/Google OAuth      | Production RDS in `ca-central-1`                  |

Set the env via the `ENVIRONMENT` variable. Pydantic validates it at startup — anything other than `dev`, `tbd`, or `prd` fails fast.

### `.env` policy (same across all environments)

- `backend/.env` is **always gitignored** because it contains secrets.
- `backend/.env.example` is the canonical list of every key the app reads — copy it and fill in values.
- In `dev`: developers author `.env` locally.
- In `tbd` / `prd`: a deploy step (ECS task entrypoint, Secrets Manager sidecar) materializes `.env` on the container before the app starts. The Docker image itself never ships secrets.

### Variable reference

| Variable                     | Required in     | Purpose                                                   |
|------------------------------|-----------------|-----------------------------------------------------------|
| `ENVIRONMENT`                | all (default `dev`) | One of `dev`, `tbd`, `prd`.                           |
| `DATABASE_URL`               | all             | Postgres connection string.                               |
| `JWT_SECRET`                 | all *(default in dev)* | HS256 signing secret. From Secrets Manager in tbd/prd. |
| `JWT_ACCESS_TTL_MINUTES`     | optional        | Default 60.                                               |
| `JWT_REFRESH_TTL_DAYS`       | optional        | Default 30.                                               |
| `ANTHROPIC_API_KEY`          | all             | Claude API key (used by `AIProvider`).                    |
| `MEASUREMENT_DEK_DEV`        | `dev` only      | base64-encoded 32-byte AES key for `LocalAesEncryptor`.   |
| `KMS_KEY_ID`                 | `tbd`, `prd`    | KMS CMK ARN for measurement envelope encryption.          |
| `AWS_REGION`                 | `tbd`, `prd`    | Defaults to `ca-central-1`.                               |
| `SES_REGION`, `SES_FROM_ADDRESS` | `tbd`, `prd` | For password-reset emails (`SesEmailProvider`).           |
| `APPLE_CLIENT_ID`, `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY_PATH` | `tbd`, `prd` | Apple Sign-In server-side verification. |
| `GOOGLE_CLIENT_ID`           | `tbd`, `prd`    | Google ID token audience.                                 |

---

## Running the API in each environment

The same `uvicorn app.main:app` command runs in every env — only the values in `.env` change. Run all of these from `backend/` with the venv activated.

### `dev` — default, local Postgres, own-JWT, no OAuth

```bash
uvicorn app.main:app --reload
```

`dev` is the default, so no env var is required. If you prefer to be explicit, put it in `backend/.env`:

```ini
ENVIRONMENT=dev
DATABASE_URL=postgresql+psycopg2://admin:password@localhost:5433/drape
JWT_SECRET=dev-only-secret-change-me
ANTHROPIC_API_KEY=sk-ant-...
MEASUREMENT_DEK_DEV=<base64 32 bytes>
```

In dev: OAuth routes (`/auth/oauth/*`) don't mount. Email goes through `LogEmailProvider` (password-reset links land in your console). Measurement encryption uses a local AES key. Authenticate via `POST /auth/signup` then `POST /auth/login`.

### `tbd` — real OAuth, testbed RDS in `ca-central-1`

```bash
ENVIRONMENT=tbd uvicorn app.main:app
```

…with a `.env` containing the full key set (DB URL, `JWT_SECRET`, OAuth client IDs/secrets, KMS key ID, SES config, Anthropic key). Startup fails fast if any required key is missing.

### `prd` — production

Same shape as `tbd`, `ENVIRONMENT=prd`, pointed at production resources. In real deploys you don't run this by hand — the ECS task entrypoint materializes `.env` from Secrets Manager before launching the container.

### Sanity checks

- `ENVIRONMENT=staging uvicorn ...` → fails at startup (only `dev` / `tbd` / `prd` accepted).
- `ENVIRONMENT=tbd uvicorn ...` with no `JWT_SECRET` → fails at startup, not at first request.
- `backend/.env` must exist (copy from `.env.example`) — pydantic-settings reads it in every env.

---

## Authentication flow

When `ENVIRONMENT=dev`:
- No Firebase, no OAuth, no real email.
- Sign up via `POST /api/v1/auth/signup`, log in via `POST /api/v1/auth/login` to get an access + refresh token.
- Paste the access token into Swagger's **Authorize** dialog as `Bearer <token>`.
- For convenience, `python scripts/seed_dev_user.py` creates `dev@drape.local` / `password`.

When `ENVIRONMENT=tbd` or `prd`:
- Same `/auth/signup` and `/auth/login` work for email/password users.
- `/auth/oauth/apple` and `/auth/oauth/google` accept a platform-issued ID token, verify it server-side against the platform's JWKS, and return our own JWT.

See [`PHASE_PLAN.md`](./PHASE_PLAN.md) §4 for the full auth flow.

---

## Common commands

```bash
# Run the API with auto-reload
uvicorn app.main:app --reload

# Create a new migration after editing models
alembic revision --autogenerate -m "describe the change"
alembic upgrade head

# Roll back one migration
alembic downgrade -1

# Tail Postgres logs
docker compose logs -f db

# Shell into the database
docker compose exec db psql -U admin -d drape

# Seed dev user
python scripts/seed_dev_user.py
```

---

## Where we are

Each phase has explicit **Verify** criteria — when those pass, the phase is done. Track current progress against [`PHASE_PLAN.md`](./PHASE_PLAN.md).

- [x] Phase 1 — API skeleton
- [x] Phase 2 — Relational DB foundation
- [x] Phase 3 — Firebase auth *(superseded; replaced in Phase 4)*
- [ ] Phase 4 — Cross-cutting foundation: providers, logging, own-JWT
- [ ] Phase 5 — Onboarding domain (profile, measurements with AES-256, avatar, starter wardrobe)
- [ ] Phase 6 — AI service layer + outfit generation (Claude)
- [ ] Phase 7 — AWS deployment (`ca-central-1`)
- [ ] Phase 8 — Flutter client

**Future Plans** (not phased): pgvector + semantic search, multi-region failover, MFA, wardrobe scanning. See `IMPLEMENTATION_PLAN.md`.

---

## Troubleshooting

**`alembic upgrade head` fails with `relation does not exist` / `enum already exists`**
The migration history and DB schema have drifted. For local dev only: `docker-compose down -v` to nuke the volume, then `up -d` and re-run migrations.

**App fails at startup with a pydantic validation error about missing keys**
Some env-required key isn't set. The error message names which one. Either set it or drop back to `ENVIRONMENT=dev`.

**`401 Unauthorized` on every authed endpoint**
Either the access token is expired (refresh it via `POST /auth/refresh`) or the `JWT_SECRET` differs between the issuing and verifying processes (check `.env`).

**Port already in use**
The compose file maps Postgres to host port `5433` (not the default `5432`) to avoid conflicting with other local Postgres instances. If `5433` is also taken, change the left side of the `ports:` mapping in `docker-compose.yml` and update `DATABASE_URL` accordingly.

**Logs are JSON in dev (or pretty in tbd/prd)**
The structlog renderer is selected by `ENVIRONMENT` — confirm it's set to what you expect.
