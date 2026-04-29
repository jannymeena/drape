# Drape — Detailed Plan: Phases 1–3

This document expands Phases 1, 2, and 3 of [`IMPLEMENTATION_PLAN.md`](./IMPLEMENTATION_PLAN.md) into actionable, step-by-step instructions.

Phases 4–6 (AI/pgvector, AWS deployment, Flutter) remain as outlined in the master plan.

---

## Phase 1: API Skeleton (No DB, No Auth)

**Goal:** Lock down API contracts using Pydantic + FastAPI, served via Swagger with hardcoded responses.

### 1.1 Scaffold the backend folder

```text
backend/
├── app/
│   ├── __init__.py
│   ├── main.py                       # FastAPI() instance, router includes
│   ├── core/
│   │   ├── __init__.py
│   │   └── config.py                 # Settings via pydantic-settings
│   ├── api/
│   │   ├── __init__.py
│   │   └── routes/
│   │       ├── __init__.py
│   │       ├── health.py             # GET /health
│   │       └── users.py              # /users CRUD
│   └── schemas/
│       ├── __init__.py
│       └── user.py                   # UserBase, UserCreate, UserUpdate, UserResponse
├── requirements.txt
└── .env.example
```

### 1.2 Dependencies (`requirements.txt`)
- `fastapi`
- `uvicorn[standard]`
- `pydantic>=2`
- `pydantic-settings`

### 1.3 Define schemas (`app/schemas/user.py`)
- `UserBase` — shared fields (`email`, `display_name`)
- `UserCreate` — input for POST (extends Base)
- `UserUpdate` — all-optional fields for PATCH
- `UserResponse` — output (`id`, `email`, `display_name`, `role`, `created_at`)
- Use `model_config = ConfigDict(from_attributes=True)` to ease ORM transition in Phase 2

### 1.4 Build dummy routes (`app/api/routes/users.py`)
- `POST   /users`        → returns hardcoded `UserResponse` with `id=1`
- `GET    /users`        → returns list of 2 fake users
- `GET    /users/{id}`   → returns fake user with that id
- `PATCH  /users/{id}`   → echoes back merged data
- `DELETE /users/{id}`   → returns 204
- `GET    /health`       → `{"status": "ok"}`

### 1.5 Wire up `main.py`
- Create FastAPI app with title/version from `core.config`
- Include routers under `/api/v1` prefix
- Add CORS middleware (open for now, lock down later)

### 1.6 Verify
- `uvicorn app.main:app --reload` from `backend/`
- Hit `http://localhost:8000/docs`, exercise every endpoint
- **Exit criteria:** Swagger renders, all endpoints return 200/204 with the right shape

---

## Phase 2: Relational Database (Standard Tables)

**Goal:** Replace dummy data with real PostgreSQL-backed CRUD. Use the `pgvector/pgvector:pg16` image now so Phase 4 doesn't need a DB swap (no vector columns yet).

### 2.1 Local Postgres via docker-compose
- `docker-compose.yml` at repo root using `pgvector/pgvector:pg16`
- Persistent named volume so data survives restarts
- Healthcheck on `pg_isready`

### 2.2 New dependencies
- `sqlalchemy>=2`
- `alembic`
- `psycopg2-binary` (or `psycopg[binary]` for psycopg3)
- `python-dotenv` (or rely on `pydantic-settings`)

### 2.3 DB plumbing (`app/db/`)

```text
app/db/
├── __init__.py
├── base.py        # Base = declarative_base()
├── session.py     # engine, SessionLocal, get_db() generator
└── models.py      # SQLAlchemy ORM models
```

- Connection string from `core/config.py` (e.g. `DATABASE_URL`)
- `get_db()` is the FastAPI dependency yielding a session and closing on completion

### 2.4 Models (`app/db/models.py`) — no vectors yet

| Table        | Columns                                                                                                       |
|--------------|---------------------------------------------------------------------------------------------------------------|
| `users`      | `id` (PK), `firebase_uid` (unique, nullable for now), `email` (unique), `role` (enum), `is_active`, timestamps |
| `profiles`   | `id` (PK), `user_id` (FK→users, unique), `display_name`, `avatar_url`, `bio`, timestamps                       |

- `role` as a Python `enum.Enum` mapped to Postgres `ENUM` (`customer`, `admin`)
- Add `created_at` / `updated_at` via a `TimestampMixin`

### 2.5 Alembic
- `alembic init alembic` from `backend/`
- Edit `alembic/env.py`:
  - Import `Base` from `app.db.base` and `models` so autogenerate sees them
  - Pull `sqlalchemy.url` from env / settings
- Generate first migration: `alembic revision --autogenerate -m "init users and profiles"`
- Review the generated SQL by hand before running `alembic upgrade head`

### 2.6 Refactor routes to use real DB
- Replace dummy logic in `routes/users.py` with `Session.query` / `Session.add`
- Add a tiny CRUD layer in `app/services/user_service.py` so routes stay thin
- Handle 404 with `HTTPException` when row missing
- Convert ORM objects to `UserResponse` via `model_validate(orm_obj)`

### 2.7 Verify
- `docker-compose up -d`
- `alembic upgrade head` succeeds against an empty DB
- POST → GET → PATCH → DELETE round trip in Swagger persists across reloads
- **Exit criteria:** Restart uvicorn, data still there

---

## Phase 3: Authentication & Role-Based Access

**Goal:** Firebase JWT verification in production, mock user injection in local mode, role checks on protected routes.

### 3.1 Decide on env switch
- `ENVIRONMENT=dev` (default) → bypass Firebase, return mock user
- `ENVIRONMENT=tbd|prd` → verify real Firebase JWT
- Allowed values are constrained at startup via `Literal["dev", "tbd", "prd"]` in `core/config.py`
- `FIREBASE_CREDENTIALS_PATH` is required (validated at startup) when env is `tbd` or `prd`
- Document expected `.env` keys in `.env.example`

### 3.2 New dependencies
- `firebase-admin`

### 3.3 Auth dependency (`app/api/dependencies/auth.py`)
- Initialize `firebase_admin` lazily on first non-dev request (idempotent guard)
- `HTTPBearer(auto_error=False)` so dev requests can omit the header
- `get_current_user(creds, db)`:
  1. If `ENVIRONMENT == "dev"`: return a mock principal **and** upsert a corresponding user row so DB FKs work
  2. Else: `auth.verify_id_token(creds.credentials)` → extract `uid`, `email`
  3. Look up `users` row by `firebase_uid`; if missing, auto-create on first login (just-in-time provisioning)
  4. Return the ORM `User` (not just claims) — handlers get `current_user: User`
- On verify failure → `HTTPException(401, "Invalid or expired token")`

### 3.4 Role-based access
- `require_role(*allowed_roles)` factory returning a dependency:
  ```python
  def require_role(*roles):
      def checker(user: User = Depends(get_current_user)):
          if user.role not in roles:
              raise HTTPException(403, "Forbidden")
          return user
      return checker
  ```
- Apply to admin-only routes, e.g. `Depends(require_role(Role.admin))`

### 3.5 Update routes
- Public: `GET /health`
- Authenticated: `GET /users/me` (new — returns `current_user`)
- Self-or-admin: `PATCH /users/{id}` (check `id == current_user.id` or admin)
- Admin-only: `GET /users` (list), `DELETE /users/{id}`

### 3.6 Schema additions
- Make sure `firebase_uid` is indexed (already in 2.4)
- Optional: a `last_login_at` column updated on each authenticated request

### 3.7 Verify
- **Dev mode (`ENVIRONMENT=dev`):** Swagger "Authorize" with any string (or nothing), mock user gets injected, all endpoints work
- **Real mode (`ENVIRONMENT=tbd`):** Generate a Firebase ID token (emulator or a tiny Web SDK script), paste into Swagger, verify 200; corrupted token → 401; customer hitting admin route → 403
- **Exit criteria:** Same Swagger flow works under both `ENVIRONMENT=dev` and `ENVIRONMENT=tbd` with a real Firebase project

---

## Cross-cutting suggestions

- **Settings:** one `Settings` class in `core/config.py` with `DATABASE_URL`, `ENVIRONMENT`, `FIREBASE_CREDENTIALS_PATH`, `OPENAI_API_KEY` (placeholder for Phase 4) — fail fast at startup if a required value is missing in non-local envs.
- **Tests:** even a few `pytest` + `httpx.AsyncClient` smoke tests per phase will pay for themselves before Phase 5.
- **Dockerfile:** write it at the end of Phase 3 so Phase 5 has less to do.
