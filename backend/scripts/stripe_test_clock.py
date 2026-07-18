"""Drive Stripe test clocks against the dev user to exercise renewal webhooks.

Stripe only runs the interesting subscription lifecycle (renewal `invoice.paid`,
dunning `invoice.payment_failed`, eventual `customer.subscription.deleted`) as
simulated time passes, and a customer can only join a test clock at creation —
the app-created customer can't. This script builds the clocked twin and points
the dev user's local subscription row at it, so the webhook handler treats the
simulated events as the dev user's own.

Usage (from backend/, venv active, `stripe listen` + uvicorn running):

    python scripts/stripe_test_clock.py setup [--plan pro_monthly|pro_yearly]
        Create a test clock + clocked customer (with the dev user's identity,
        pm_card_visa attached) + subscription on the configured price, cancel
        the dev user's previous Stripe subscription (so it can't also renew),
        and repoint the local subscriptions row. Requires the dev user to have
        upgraded once via the app (`POST /subscription/upgrade`).

    python scripts/stripe_test_clock.py advance [--days 31]
        Fast-forward the clock; Stripe emits the real renewal webhooks through
        `stripe listen`. Watch the server log + billing history afterwards.

    python scripts/stripe_test_clock.py fail-next
        Swap the clocked customer's default card for one that declines, so the
        next `advance` exercises `invoice.payment_failed` instead.

Dev-only; refuses to run when ENVIRONMENT != dev.
"""
from __future__ import annotations

import argparse
import sys
import time
from pathlib import Path

import httpx

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.core.config import settings  # noqa: E402
from app.db.models import Subscription, User  # noqa: E402
from app.db.session import SessionLocal  # noqa: E402

_BASE = "https://api.stripe.com/v1"
DEV_EMAIL = "dev@example.com"
# Always-succeeds and attaches-fine-but-declines-charges sandbox cards.
_PM_OK = "pm_card_visa"
_PM_FAIL = "pm_card_chargeCustomerFail"


def _req(method: str, path: str, **data) -> dict:
    resp = httpx.request(
        method,
        f"{_BASE}{path}",
        auth=(settings.stripe_api_key, ""),
        data=data or None,
        timeout=20.0,
    )
    payload = resp.json()
    if resp.status_code >= 400:
        raise SystemExit(f"stripe error on {path}: {payload.get('error', {}).get('message')}")
    return payload


def _dev_subscription(db) -> tuple[User, Subscription]:
    user = db.query(User).filter(User.email == DEV_EMAIL).one_or_none()
    if user is None:
        raise SystemExit("no dev user — run scripts/seed_dev_user.py first")
    sub = db.query(Subscription).filter(Subscription.user_id == user.id).one_or_none()
    if sub is None:
        raise SystemExit(
            "dev user has no subscription row — upgrade once via the app "
            "(POST /subscription/upgrade) before setting up the clock"
        )
    return user, sub


def _clock_for_sub(provider_subscription_id: str) -> str:
    stripe_sub = _req("GET", f"/subscriptions/{provider_subscription_id}")
    customer = _req("GET", f"/customers/{stripe_sub['customer']}")
    clock = customer.get("test_clock")
    if not clock:
        raise SystemExit(
            "the current subscription's customer is not on a test clock — run "
            "`setup` first"
        )
    return clock


def setup(plan: str) -> None:
    price_id = {
        "pro_monthly": settings.stripe_price_id_pro_monthly,
        "pro_yearly": settings.stripe_price_id_pro_yearly,
    }[plan]
    if not price_id:
        raise SystemExit(f"no price id configured for {plan} — check backend/.env")

    with SessionLocal() as db:
        user, sub = _dev_subscription(db)

        clock = _req("POST", "/test_helpers/test_clocks", frozen_time=int(time.time()))
        print(f"test clock:   {clock['id']}")

        customer = _req(
            "POST",
            "/customers",
            test_clock=clock["id"],
            email=user.email,
            name=user.display_name,
            **{
                "metadata[user_id]": str(user.id),
                "metadata[environment]": settings.environment,
                "metadata[test_clock]": "true",
            },
        )
        print(f"customer:     {customer['id']} (clocked twin of {user.email})")

        pm = _req("POST", f"/payment_methods/{_PM_OK}/attach", customer=customer["id"])
        _req(
            "POST",
            f"/customers/{customer['id']}",
            **{"invoice_settings[default_payment_method]": pm["id"]},
        )

        clocked_sub = _req(
            "POST",
            "/subscriptions",
            customer=customer["id"],
            payment_behavior="error_if_incomplete",
            **{"items[0][price]": price_id, "metadata[user_id]": str(user.id)},
        )
        print(f"subscription: {clocked_sub['id']} on {plan}")

        # Stop the app-created subscription from also renewing in the sandbox.
        if sub.provider_subscription_id and sub.provider_subscription_id != clocked_sub["id"]:
            _req("DELETE", f"/subscriptions/{sub.provider_subscription_id}")
            print(f"canceled app-created subscription {sub.provider_subscription_id}")

        sub.provider_subscription_id = clocked_sub["id"]
        db.commit()
        print(
            "local subscriptions row repointed — renewal webhooks for the "
            "clocked subscription now apply to the dev user.\n"
            f"next: python scripts/stripe_test_clock.py advance --days "
            f"{31 if plan == 'pro_monthly' else 366}"
        )


def advance(days: int) -> None:
    with SessionLocal() as db:
        _, sub = _dev_subscription(db)
    clock_id = _clock_for_sub(sub.provider_subscription_id)
    clock = _req("GET", f"/test_helpers/test_clocks/{clock_id}")
    target = clock["frozen_time"] + days * 86400
    _req("POST", f"/test_helpers/test_clocks/{clock_id}/advance", frozen_time=target)
    print(f"advancing {clock_id} by {days}d ", end="", flush=True)
    while True:
        time.sleep(2)
        status = _req("GET", f"/test_helpers/test_clocks/{clock_id}")["status"]
        print(".", end="", flush=True)
        if status == "ready":
            break
        if status not in ("advancing", "ready"):
            raise SystemExit(f"\nclock entered unexpected status {status!r}")
    print(
        "\nclock advanced — check `stripe listen` for invoice.* events, the "
        "server log for the webhook 200s, and GET /billing/history for the "
        "renewal/failure row."
    )


def fail_next() -> None:
    with SessionLocal() as db:
        _, sub = _dev_subscription(db)
    stripe_sub = _req("GET", f"/subscriptions/{sub.provider_subscription_id}")
    customer_id = stripe_sub["customer"]
    pm = _req("POST", f"/payment_methods/{_PM_FAIL}/attach", customer=customer_id)
    _req(
        "POST",
        f"/customers/{customer_id}",
        **{"invoice_settings[default_payment_method]": pm["id"]},
    )
    print(
        f"default card on {customer_id} now declines — the next `advance` "
        "past a renewal exercises invoice.payment_failed."
    )


def main() -> int:
    if settings.environment != "dev":
        print(
            f"refusing to run: ENVIRONMENT={settings.environment!r} (only 'dev' is allowed)",
            file=sys.stderr,
        )
        return 2
    if not settings.stripe_api_key:
        print("no STRIPE_API_KEY in backend/.env", file=sys.stderr)
        return 2

    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    p_setup = commands.add_parser("setup")
    p_setup.add_argument("--plan", choices=["pro_monthly", "pro_yearly"], default="pro_monthly")
    p_advance = commands.add_parser("advance")
    p_advance.add_argument("--days", type=int, default=31)
    commands.add_parser("fail-next")

    args = parser.parse_args()
    if args.command == "setup":
        setup(args.plan)
    elif args.command == "advance":
        advance(args.days)
    else:
        fail_next()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
