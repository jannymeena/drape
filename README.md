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
| Firebase project| —          | Only needed when `ENVIRONMENT` is `tbd` or `prd` (Phase 3 onwards)    |

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

## Environments and configuration

The app supports three environments, modeled after the Java/Node `dev` / `tbd` / `prd` convention:

| Env   | Default? | Auth                                | DB                                            |
|-------|----------|-------------------------------------|-----------------------------------------------|
| `dev` | yes      | Mock auth — bypasses Firebase       | Local docker-compose Postgres (`localhost:5433`) |
| `tbd` | no       | Real Firebase JWT verification      | Testbed RDS (URL set by deploy infra)         |
| `prd` | no       | Real Firebase JWT verification      | Production RDS (URL set by deploy infra)      |

Set the env via the `ENVIRONMENT` variable. Pydantic validates it at startup — anything other than `dev`, `tbd`, or `prd` fails fast.

### `.env` policy (same across all environments)

- `backend/.env` is **always gitignored** because it contains secrets.
- `backend/.env.example` is the canonical list of every key the app reads — copy it and fill in values.
- In `dev`: developers author `.env` locally.
- In `tbd` / `prd`: a deploy step (CI/CD job, ECS entrypoint, Secrets Manager sidecar) materializes `.env` on the container before the app starts. The Docker image itself never ships secrets.

| Variable                     | Required in            | Purpose                                                            |
|------------------------------|------------------------|--------------------------------------------------------------------|
| `ENVIRONMENT`                | all (default `dev`)    | One of `dev`, `tbd`, `prd`.                                        |
| `DATABASE_URL`               | all                    | Postgres connection string. Each env points at its own database.   |
| `FIREBASE_CREDENTIALS_PATH`  | `tbd`, `prd`           | Path to Firebase service-account JSON inside the container.        |
| `OPENAI_API_KEY`             | Phase 4+               | Set later when AI services come online.                            |

---

## Authentication during local development

When `ENVIRONMENT=dev`:
- Firebase verification is bypassed.
- A single mock user is JIT-provisioned on first authenticated request and reused thereafter.
- In Swagger, the **Authorize** dialog is satisfied by any value (or none) — the bearer token is ignored in dev.
- Multi-user dev (a real `/auth/local/login` flow) is planned but not yet built.

When `ENVIRONMENT=tbd` or `prd`:
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
docker compose logs -f db

# Shell into the database
docker compose exec db psql -U admin -d drape
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

**`firebase_admin` errors at startup in dev**
You shouldn't be initializing it in dev — confirm `ENVIRONMENT=dev` is actually set (`echo $ENVIRONMENT` from your venv shell, or check `.env`).

**App fails at startup with `FIREBASE_CREDENTIALS_PATH is required ...`**
You set `ENVIRONMENT=tbd` or `prd` without providing a service-account JSON path. Either set it, or drop back to `ENVIRONMENT=dev`.

**Swagger says 401 even with a valid token**
Confirm `ENVIRONMENT` matches the token issuer's project, and that `FIREBASE_CREDENTIALS_PATH` points at the service-account JSON for the same project.

**Port already in use**
The compose file maps Postgres to host port `5433` (not the default `5432`) to avoid conflicting with other local Postgres instances. If `5433` is also taken, change the left side of the `ports:` mapping in `docker-compose.yml` and update `DATABASE_URL` accordingly.
