# Drape test backend on AWS (App Runner + RDS)

Stands up an **internet-reachable, HTTPS** backend so you can exercise the
already-wired mobile features (auth, onboarding, today, wardrobe, profile)
against a real server instead of `localhost`.

This is a **test rig**, intentionally simpler than the Tier 3 production plan
in [`../BACKEND_CHANGES.md`](../BACKEND_CHANGES.md) (§3.2 — ECS Fargate + ALB +
Secrets Manager):

- Runs `ENVIRONMENT=dev`, so it boots **without any external keys** — no OAuth,
  SES, KMS, S3, Stripe, or FCM. Email is log-only, measurements use local AES,
  images use local-disk storage, billing uses `MockPaymentProvider`, and push
  uses `LogPushProvider`. (The `DISABLED_FEATURES` switches are a tbd/prd
  concern — dev always falls back to mocks, nothing to set here.)
- App Runner (managed container, free `*.awsapprunner.com` TLS) → RDS Postgres 16
  over a VPC connector. No ALB / CloudFront / Secrets Manager / multi-AZ.

**Region:** everything deploys to `ca-central-1` (PIPEDA). Keep your CLI on it.

Files:
- [`../backend/Dockerfile`](../backend/Dockerfile) + [`../backend/entrypoint.sh`](../backend/entrypoint.sh) — the image (entrypoint runs `alembic upgrade head`, which also seeds the starter-wardrobe templates, then `uvicorn`).
- [`drape-test-apprunner.yaml`](./drape-test-apprunner.yaml) — the stack.

---

## Prerequisites

- AWS CLI v2, authenticated to your account (`aws sts get-caller-identity`).
- Docker (with `buildx` — bundled in Docker Desktop).
- Python 3 locally (only to generate the two secrets below).

```sh
export AWS_REGION=ca-central-1
export AWS_DEFAULT_REGION=ca-central-1
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REPO=drape-backend
IMAGE_URI="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO:latest"
```

## 1. Generate secrets

```sh
JWT_SECRET=$(python3 -c "import secrets; print(secrets.token_urlsafe(64))")
MEASUREMENT_DEK=$(python3 -c "import os,base64; print(base64.b64encode(os.urandom(32)).decode())")
DB_PASSWORD=$(python3 -c "import secrets,string; print(''.join(secrets.choice(string.ascii_letters+string.digits) for _ in range(24)))")
echo "JWT_SECRET=$JWT_SECRET"; echo "MEASUREMENT_DEK=$MEASUREMENT_DEK"; echo "DB_PASSWORD=$DB_PASSWORD"
```
(Keep these — you'll pass them as stack parameters. `DB_PASSWORD` is alphanumeric on purpose, to keep the DATABASE_URL valid.)

## 2. Build + push the image to ECR

```sh
# Create the repo (one-time; ignore the error if it already exists).
aws ecr create-repository --repository-name "$ECR_REPO" >/dev/null 2>&1 || true

# Log Docker in to ECR.
aws ecr get-login-password | docker login --username AWS --password-stdin \
  "$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

# Build for App Runner's amd64 runtime. The --platform flag is REQUIRED on
# Apple Silicon — an arm64 image will fail to start on App Runner.
cd ../backend
docker build --platform linux/amd64 -t "$IMAGE_URI" .
docker push "$IMAGE_URI"
cd ../infra
```

## 3. Deploy the stack

```sh
aws cloudformation deploy \
  --template-file drape-test-apprunner.yaml \
  --stack-name drape-test \
  --capabilities CAPABILITY_IAM \
  --parameter-overrides \
      ImageUri="$IMAGE_URI" \
      DBPassword="$DB_PASSWORD" \
      JwtSecret="$JWT_SECRET" \
      MeasurementDek="$MEASUREMENT_DEK"
      # AnthropicApiKey="sk-ant-..."   # optional: real AI instead of the mock
```
RDS takes ~5–10 min the first time. The App Runner service then pulls the image,
runs migrations on boot, and goes healthy on `/api/v1/health`.

Read the outputs:
```sh
aws cloudformation describe-stacks --stack-name drape-test \
  --query "Stacks[0].Outputs" --output table
```

## 4. Smoke test

```sh
curl -s https://$(aws cloudformation describe-stacks --stack-name drape-test \
  --query "Stacks[0].Outputs[?OutputKey=='ServiceUrl'].OutputValue" --output text)/api/v1/health
# -> {"status":"ok"}  (or similar 200 body)
```

## 5. Make wardrobe images render (2nd deploy)

Image URLs are absolute and depend on the service's own domain, which isn't
known until step 3. Re-deploy once with the `ImageBaseUrlToSet` output value so
uploaded photos load in the app (everything else already works without this):

```sh
IMG=$(aws cloudformation describe-stacks --stack-name drape-test \
  --query "Stacks[0].Outputs[?OutputKey=='ImageBaseUrlToSet'].OutputValue" --output text)

aws cloudformation deploy \
  --template-file drape-test-apprunner.yaml \
  --stack-name drape-test \
  --capabilities CAPABILITY_IAM \
  --parameter-overrides \
      ImageUri="$IMAGE_URI" DBPassword="$DB_PASSWORD" \
      JwtSecret="$JWT_SECRET" MeasurementDek="$MEASUREMENT_DEK" \
      ImageBaseUrl="$IMG"
```

## 6. Point the mobile app at it

Use the `MobileApiBaseUrl` output (it already includes `/api/v1`):

```sh
API=$(aws cloudformation describe-stacks --stack-name drape-test \
  --query "Stacks[0].Outputs[?OutputKey=='MobileApiBaseUrl'].OutputValue" --output text)

cd ../mobile
flutter run --dart-define=API_BASE_URL="$API"
```
The DB starts empty — **sign up a new user in the app** (which also exercises
onboarding). Starter-wardrobe templates are already seeded by the migration.

---

## Redeploy after a code change

```sh
cd ../backend
docker build --platform linux/amd64 -t "$IMAGE_URI" . && docker push "$IMAGE_URI"
aws apprunner list-services --query "ServiceSummaryList[?ServiceName=='drape-test-svc'].ServiceArn" --output text \
  | xargs -I{} aws apprunner start-deployment --service-arn {}
```
(`AutoDeploymentsEnabled` is off, so pushing `:latest` alone won't redeploy — trigger it explicitly as above.)

## Teardown

```sh
aws cloudformation delete-stack --stack-name drape-test
aws ecr delete-repository --repository-name "$ECR_REPO" --force   # optional
```
RDS is `DeletionPolicy: Delete` (no snapshot) — the test DB is wiped on teardown.

---

## Known limitations (by design, for a test rig)

- **Images are ephemeral.** LocalFsStorage writes to the container's disk, lost
  on every redeploy/restart and not shared if App Runner scales out. Fine for
  spot-checking upload/scan; for durable images you'd move to S3 (S3ImageStorage
  is built — but selecting it requires `ENVIRONMENT=tbd`, which still
  hard-requires SES + KMS + S3 even with `DISABLED_FEATURES=apple_login,
  google_login,billing,push` turning off the rest; out of scope for this rig).
- **No OAuth / SES / real KMS.** The OAuth routes aren't mounted in dev
  (sign-in with Apple/Google 404s; the app treats it as unavailable);
  password-reset emails are logged, not sent; measurements use local AES,
  not KMS.
- **Billing and push are mocked.** Subscribe/cancel flows work end-to-end
  against `MockPaymentProvider` (no Stripe, no real charges, no webhook);
  push notifications are log lines, though device registration works.
- **Secrets are passed as stack parameters** (NoEcho) and surface as App Runner
  env vars — acceptable for a throwaway test env; production uses Secrets Manager
  (Tier 3.2).
- **Single small instance**, migrations run on container start. Don't load-test.
- **Cost** runs while up (App Runner provisioned instance + RDS + NAT gateway ≈
  low-tens of dollars/month). `delete-stack` when you're done.
