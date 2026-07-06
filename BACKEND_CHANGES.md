# DRAPE — Backend Changes (Pending Tasks)

**Created:** 2026-07-05 · derived from the gap analysis of `CTO_Handoff_*.md` vs the codebase;
completed work (shipped 2026-07-05, 198 tests green) removed — record in git history.
**Reordered:** 2026-07-06 · execution order: Tier 1 buildable now → Tier 2 blocked on
keys/accounts → Tier 3 hardening + AWS deploy → optional last. The parking lot was dissolved
into the tiers. The 2D-avatar removal is confirmed but stays a **note** (see the Avatar note
at the end), not a scheduled task.
**Updated:** 2026-07-07 · the settings-privacy follow-on (old 1.3) was resolved with **no
backend work** — mobile dropped the Connected Apps rows (no integrations exist); Tier 1
renumbered. `ReasoningItem` gained `category`/`color_name` (additive, shipped with mobile P2).
Companion doc: `MOBILE_CHANGES.md`.

Schema convention (pre-prod): fold all new tables into the **single init migration**
(wipe local DB + regenerate), per the squash-don't-ALTER rule. Revert to additive
migrations once prd has real users.

---

## Tier 1 — Buildable now (no outside input)

### 1.1 Measurements → fit-summary consent path *(§5.5.1 — full design note below)*
- [ ] Server-side derived **fit profile** (body shape from chest/waist/hip ratio; height band;
      build) — exact cm never leave our infra.
- [ ] Separate opt-in consent flag + timestamp (default off; mirror `community_share_avatar`).
- [ ] Feed the derived block into the outfit prompt; ensure `ai_usage.jsonl` logs the derived
      block, not raw measurements.
- [ ] `DELETE /account` purges any cached derived fit profile.
- [ ] Privacy-policy line lands with MOBILE_CHANGES P4 (PIPEDA cross-border disclosure).
- Independent of the avatar removal (see the Avatar note).

### 1.2 User-local streak timing
- [ ] Monday 5 AM **local** reset per the Today handoff; streak math is currently UTC-pinned
      (the 2026-07-05 fix only de-flaked the tests).

### 1.3 Anthropic native prompt caching
- [ ] `cache_control` on the repeated outfit-gen prefix (~90% cheaper input tokens).

### 1.4 Reset-password URL default *(trivial)*
- [ ] Config default (`core/config.py`) still points at `https://drape.local/reset`; dev `.env`
      carries the `drape://` template. Set the real https App/Universal Link template at deploy
      time (Tier 3.2 step 7).

## Tier 2 — Blocked on keys/accounts — by build complexity

Each item is blocked on something only you can provide; listed smallest build first.

### 2.1 OAuth *(item 11a)* — blocked on: Apple/Google client IDs
- [ ] `RealOAuthVerifier` — Apple + Google JWKS verification (currently raises
      `NotImplementedError`; dev disables OAuth). Server-side token verification
      per the own-JWT design. Mobile buttons follow (MOBILE_CHANGES P2).

### 2.2 Stripe *(item 11c)* — blocked on: Stripe test keys + price IDs
- [ ] Real `StripeProvider` behind the existing `PaymentProvider` interface
      (webhook → subscription flip, customer portal). `MockPaymentProvider`
      covers dev end-to-end today.

### 2.3 Push delivery *(item 11d)* — blocked on: FCM/APNS project
- [ ] Real `ApnsFcmProvider` behind the existing `PushProvider` interface;
      APNS entitlement. (`LogPushProvider` covers dev; `devices` table +
      registration endpoints + `notify_user` fan-out already shipped.)
- [ ] The 18 spec'd campaigns (6 per tab doc: wardrobe nudges, limit warnings,
      price drops, win-back, renewal reminders) on the scheduler.
      Mobile client work follows (MOBILE_CHANGES P3).

### 2.4 AWIN affiliate *(item 11e)* — blocked on: affiliate account / data-source decision
- [ ] Real `AwinProvider` replacing the mock catalog `AffiliateProvider`
      (product data source is an open decision — seeded/mock vs real
      affiliate API).

### 2.5 Analytics *(decision 2026-07-05)* — blocked on: PostHog project + key
- [ ] Recommended: PostHog Flutter SDK direct-to-PostHog — **no backend work** beyond adding
      the project key to config. Only if we later want first-party capture does a `/events`
      proxy endpoint make sense. Mobile implements the events (MOBILE_CHANGES P1).

## Tier 3 — Production hardening & AWS deploy *(items 10a/10b/11b)*

**Nothing in this tier is built** — no Dockerfile, task definitions, IaC, or CI exist in the
repo yet; this is the target runbook. All resources in **`ca-central-1`** (PIPEDA); `tbd` and
`prd` fully isolated (separate VPC / RDS / KMS / ECS services), same image, different env vars.

### 3.1 Pre-deploy hardening *(item 10a)*
- [ ] Sanitize Pydantic `Settings` validation errors — they echo the input dict incl. secrets
      (memory: `project_pydantic_error_leak`).
- [ ] CORS: `allow_origins=["*"]` in `app/main.py` is dev-only — restrict per env.
- [ ] Rate-limit `/auth/login`, `/auth/forgot-password`, `/auth/reset-password` (unbounded today).
- [ ] Pagination caps; orphaned-image GC.
- [ ] WAF in front of the ALB; CloudWatch alarms (5xx rate, p95 latency, RDS CPU, free storage).
- [ ] RDS automated backups + a periodic manual snapshot; PITR in prd.
- [ ] SES domain out of sandbox before prd (tbd may stay sandboxed).

### 3.2 AWS infrastructure *(item 10b)* — first-time `tbd` setup, in order

| Component | Service |
|---|---|
| Registry / compute / LB | ECR → ECS Fargate behind an ALB (TLS terminator, health check `/api/v1/health`) |
| Database | RDS for PostgreSQL 16 (`pgvector` available; single-AZ tbd, multi-AZ prd) |
| Secrets / encryption | Secrets Manager + a KMS CMK per env (measurement envelope encryption) |
| Email / storage / logs | SES · S3+CloudFront (images) · CloudWatch Logs (structlog JSON with `request_id`) |

1. [ ] Account prep: MFA on root, IAM admin role, CLI profile; default region `ca-central-1`
       everywhere — spot-check before every console action (wrong region = accidental PIPEDA violation).
2. [ ] VPC: 2 private subnets (RDS) + 2 public (ALB) across 2 AZs; NAT gateway so tasks reach
       Anthropic / SES / Apple JWKS; SGs: ALB → task:8000, task → RDS:5432.
3. [ ] RDS PG16, DB `drape_tbd` (`db.t4g.medium` fine); master creds auto-created in Secrets Manager;
       then connect once (bastion/SSM) and `CREATE EXTENSION IF NOT EXISTS vector;`.
4. [ ] KMS CMK `alias/drape-tbd-measurements`; key policy: task role gets
       `kms:Encrypt/Decrypt/GenerateDataKey` only. Key ARN → `KMS_KEY_ID`.
5. [ ] SES: verify sending domain + `no-reply@` from-address → `SES_REGION`, `SES_FROM_ADDRESS`.
6. [ ] OAuth creds: Apple Service ID (e.g. `com.drape.app`) + `.p8` private key (record Team/Key IDs;
       `.p8` contents into Secrets Manager); Google OAuth clients (iOS + Android) — the backend only
       needs `GOOGLE_CLIENT_ID` as the audience (verification is JWKS-based).
7. [ ] Secrets Manager: one JSON secret per env (e.g. `drape/tbd/app`) holding the full `.env`
       envelope — `JWT_SECRET` (64-byte urlsafe), `DATABASE_URL`, `ANTHROPIC_API_KEY`, Apple/Google
       IDs, `SES_*`, `KMS_KEY_ID`, `AWS_REGION`, `PASSWORD_RESET_URL_TEMPLATE` (https App/Universal
       Link in prod). `backend/.env.example` is the canonical key list — everything in it must be
       present in the secret.
8. [ ] ECR repo `drape` + lifecycle policy (keep last N tagged, expire untagged after 7 days).
9. [ ] `backend/Dockerfile` — `python:3.11-slim` + `build-essential libpq-dev`, copy
       `app/ alembic/ alembic.ini scripts/`, `EXPOSE 8000`, `ENTRYPOINT scripts/entrypoint.sh`
       which materializes `.env` from Secrets Manager (`get-secret-value` → JSON → `.env` lines)
       before exec-ing `uvicorn app.main:app --host 0.0.0.0 --port 8000` — per the .env policy
       (the image never ships secrets).
10. [ ] Two task definitions per env, same image: **`drape-tbd-app`** (long-running, CPU 512 /
        mem 1024; task role: `secretsmanager:GetSecretValue` on `drape/tbd/*` + KMS on the CMK +
        `ses:SendEmail`; container health check `curl -f localhost:8000/api/v1/health`) and
        **`drape-tbd-migrate`** (one-shot, CMD `alembic upgrade head`).
11. [ ] First migration via `aws ecs run-task --task-definition drape-tbd-migrate` — wait for exit 0
        (alembic output in CloudWatch). Then create the service: 2 desired tasks, ALB target group,
        deployment circuit breaker on, rolling min/max 100/200%.
12. [ ] Smoke test: `/api/v1/health` 200 · OAuth route returns **401 not 404** (mounted in tbd,
        unlike dev) · `forgot-password` → 202 / SES delivery · CloudWatch shows JSON logs with
        `request_id` (pretty colored logs ⇒ `ENVIRONMENT` isn't `tbd`; fix before anything else).
13. [ ] DNS: Route53 alias `api-tbd.drape.app` → ALB; ACM cert `*.drape.app` on the listener.
14. [ ] Record every provisioned ARN (RDS, KMS, ECR, ECS service, secret) in `infra/`.

### 3.3 CI + release flow *(lands with 3.2)*
- [ ] CI on merge to master: `pytest` + `alembic upgrade head` against a throwaway Postgres →
      build/push `drape:tbd-<git-sha>` to ECR → update both task definitions.
- Release order, always: **run the migrate task first** (wait exit 0; if it fails, do NOT roll the
  service forward — forward-fix, push, retry), then
  `aws ecs update-service --force-new-deployment` (rolling; circuit breaker auto-rolls back on
  failed health checks).
- Promote to prd: re-tag the **same SHA**, run the prd migrate task, deploy — only after tbd has
  been green for a while; watch CloudWatch alarms ~10 min before walking away.
- Rollback: bad-but-healthy release → previous task-def revision; bad migration →
  **forward-fix, never `alembic downgrade`** in tbd/prd; compromised `JWT_SECRET` → rotate secret +
  `--force-new-deployment` + `UPDATE refresh_tokens SET revoked_at = now()`; compromised CMK →
  rotate (old ciphertexts decrypt via the old key version transparently).
- Day-2 ops: `aws logs tail /ecs/drape-tbd --follow` · Logs Insights `filter request_id = "..."` ·
  one-off SQL via SSM bastion only (never open RDS to the internet) · restart / pick up new secrets:
  `update-service --force-new-deployment` with no task-def change.

### 3.4 KMS envelope encryption *(item 11b)* — after 3.2
- [ ] Real `KmsEnvelopeEncryptor` + measurement DEK rotation (stub raises `NotImplementedError`;
      dev uses `LocalAesEncryptor` with `MEASUREMENT_DEK_DEV`).

## Optional / last

- [ ] **Outfit composite image generation** *(item 11f)* — `image_url` stays `null` by design;
      the client renders the 2×2 grid from item images. Build only if the product wants it.
- [ ] **Support attachments** — `POST /support/*` has no attachment field; mobile removed the
      Contact Us attach control on that basis (2026-07-07). Build (S3 upload + reference in
      `extra`) only if the product wants in-app screenshots on bug reports.
- **2FA + `PUT /account/phone`** — no design; cut for v1. Revisit only if a design lands.
  (The mocked 2FA switches were removed from mobile 2026-07-07.)

---

## 📝 Note — Avatar (confirmed for removal 2026-07-06; do NOT implement)

The **2D avatar** concept is being removed. Consequences for the backend, recorded here so
nobody builds against the handoff doc:

- The parametric `POST /avatar/generate` pipeline from the Onboarding handoff is
  **permanently N/A** — do not build it.
- What stays (for now) is the *photo* path: `POST /profile/avatar/upload` +
  `avatar_analysis.analyze_body` → `Profile.body_analysis` feeding the outfit prompt
  "Wearer:" block. When the removal work is scoped, decide whether body/skin analysis
  survives as a standalone **style photo** feature or goes too — it is the §5.5
  personalization link, so removing it silently would regress outfit quality
  (recommended: keep it).
- `user_avatars` / avatar fields cleanup happens with the removal work, not before
  (squash into the init migration when it does).
- The measurements→fit-summary path (Tier 1.1) is independent of the avatar and proceeds
  regardless. Mobile-side consequences are in the MOBILE_CHANGES avatar note.

## Design note — measurements → outfit personalization, the PIPEDA-safe way *(§5.5.1 — implements Tier 1.1)*

*(The photo half of §5.5 is built — body/skin from the uploaded photo → `Profile.body_analysis` →
outfit-prompt "Wearer:" block; its fate under the avatar removal is covered in the Avatar note.
This note is the design for the remaining, consent-gated half. POC reference: `cli_claude.py`.)*

`UserMeasurements` (`models.py`) stores height/weight/shoulders/chest/waist/inseam/hips as encrypted
ciphertext — personal, arguably *sensitive*, information under **PIPEDA** (the reason for
`ca-central-1` + own-JWT + encryption at rest). Feeding it to outfit generation means *decrypting* it
and *disclosing* it to a third-party US processor (Anthropic) — allowed, but only if **consented,
disclosed, and minimized** (PIPEDA hooks: consent, identified purpose, limiting use/disclosure,
safeguards, data minimization). Five points:

1. **Derive, don't disclose.** Convert raw measurements server-side into a coarse **fit profile**
   before the prompt: chest/waist/hip ratio → body shape (rectangle/triangle/inverted-triangle/
   hourglass); height band (petite/average/tall); build (slim/regular/broad) from shoulders+chest.
   Prompt gets e.g. *"Wearer: tall, athletic build, broad shoulders — favor structured fits"* —
   **exact cm never leave our infra** (matches the POC: it inferred body type, didn't ship numbers).
2. **Explicit, separate, opt-in consent** (default **off**): *"Use my measurements to personalize
   fit. We send a general body-shape summary (not exact measurements) to our AI provider."* Store
   consent flag + timestamp (mirror `community_share_avatar`).
3. **Raw numbers stay server-side only.** Decryption never leaves the backend; the AI usage log
   (`ai_usage.jsonl`) must capture the derived block, not raw measurements.
4. **Privacy-policy transparency.** One line: measurements may be used in derived/generalized form
   to personalize recs via a US-based AI processor (PIPEDA cross-border-transfer disclosure).
5. **Honor deletion.** `DELETE /account` must purge any cached derived fit profile alongside the
   encrypted measurements.
