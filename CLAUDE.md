# DRAPE — Instructions for Claude

AI fashion stylist: Flutter mobile app (`mobile/`) + FastAPI backend (`backend/`) + Postgres.
Own-issued JWT auth (no Firebase — rejected for PIPEDA; everything targets AWS `ca-central-1`).
Environments follow the Spring-style `dev` / `tbd` / `prd` convention.

## Doc system — exactly five docs; do not create new root-level planning files

- `README.md` — orientation + the full local runbook (setup, run, test, reset, troubleshoot).
- `BACKEND_CHANGES.md` — backend task doc: open work by tier, deploy runbook, design notes.
- `MOBILE_CHANGES.md` — mobile task doc: gap-closure plan, release prep.
- `PRD_MIGRATION_CHECKLIST.md` — every go-live shadow task (vendor dashboards, live keys,
  DNS, legal). Whenever a dev/tbd step has a "redo this for live" twin, record it here at once.
- `CLAUDE.md` — this file.

New tasks/plans go into the two `*_CHANGES.md` docs. Product/design specs live in `handoff/`
(authoritative — implement them, don't improvise). Folder-local readmes under `backend/` and
`infra/` are left as-is.

## Commands

```bash
# Backend (venv at repo root; run from backend/)
source .venv/bin/activate && cd backend
uvicorn app.main:app --reload        # http://localhost:8000/docs
pytest                               # full suite
bash api_tests/run_all.sh            # smoke tests (needs running server + jq)
python scripts/reset_dev_db.py       # wipe + reseed dev data (dev-only)
python scripts/seed_dev_user.py      # dev@example.com / password1; prints token

# Mobile
cd mobile && flutter analyze && flutter test
cd mobile && flutter run             # backend must be running; Android emulator uses 10.0.2.2
```

## Conventions

Backend:
- **Three tiers, strictly:** `routes/` → `services/` → `db/`. Routes never touch the DB; services
  never know HTTP — they raise typed domain exceptions, routes map them to `HTTPException`.
- **Provider pattern** for anything env-specific (AI, email, OAuth, crypto, payments, push,
  affiliate): `abc.ABC` interface + per-env impls, wired only in `app/core/providers.py`.
  Inject via `Depends(...)`; never import the container from inside a service.
- **Config:** single pydantic-settings `Settings`; `backend/.env` is always gitignored;
  `.env.example` is the canonical key list; missing config fails at startup, never at request time.
- **Migrations (pre-prod): squash, don't ALTER** — fold schema changes into the single init
  migration and wipe/regenerate the local dev + test DBs. Switch to additive forward-only
  migrations once prd has real users.

Mobile:
- **Module-wise folders:** `modules/<feature>/` + `shared/`; every route is registered in
  `shared/providers/router_provider.dart`.
- **Expensive/AI calls fire one-by-one** from the client with per-success state updates —
  never batched into a single request.

## Commit policy

**Only ever commit files under `mobile/` or `backend/`. Nothing else.**

Root-level docs (`*_CHANGES.md`, `README.md`, `CLAUDE.md`), `handoff/`, `infra/`, dotfiles, and
anything outside those two folders stay uncommitted unless the user explicitly says otherwise.
Stage by explicit path (`git add mobile/... backend/...`) — never `git add -A` / `git add .`.
