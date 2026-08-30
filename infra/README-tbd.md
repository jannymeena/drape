# zoura-tbd — deployed state & runbook (deployed 2026-07-19)

Full-app tbd on one EC2 (BACKEND_CHANGES §3.2A). AWS account `026481484029`,
region `ca-central-1`, CLI profile `zoura`.

## Provisioned resources

| Thing | Value |
|---|---|
| CloudFormation stack | `zoura-tbd` (template: `zoura-tbd.yaml`) |
| Instance | `i-08b68c1216cba7881` — t4g.micro, Ubuntu 24.04 arm64 |
| Elastic IP | **15.223.99.152** ← Namecheap A record `api-tbd.zoura.style` |
| Data volume (Postgres, `/data`) | `vol-06f9e1af480ec9b39` — 10 GB gp3, DeletionPolicy Retain |
| Images bucket (public-read) | `zoura-tbd-images-026481484029` |
| Backups bucket (private, 30-day expiry) | `zoura-tbd-backups-026481484029` |
| KMS CMK (measurements) | `arn:aws:kms:ca-central-1:026481484029:key/bfe01464-9d97-431b-8c25-2c975cfe5f7f` (`alias/zoura-tbd-measurements`) |
| Config | SSM Parameter Store `/zoura/tbd/*` (19 SecureString params) |
| SSH key | `~/.ssh/zoura-tbd.pem` (key pair `zoura-tbd`; port 22 open to home IP only) |
| SES identities | `zoura.style` (needs DKIM CNAMEs) + `developer@zoura.style` (sandbox recipient) |

On-box: systemd units `zoura` (uvicorn :8000, `--no-access-log`), `caddy`
(TLS for api-tbd.zoura.style), `postgresql` (16 + pgvector, data on `/data`);
2 GB swap; nightly `pg_dump` → backups bucket at 07:15 UTC (cron, user zoura).

## DNS records to create at Namecheap (zoura.style)

| Type | Host | Value |
|---|---|---|
| A | `api-tbd` | `15.223.99.152` |
| CNAME | `jxbk7dhg6ackfhyw2qp3d7zm5aeouh6z._domainkey` | `jxbk7dhg6ackfhyw2qp3d7zm5aeouh6z.dkim.amazonses.com` |
| CNAME | `rxjsfsesbzh7ov5n5cxn3kfoyvxr6chi._domainkey` | `rxjsfsesbzh7ov5n5cxn3kfoyvxr6chi.dkim.amazonses.com` |
| CNAME | `lls5rp223g5gzanowjf54yk2cxtnzfta._domainkey` | `lls5rp223g5gzanowjf54yk2cxtnzfta.dkim.amazonses.com` |

Caddy auto-issues the Let's Encrypt cert once the A record resolves (keeps
retrying, no action needed). SES sends once the DKIM CNAMEs verify; sandbox
mode also requires clicking the verification link mailed to the gmail address.

## Day-2 commands

```sh
# Deploy a code change (sync, pip, .env from SSM, alembic, restart, health)
cd infra/ansible && ansible-playbook deploy.yml

# Re-run server provisioning (idempotent)
ansible-playbook provision.yml

# Rebuild the DB from the current migrations — DESTROYS ALL DATA in zoura_tbd.
# Needed after a migration squash (CLAUDE.md folds schema changes into the
# single init migration, so `alembic upgrade head` no-ops against a DB already
# reporting that revision and the new columns never appear). Dumps to the
# backups bucket first. Deploy the new code first, then reset.
# Prefer a plain ALTER TABLE when the delta is a nullable column or two.
ansible-playbook deploy.yml
ansible-playbook reset-db.yml -e confirm=zoura_tbd

# Logs / status / SQL
ssh -i ~/.ssh/zoura-tbd.pem ubuntu@15.223.99.152
  sudo journalctl -u zoura -f
  sudo systemctl status zoura caddy postgresql
  sudo -u zoura psql zoura_tbd        # peer auth as app user? use: sudo -u postgres psql zoura_tbd

# Change a config value, then restart to pick it up
aws ssm put-parameter --profile zoura --name /zoura/tbd/KEY --value '...' --type SecureString --overwrite
ssh -i ~/.ssh/zoura-tbd.pem ubuntu@15.223.99.152 'sudo systemctl restart zoura'

# Grow the Postgres volume (online, grow-only, once per 6 h)
aws ec2 modify-volume --profile zoura --volume-id vol-06f9e1af480ec9b39 --size 20
ssh ... 'sudo resize2fs /dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_vol06f9e1af480ec9b39'

# If your home IP changes (SSH locked out): open the SG rule directly.
# DO NOT use `cloudformation deploy` for this any more — `UbuntuArmAmi` resolves
# to the *current* Ubuntu AMI, which has moved since the 2026-07-19 launch, so
# any stack update now REPLACES THE INSTANCE (verified via change set
# 2026-08-30: Instance replacement=True, ImageId recreation=Always). That
# rebuilds the root volume — app, venv, systemd units, Caddy's Let's Encrypt
# certs — and leaves the retained data volume attached to a bare box needing a
# full provision.yml.
SG=$(aws cloudformation describe-stack-resources --stack-name zoura-tbd --profile zoura \
  --query "StackResources[?ResourceType=='AWS::EC2::SecurityGroup'].PhysicalResourceId" --output text)
aws ec2 authorize-security-group-ingress --profile zoura --group-id "$SG" \
  --ip-permissions 'IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=NEW.IP/32,Description="temp"}]'
# Revoke when done — a dynamic IP gets reassigned to someone else eventually:
aws ec2 revoke-security-group-ingress --profile zoura --group-id "$SG" \
  --ip-permissions 'IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=NEW.IP/32}]'
# This drifts from the template (CFN still records the old HomeIpCidr). To make
# a stack update safe again, first pin UbuntuArmAmi to the AMI the instance is
# actually running.
```

## Verified end-to-end 2026-07-19

- [x] DNS: `api-tbd.zoura.style` → 15.223.99.152; HTTPS live (Let's Encrypt via Caddy).
- [x] `GET /api/v1/health` → 200 over HTTPS; signup 201; Google OAuth verifier answers
      `oauth_invalid_token` (wired); JSON logs with request_id.
- [x] SES recipient `developer@zoura.style` VERIFIED. Other available mailboxes:
      info@zoura.style, support@zoura.style.
- [x] Stripe tbd webhook `we_1TuyOZLOZdriIeeP7YYP2ZZy` → the /billing/webhook/stripe URL
      (3 events); its `whsec_` in `/zoura/tbd/STRIPE_WEBHOOK_SECRET`; unsigned POST → 400.
- [x] forgot-password 500-on-mail-failure bug found live + fixed (service now keeps the
      202 contract when the provider raises; regression test added).

## Still pending

- [x] SES domain `zoura.style` VERIFIED (DKIM SUCCESS, 2026-07-20) — real password-reset
      email delivered to developer@zoura.style via forgot-password. Email pipeline done.
- [ ] Mobile build against it: `flutter run --dart-define=API_BASE_URL=https://api-tbd.zoura.style/api/v1`.
- [ ] CloudWatch log shipping (journald → CW agent) — optional, journalctl works meanwhile.
