# Drape

Enterprise AI B2C application — FastAPI backend, Flutter mobile client, PostgreSQL with `pgvector`, Firebase auth, deployed on AWS.

For the full roadmap see [`IMPLEMENTATION_PLAN.md`](./IMPLEMENTATION_PLAN.md). For the in-progress detailed plan covering the API skeleton, database, and auth, see [`PHASE_PLAN.md`](./PHASE_PLAN.md).

---

## Repository layout

```text
drape/
├── backend/                  # FastAPI app (Phases 1–3 in progress)
├── mobile/                   # Flutter app (Phase 6, not started)
├── docker-compose.yml        # Local Postgres (added in Phase 2)
├── IMPLEMENTATION_PLAN.md    # Master plan (all 6 phases)
├── PHASE_PLAN.md             # Detailed plan for Phases 1–3
└── README.md
```

> The `backend/` and `mobile/` folders are created as we work through the phases. If they're not there yet, that's expected.

---

## Prerequisites

| Tool            | Version    | Notes                                                                 |
|-----------------|------------|-----------------------------------------------------------------------|
| Python          | 3.11+      | Backend runtime                                                       |
| Docker + Compose| latest     | Runs local Postgres (`pgvector/pgvector:pg16`)                        |
| Git             | any        | —                                                                     |
| Flutter         | stable     | Only needed for Phase 6                                               |
| Firebase project| —          | Only needed when `ENVIRONMENT != local` (Phase 3 onwards)             |

Optional:
- `direnv` — the repo ships an `.envrc` that points `CLAUDE_CONFIG_DIR` at a project-local Claude Code config.
- `psql` or DBeaver — handy for poking at the local DB.

---

## Quick start (local development)

These steps will be valid as each phase lands. If a step references a file or folder that doesn't exist yet, that phase hasn't been built — check `PHASE_PLAN.md` to see where we are.

### 1. Clone and enter the repo
```bash
git clone <repo-url> drape
cd drape
```

### 2. Set up the backend (Phase 1+)
```bash
cd backend
python -m venv .venv
source .venv/bin/activate          # Windows: .venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env               # then edit values as needed
```

### 3. Start Postgres (Phase 2+)
```bash
# from repo root
docker-compose up -d
```

### 4. Run migrations (Phase 2+)
```bash
cd backend
alembic upgrade head
```

### 5. Start the API
```bash
# from backend/
uvicorn app.main:app --reload
```

Open http://localhost:8000/docs — that's Swagger UI, your primary tool for exercising the API.

---

## Environment variables

All env vars live in `backend/.env` (gitignored). A template `.env.example` is committed.

| Variable                     | Phase | Purpose                                                                |
|------------------------------|-------|------------------------------------------------------------------------|
| `ENVIRONMENT`                | 1     | `local` \| `dev` \| `prod`. `local` enables mock auth.                 |
| `DATABASE_URL`               | 2     | e.g. `postgresql+psycopg2://admin:password@localhost:5432/my_app_db`   |
| `FIREBASE_CREDENTIALS_PATH`  | 3     | Path to Firebase service-account JSON. Unused when `ENVIRONMENT=local`.|
| `OPENAI_API_KEY`             | 4     | Set later when AI services come online.                                |

**Never commit `.env`.** `.gitignore` already excludes it; double-check before pushing.

---

## Authentication during local development

When `ENVIRONMENT=local`:
- Firebase verification is bypassed.
- A mock user (`uid=mock_123`, role `customer`) is injected on every authenticated request.
- In Swagger, click **Authorize** and paste any non-empty string — it's ignored, but `HTTPBearer` requires a value.

When `ENVIRONMENT=dev` or `prod`:
- Generate a real Firebase ID token (e.g. via the Firebase Auth emulator or a small Web SDK script).
- Paste it into Swagger's **Authorize** dialog as `Bearer <token>`.

See `PHASE_PLAN.md` §3 for the full auth flow.

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
docker-compose logs -f db

# Shell into the database
docker-compose exec db psql -U admin -d my_app_db
```

---

## Where we are

Track current progress against `PHASE_PLAN.md`. Each phase has explicit **Exit criteria** — when those pass, that phase is done.

- [ ] Phase 1 — API skeleton (no DB, no auth)
- [ ] Phase 2 — Relational database
- [ ] Phase 3 — Auth & RBAC
- [ ] Phase 4 — AI & pgvector (see `IMPLEMENTATION_PLAN.md`)
- [ ] Phase 5 — AWS deployment
- [ ] Phase 6 — Flutter client

---

## Troubleshooting

**`alembic upgrade head` fails with `relation does not exist` / `enum already exists`**
The migration history and DB schema have drifted. For local dev only: `docker-compose down -v` to nuke the volume, then `up -d` and re-run migrations.

**`firebase_admin` errors at startup in local mode**
You shouldn't be initializing it locally — confirm `ENVIRONMENT=local` is actually set (`echo $ENVIRONMENT` from your venv shell, or check `.env`).

**Swagger says 401 even with a valid token**
Confirm `ENVIRONMENT` matches the token issuer's project, and that `FIREBASE_CREDENTIALS_PATH` points at the service-account JSON for the same project.

**Port 5432 already in use**
You probably have another Postgres running locally. Either stop it, or change the host port mapping in `docker-compose.yml`.
