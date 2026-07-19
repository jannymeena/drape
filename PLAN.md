# ZOURA — Plan & State Snapshot (written 2026-07-20, pre-session-clear)

Self-sufficient snapshot: everything a fresh session (or fresh memory) needs.
Detail lives in: `BACKEND_CHANGES.md` · `MOBILE_CHANGES.md` · `PRD_MIGRATION_CHECKLIST.md`
· `infra/README-tbd.md` (tbd runbook + all ARNs) · `CLAUDE.md` (conventions).

## Current state — tbd is DEPLOYED and 100% functional (2026-07-20)

Full app live at **https://api-tbd.zoura.style/api/v1** (health 200, HTTPS via Caddy/
Let's Encrypt). Verified end-to-end: signup, Google OAuth verifier, KMS measurement
encryption, S3 images, Stripe sandbox webhook, FCM wiring, and real SES email delivery
(password reset landed in developer@zoura.style).

### Key facts (memory-critical)

| Fact | Value |
|---|---|
| AWS | account `026481484029`, region `ca-central-1`, **CLI profile `zoura` always** (default profile = unrelated, never touch) |
| tbd stack | CloudFormation `zoura-tbd` (`infra/zoura-tbd.yaml`) + Ansible (`infra/ansible/`: `provision.yml`, `deploy.yml`) |
| Server | EC2 `i-08b68c1216cba7881` t4g.micro arm64, EIP **15.223.99.152**, SSH `~/.ssh/zoura-tbd.pem` (port 22 = home IP `123.231.87.221/32` only — if IP changes, redeploy stack with new `HomeIpCidr`) |
| Data | Postgres 16+pgvector on separate EBS `vol-06f9e1af480ec9b39` at `/data` (grow online); nightly pg_dump → `zoura-tbd-backups-026481484029` |
| Config | SSM Parameter Store `/zoura/tbd/*` (19 SecureStrings); change → `put-parameter` + `systemctl restart zoura`. tbd JWT_SECRET is freshly generated (dev .env still has placeholder) |
| Images | S3 `zoura-tbd-images-026481484029` (public-read; prd will be private+CloudFront) |
| KMS | `alias/zoura-tbd-measurements` = `arn:aws:kms:ca-central-1:026481484029:key/bfe01464-9d97-431b-8c25-2c975cfe5f7f` |
| Stripe | tbd webhook `we_1TuyOZLOZdriIeeP7YYP2ZZy` → `/billing/webhook/stripe`; whsec in SSM |
| Email | SES sandbox; domain `zoura.style` + `developer@zoura.style` verified. Mailboxes user can access: developer@ / info@ / support@zoura.style. Test user exists: developer@zoura.style |
| Features off in tbd | `DISABLED_FEATURES=apple_login,affiliate` (affiliate switch keeps mock catalog) |
| Deploy a backend change | `cd infra/ansible && ansible-playbook deploy.yml` |
| Costs | ~$13.75/mo 24/7 (IPv4 fee included); budget alert recommended at $15 |

### Decisions locked (don't re-litigate)
tbd = one EC2, native install (no Docker), Ansible; prd = separate ECS+ALB+RDS stack
(§3.2B), nothing migrated from tbd. Photos on S3, DB on its own EBS. No Cloudflare;
Namecheap A record → EIP. dev/tbd share keys; prd gets fresh ones. App Runner is dead
(legacy templates in infra/ superseded). DB naming: `zoura_tbd` / `zoura_prd`.

## Pending work, in suggested order

### Mobile (active front — MOBILE_CHANGES.md)
1. **Smoke run against tbd** (next!): `cd mobile && flutter run
   --dart-define=API_BASE_URL=https://api-tbd.zoura.style/api/v1` — signup, onboarding,
   measurements (real KMS), wardrobe scan (real AI + S3), outfit generation, reset email.
2. **P2 Google login button** — backend live; wire `GOOGLE_SERVER_CLIENT_ID` define, test on device.
3. **P3 Push (Android)** — Firebase `zoura-ec971` + google-services.json banked, backend FCM live; end-to-end device test never run. iOS blocked on Apple enrollment.
4. **P1 Analytics** — instrumentation done; needs a PostHog project + `POSTHOG_API_KEY`.
5. **P4 Release prep** — real Stripe card entry (flutter_stripe PaymentSheet), Sentry project + DSN, privacy/terms pages live on zoura.style, App/Universal Links for reset, visual diff pass, store uploads.

### Backend hardening (before outside testers — BACKEND_CHANGES §3.1)
- Sanitize pydantic Settings errors (echo secrets on bad boot), restrict CORS per env,
  rate-limit auth endpoints (obs half done: `auth.login_failed` + email_fp), pagination
  caps, orphaned-image GC. Optional: CloudWatch log shipping (journalctl fine meanwhile).

### Parked (blocked on external things)
- Apple login (Developer enrollment) · AWIN affiliate (no account) · SES production
  access + real card entry before any real users · **prd build** = §3.2B + the whole
  PRD_MIGRATION_CHECKLIST at go-live.

## Recent commits (all tests green: backend 344, mobile 140)
- `e396582` KMS envelope encryptor + affiliate feature switch
- `ed25377` mobile on-device image caching (cached_network_image)
- `f4a2cee` forgot-password 202 contract on mail-provider failure (found live on tbd)
