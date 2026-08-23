# zoura web — marketing site hosting & runbook

Static site (`web/`) on **S3 + CloudFront**. AWS account `026481484029`,
CLI profile `zoura`. Bucket in `ca-central-1`; the ACM certificate is in
`us-east-1` because CloudFront reads certificates only from there.

| Thing | Value |
|---|---|
| Cert stack (us-east-1) | `zoura-web-cert` (template: `zoura-web-cert.yaml`) |
| Site stack (ca-central-1) | `zoura-prd-web` (template: `zoura-web.yaml`) |
| Bucket | `zoura-prd-web-026481484029` — private, CloudFront-only via OAC |
| Domains | `zoura.style` + `www` (the site) and `getzoura.com` + `www` (301 → `/download`) |
| Registrar & DNS | **Namecheap**, both domains |
| Certificate | one cert, four names, `us-east-1` |
| Deploy | `cd infra/ansible && ansible-playbook deploy-web.yml` |

## First-time setup

Three stages, in order. The middle one blocks on DNS, so expect a wait.

### 1. Request the certificate (us-east-1)

```sh
aws cloudformation create-stack --profile zoura --region us-east-1 \
  --stack-name zoura-web-cert \
  --template-body file://infra/zoura-web-cert.yaml \
  --parameters ParameterKey=DomainName,ParameterValue=zoura.style \
               ParameterKey=RedirectDomain,ParameterValue=getzoura.com
```

`create-stack`, not `deploy` — `deploy` blocks waiting for a stack that cannot
finish until the DNS in step 2 exists.

This intentionally hangs in `CREATE_IN_PROGRESS` until you complete step 2 —
ACM will not issue until it can resolve the validation records. Read them with:

```sh
aws acm list-certificates --profile zoura --region us-east-1 \
  --query "CertificateSummaryList[?DomainName=='zoura.style'].CertificateArn" --output text

aws acm describe-certificate --profile zoura --region us-east-1 \
  --certificate-arn <arn> \
  --query "Certificate.DomainValidationOptions[].ResourceRecord" --output table
```

### 2. Namecheap — validation records

Namecheap dashboard → **Domain List** → `zoura.style` → **Manage**.

First confirm **Nameservers** is set to *Namecheap BasicDNS*. If it points
somewhere else, the **Advanced DNS** tab is not authoritative and nothing below
takes effect.

Then **Advanced DNS** → *Host Records* → add the two ACM records as `CNAME Record`.

> **The one thing people get wrong here:** Namecheap appends the domain to the
> Host field for you. ACM prints a full name like
> `_a1b2c3.zoura.style.` — enter only **`_a1b2c3`** in Host. Pasting the whole
> thing creates `_a1b2c3.zoura.style.zoura.style` and validation never completes.
> Drop the trailing dot from the value too. TTL: Automatic.

Also delete Namecheap's default parking records if they are still there — a
`CNAME` on `www` pointing at `parkingpage.namecheap.com`, and any
`URL Redirect Record` on `@`. They will collide with the records in step 4.

Leave the existing `api-tbd` A record and the three `_domainkey` DKIM CNAMEs
alone — they are unrelated and still needed.

Validation usually lands within 10–30 minutes. Watch it:

```sh
aws acm describe-certificate --profile zoura --region us-east-1 \
  --certificate-arn <arn> --query "Certificate.Status" --output text
# ISSUED
```

ACM issues **only once all four records resolve** — two in each zone. Verify
them yourself before waiting on AWS:

```sh
dig +short CNAME _<token>.zoura.style      # must return the acm-validations value
```

### 3. Create the site stack (ca-central-1)

```sh
aws cloudformation deploy --profile zoura --region ca-central-1 \
  --stack-name zoura-prd-web \
  --template-file infra/zoura-web.yaml \
  --parameter-overrides \
      Env=prd \
      DomainName=zoura.style \
      RedirectDomain=getzoura.com \
      RedirectTarget=https://zoura.style/download \
      CertificateArn=<arn from step 1>

aws cloudformation describe-stacks --profile zoura --region ca-central-1 \
  --stack-name zoura-prd-web --query "Stacks[0].Outputs" --output table
```

CloudFront takes 5–15 minutes to deploy. Note `DistributionDomainName` —
something like `d1a2b3c4d5e6f7.cloudfront.net`. That is the DNS target.

### 4. Namecheap — point the domain at CloudFront

Back in **Advanced DNS** → *Host Records*:

Four records, two per zone — all pointing at the **same** distribution.

`zoura.style`:

| Type | Host | Value | TTL |
|---|---|---|---|
| `ALIAS Record` | `@` | `dxxxxxxxx.cloudfront.net` | Automatic |
| `CNAME Record` | `www` | `dxxxxxxxx.cloudfront.net` | Automatic |

`getzoura.com` — same target; the redirect happens at the edge, not in DNS:

| Type | Host | Value | TTL |
|---|---|---|---|
| `ALIAS Record` | `@` | `dxxxxxxxx.cloudfront.net` | Automatic |
| `CNAME Record` | `www` | `dxxxxxxxx.cloudfront.net` | Automatic |

The apex needs **ALIAS**, not CNAME — DNS forbids a CNAME at a zone apex
alongside the SOA/NS records. Namecheap's BasicDNS offers `ALIAS Record` for
exactly this, which is why the zone can stay at Namecheap.

> **Why `getzoura.com` is not a Namecheap URL Redirect Record:** Namecheap's
> forwarder does not serve an SSL certificate for the source domain, so
> `https://getzoura.com` shows a certificate warning — and Chrome tries HTTPS
> first. The CloudFront Function returns a real 301 over valid TLS instead, at
> no extra cost, because `getzoura.com` is an alias on the same distribution.
>
> **Do not** substitute a `URL Redirect Record` on `@` pointing at `www`.
> Namecheap's redirector does not serve valid HTTPS for the apex, and
> `PRD_MIGRATION_CHECKLIST.md` requires `https://zoura.style/privacy` and
> `/terms` to be reachable for App Store review.
>
> If the ALIAS record misbehaves, the fallback is moving the zone to Route53
> and using an A/AAAA **Alias** to the distribution (~$0.50/month for the hosted
> zone, and the DKIM/`api-tbd` records have to be recreated there).

Check propagation:

```sh
dig +short zoura.style && dig +short www.zoura.style
dig +short getzoura.com && dig +short www.getzoura.com

curl -sSI https://zoura.style          | head -1     # 200
curl -sSI https://zoura.style/download | head -1     # 200
curl -sSI https://getzoura.com         | grep -iE '^(HTTP|location)'
# HTTP/2 301
# location: https://zoura.style/download
```

### 5. First deploy

```sh
cd infra/ansible && ansible-playbook deploy-web.yml
```

## Day-2

```sh
# Build and publish (the normal path)
cd infra/ansible && ansible-playbook deploy-web.yml

# Publish an already-built dist/ without rebuilding
ansible-playbook deploy-web.yml -e skip_build=true

# Preview the exact bytes that will ship, locally
cd web && npm run build && npm run preview      # http://localhost:4173

# Watch an invalidation finish
aws cloudfront get-invalidation --profile zoura \
  --distribution-id <id> --id <invalidation-id> --query "Invalidation.Status"

# Tear the site down (bucket is DeletionPolicy: Delete — empty it first)
aws s3 rm s3://zoura-prd-web-026481484029/ --recursive --profile zoura
aws cloudformation delete-stack --profile zoura --region ca-central-1 --stack-name zoura-prd-web
```

`deploy-web.yml` runs locally rather than over SSH — it reads the bucket and
distribution id out of the stack outputs, so it keeps working if the stack is
recreated. It syncs in three passes to give each content type its own
`Cache-Control` (images a week, css/js an hour, HTML `no-cache`), deletes
orphans, then invalidates `/*`. Filenames are not content-hashed, which is why
nothing gets a long TTL.

## Notes

- **Cost** — roughly zero. CloudFront's permanent free tier covers 1 TB/month
  and 10M requests; `dist/` is ~2.5 MB. S3 storage is pennies. The first 1,000
  invalidation paths each month are free, and `/*` counts as one path.
- **PriceClass_100** (North America + Europe) is the default. Raise it to
  `PriceClass_All` in the stack parameters if traffic justifies it.
- **`.well-known/`** is excluded from the URL-rewrite CloudFront Function, so
  `apple-app-site-association` (no extension, must be `application/json`) will
  be served verbatim once it is added. Set its content type explicitly on
  upload — S3 will not infer it.
- **Not yet built:** `/privacy`, `/terms`, and the two `.well-known` files.
  Tracked in `web/README.md` and `PRD_MIGRATION_CHECKLIST.md:27-28`.
