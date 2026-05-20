"""Phase 6d verify — usage tracking, free-tier limits, analytics, Pro gate.

Usage (from backend/, with the venv active):

    python scripts/verify_phase_6d.py

The 7 checks correspond to plan.md §7 Phase 6d Verify plus a couple of
defensive guards:

  1. 22nd outfit gen for a free user → 429 with `code: limit_reached,
     resource: outfits, resets_at: ...`.
  2. Reset window math: `next_reset` is the upcoming Monday 05:00 in the
     user's timezone (America/Toronto).
  3. Cost-per-wear endpoint returns sensible numbers for items with both
     `purchase_price` and `worn_count > 0`.
  4. Intelligence report returns 402 for a free user, then 200 after
     subscription_tier flips to 'pro'.
  5. Streak: log on day N → 1, day N+1 → 2; skip a day → 1 (current_streak
     resets on a > 1-day gap).
  6. Pro user bypasses the outfits limit (would otherwise 429 at #22).
  7. Wardrobe item limit: free user can't add a 31st real item; starter
     items don't count toward the cap.
"""
from __future__ import annotations

import asyncio
import sys
from datetime import date, datetime, time, timedelta, timezone
from pathlib import Path
from zoneinfo import ZoneInfo

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from sqlalchemy import delete, select  # noqa: E402

from app.core.config import settings  # noqa: E402
from app.db.models import (  # noqa: E402
    AuthMethod,
    Outfit,
    OutfitHistory,
    StreakTracking,
    UsageTracking,
    User,
    UserStarterWardrobe,
    WardrobeItem,
    WardrobeWearLog,
)
from app.db.session import SessionLocal  # noqa: E402
from app.schemas.user import Role  # noqa: E402
from app.schemas.wardrobe import WardrobeItemCreate  # noqa: E402
from app.services import (  # noqa: E402
    analytics_service,
    outfit_service,
    starter_wardrobe_service,
    usage_service,
    wardrobe_service,
)
from app.services.usage_service import UsageError  # noqa: E402
from app.services.wardrobe_service import WardrobeError  # noqa: E402

# Reuse the canned providers we built for 6c.
from scripts.verify_phase_6c import _CannedAIProvider, _StubWeatherProvider  # noqa: E402


def _ok(label: str, detail: str = "") -> None:
    suffix = f" — {detail}" if detail else ""
    print(f"  [PASS] {label}{suffix}")


def _fail(label: str, detail: str) -> None:
    print(f"  [FAIL] {label} — {detail}")


_TEST_EMAIL_FREE = "verify-6d-free@test.local"
_TEST_EMAIL_PRO = "verify-6d-pro@test.local"
_TEST_EMAIL_LIMIT = "verify-6d-limit@test.local"


def _wipe_user(db, email: str) -> None:
    user = db.query(User).filter(User.email == email).one_or_none()
    if user is None:
        return
    db.execute(delete(OutfitHistory).where(OutfitHistory.user_id == user.id))
    db.execute(delete(Outfit).where(Outfit.user_id == user.id))
    db.execute(delete(StreakTracking).where(StreakTracking.user_id == user.id))
    db.execute(delete(UsageTracking).where(UsageTracking.user_id == user.id))
    db.execute(delete(WardrobeWearLog).where(WardrobeWearLog.user_id == user.id))
    db.execute(delete(WardrobeItem).where(WardrobeItem.user_id == user.id))
    db.execute(delete(UserStarterWardrobe).where(UserStarterWardrobe.user_id == user.id))
    db.delete(user)
    db.commit()


def _seed_user(
    db, email: str, *, tier: str = "free", with_starter: bool = True
) -> User:
    _wipe_user(db, email)
    user = User(
        email=email,
        display_name=f"Verify 6d ({tier})",
        role=Role.customer,
        password_hash="x",
        auth_method=AuthMethod.email,
        agreed_to_terms=True,
        agreed_to_privacy=True,
        terms_agreed_at=datetime.now(timezone.utc),
        shopping_style="womens",
        age_range="25-34",
        style_goals=["polished"],
        timezone="America/Toronto",
        location="Toronto, ON",
        onboarding_completed=True,
        subscription_tier=tier,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    if with_starter:
        starter_wardrobe_service.assign(db, user=user)
        db.refresh(user)
    return user


# ---------------------------------------------------------------------------


async def check_22nd_outfit_blocked(ai, weather) -> bool:
    print("[1] free user 22nd outfit → UsageError(limit_reached, outfits)")
    with SessionLocal() as db:
        user = _seed_user(db, _TEST_EMAIL_LIMIT)
        # Pre-populate the row with 21 generations to skip the actual AI calls.
        usage_service.get_or_create_current_week(db, user=user)
        row = db.query(UsageTracking).filter(UsageTracking.user_id == user.id).one()
        row.outfits_generated = 21
        db.commit()
        try:
            usage_service.check_and_increment(db, user=user, resource="outfits")
        except UsageError as exc:
            if exc.code != "limit_reached":
                _fail("22nd outfit", f"wrong code: {exc.code!r}")
                return False
            if exc.resource != "outfits":
                _fail("22nd outfit", f"wrong resource: {exc.resource!r}")
                return False
            if exc.used != 21 or exc.limit != 21:
                _fail("22nd outfit", f"counters wrong: used={exc.used}, limit={exc.limit}")
                return False
            if exc.resets_at is None:
                _fail("22nd outfit", "resets_at not populated")
                return False
            _ok(
                "22nd outfit blocked",
                f"used={exc.used}/{exc.limit}, resets_at={exc.resets_at.isoformat()}",
            )
            return True
        _fail("22nd outfit", "no UsageError raised")
        return False


def check_reset_window() -> bool:
    print("[2] reset window: next Monday 05:00 in user's tz")
    tz = ZoneInfo("America/Toronto")
    # A Wednesday afternoon, well after 05:00 local. Next reset = next Monday 05:00.
    sample_local = datetime(2026, 5, 6, 14, 0, tzinfo=tz)  # Wed
    sample_utc = sample_local.astimezone(timezone.utc)
    week_start, last_reset, next_reset = usage_service._week_window_local(sample_utc, tz)
    expected_week_start = date(2026, 5, 4)  # the Monday before
    expected_last = datetime(2026, 5, 4, 5, 0, tzinfo=tz)
    expected_next = datetime(2026, 5, 11, 5, 0, tzinfo=tz)
    if week_start != expected_week_start:
        _fail("reset window", f"week_start={week_start}, expected {expected_week_start}")
        return False
    if last_reset != expected_last.astimezone(timezone.utc):
        _fail("reset window", f"last_reset={last_reset}, expected {expected_last}")
        return False
    if next_reset != expected_next.astimezone(timezone.utc):
        _fail("reset window", f"next_reset={next_reset}, expected {expected_next}")
        return False

    # Pre-Monday-05:00 corner: a Monday at 03:00 local belongs to the *prior*
    # week — `last_reset` is the Monday-before-that.
    pre_reset_local = datetime(2026, 5, 11, 3, 0, tzinfo=tz)  # Mon @ 03:00
    pre_reset_utc = pre_reset_local.astimezone(timezone.utc)
    week_start_pre, _, next_reset_pre = usage_service._week_window_local(pre_reset_utc, tz)
    if week_start_pre != date(2026, 5, 4):
        _fail("reset window pre-Mon-5am", f"week_start={week_start_pre}, expected 2026-05-04")
        return False
    expected_next_pre = datetime(2026, 5, 11, 5, 0, tzinfo=tz).astimezone(timezone.utc)
    if next_reset_pre != expected_next_pre:
        _fail("reset window pre-Mon-5am", f"next_reset={next_reset_pre}, expected {expected_next_pre}")
        return False
    _ok("reset window", f"week_start={week_start}, next_reset={next_reset.isoformat()}")
    return True


def check_cost_per_wear() -> bool:
    print("[3] cost-per-wear math")
    with SessionLocal() as db:
        user = _seed_user(db, _TEST_EMAIL_FREE, with_starter=False)
        # Add a real item with price=120, worn 3x → CPW = 40.0.
        item = wardrobe_service.create_item(
            db,
            user=user,
            payload=WardrobeItemCreate(
                name="Test Trousers",
                category="bottoms",
                purchase_price=120.0,
                color_name="navy",
                formality="smart_casual",
            ),
        )
        from app.schemas.wardrobe import LogWornRequest

        for offset in range(3):
            wardrobe_service.log_worn(
                db,
                user=user,
                item_id=item.id,
                payload=LogWornRequest(worn_date=date.today() - timedelta(days=offset)),
            )
        report = analytics_service.cost_per_wear(db, user=user)
        match = next((i for i in report.items if i.item_id == item.id), None)
        if match is None:
            _fail("cost_per_wear", "test item missing from report")
            return False
        if match.cost_per_wear != 40.0:
            _fail("cost_per_wear", f"per-item cpw={match.cost_per_wear}, expected 40.00")
            return False
        cat = next((c for c in report.categories if c.category == "bottoms"), None)
        if cat is None or cat.average_cost_per_wear != 40.0:
            _fail("cost_per_wear", f"category cpw wrong: {cat!r}")
            return False
        _ok("cost_per_wear", f"per-item cpw={match.cost_per_wear}, category cpw={cat.average_cost_per_wear}")
        return True


def check_intelligence_report_pro_gate() -> bool:
    print("[4] intelligence-report 402 for free; 200 after upgrade")
    from fastapi.testclient import TestClient
    from app.core.security import create_access_token
    from app.main import app

    client = TestClient(app)
    with SessionLocal() as db:
        user = _seed_user(db, _TEST_EMAIL_FREE, with_starter=True)
        token = create_access_token(user_id=user.id, role=user.role.value)
        h = {"Authorization": f"Bearer {token}"}

    r = client.get("/api/v1/wardrobe/analytics/intelligence-report", headers=h)
    if r.status_code != 402:
        _fail("intelligence_report free", f"expected 402, got {r.status_code}: {r.text}")
        return False
    body = r.json()
    if body.get("detail", {}).get("error") != "pro_required":
        _fail("intelligence_report free", f"expected pro_required, got {body!r}")
        return False

    # Flip to Pro and re-hit.
    with SessionLocal() as db:
        u = db.query(User).filter(User.email == _TEST_EMAIL_FREE).one()
        u.subscription_tier = "pro"
        db.commit()
    r2 = client.get("/api/v1/wardrobe/analytics/intelligence-report", headers=h)
    if r2.status_code != 200:
        _fail("intelligence_report pro", f"expected 200, got {r2.status_code}: {r2.text}")
        return False
    body2 = r2.json()
    if "total_items" not in body2:
        _fail("intelligence_report pro", f"missing total_items: {body2!r}")
        return False
    _ok(
        "intelligence_report",
        f"free → 402 pro_required, pro → 200 (total_items={body2['total_items']})",
    )
    return True


async def check_streak_skip_resets() -> bool:
    print("[5] streak: log day N → 1, day N+1 → 2, skip a day → 1")
    with SessionLocal() as db:
        user = _seed_user(db, _TEST_EMAIL_FREE)
        outfits = (
            db.query(Outfit).filter(Outfit.user_id == user.id).all()
        )
        # Generate 3 fresh outfits to work with.
        if len(outfits) < 3:
            ai = _CannedAIProvider()
            weather = _StubWeatherProvider()
            outfits = await outfit_service.generate_for_user(
                db=db, user=user, ai=ai, weather=weather,
                occasions=("work", "casual", "date_night"),
            )
        # Day N: log first outfit.
        _, _, streak1 = outfit_service.log_outfit(db, user=user, outfit_id=outfits[0].id)
        if streak1.current_streak != 1:
            _fail("streak day N", f"streak={streak1.current_streak}, expected 1")
            return False
        # Day N+1: rewrite last_logged_date to yesterday, then log next outfit.
        row = db.query(StreakTracking).filter(StreakTracking.user_id == user.id).one()
        row.last_logged_date = date.today() - timedelta(days=1)
        db.commit()
        _, _, streak2 = outfit_service.log_outfit(db, user=user, outfit_id=outfits[1].id)
        if streak2.current_streak != 2:
            _fail("streak day N+1", f"streak={streak2.current_streak}, expected 2")
            return False
        # Skip a day: rewrite last_logged_date to 3 days ago.
        row = db.query(StreakTracking).filter(StreakTracking.user_id == user.id).one()
        row.last_logged_date = date.today() - timedelta(days=3)
        db.commit()
        _, _, streak3 = outfit_service.log_outfit(db, user=user, outfit_id=outfits[2].id)
        if streak3.current_streak != 1:
            _fail("streak skip", f"streak={streak3.current_streak}, expected 1 (gap reset)")
            return False
        _ok("streak", "1 → 2 → reset(1) on > 1-day gap")
        return True


def check_pro_bypass() -> bool:
    print("[6] Pro user bypasses the 21/wk outfit limit")
    with SessionLocal() as db:
        user = _seed_user(db, _TEST_EMAIL_PRO, tier="pro")
        # No row needed; bumping should be a no-op for Pro.
        for _ in range(50):
            try:
                usage_service.check_and_increment(db, user=user, resource="outfits")
            except UsageError as exc:
                _fail("pro bypass", f"raised on iter: code={exc.code}")
                return False
        # Confirm no row was created (Pro short-circuits).
        rows = (
            db.query(UsageTracking).filter(UsageTracking.user_id == user.id).count()
        )
        if rows != 0:
            _fail("pro bypass", f"expected 0 usage rows, got {rows}")
            return False
        _ok("pro bypass", "50 increments OK, no usage_tracking row created")
        return True


def check_wardrobe_item_limit() -> bool:
    print("[7] free user 31st real item → WardrobeError(limit_reached); starter items exempt")
    with SessionLocal() as db:
        user = _seed_user(db, _TEST_EMAIL_FREE, with_starter=True)
        # Starter assigned 9 items; those don't count.
        starter_count = (
            db.query(WardrobeItem)
            .filter(
                WardrobeItem.user_id == user.id,
                WardrobeItem.is_starter_wardrobe.is_(True),
            )
            .count()
        )
        if starter_count == 0:
            _fail("wardrobe limit", "no starter items materialized")
            return False

        # Add 30 real items — should all succeed.
        for n in range(30):
            wardrobe_service.create_item(
                db,
                user=user,
                payload=WardrobeItemCreate(
                    name=f"Test Item {n}", category="tops", color_name="white"
                ),
            )
        # 31st must fail.
        try:
            wardrobe_service.create_item(
                db,
                user=user,
                payload=WardrobeItemCreate(
                    name="Test Item 30", category="tops", color_name="white"
                ),
            )
        except WardrobeError as exc:
            if exc.code != "limit_reached":
                _fail("wardrobe limit", f"wrong code: {exc.code!r}")
                return False
            real_after = (
                db.query(WardrobeItem)
                .filter(
                    WardrobeItem.user_id == user.id,
                    WardrobeItem.is_starter_wardrobe.is_(False),
                )
                .count()
            )
            if real_after != 30:
                _fail("wardrobe limit", f"real items leaked past cap: {real_after}")
                return False
            _ok(
                "wardrobe limit",
                f"30 real items OK, 31st → limit_reached; starter ({starter_count}) exempt",
            )
            return True
        _fail("wardrobe limit", "31st item didn't raise")
        return False


async def main() -> int:
    print(f"=== Phase 6d verify (ENVIRONMENT={settings.environment}) ===")
    print()
    ai = _CannedAIProvider()
    weather = _StubWeatherProvider()

    results: list[bool] = [
        await check_22nd_outfit_blocked(ai, weather),
        check_reset_window(),
        check_cost_per_wear(),
        check_intelligence_report_pro_gate(),
        await check_streak_skip_resets(),
        check_pro_bypass(),
        check_wardrobe_item_limit(),
    ]
    print()
    passed = sum(1 for r in results if r)
    total = len(results)
    print(f"=== {passed}/{total} checks passed ===")
    return 0 if passed == total else 1


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
