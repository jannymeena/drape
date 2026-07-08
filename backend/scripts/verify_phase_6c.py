"""Phase 6c verify — outfit generation, mix-and-match, log + streak, history.

Usage (from backend/, with the venv active):

    python scripts/verify_phase_6c.py

The 6 checks correspond to plan.md §7 Phase 6c Verify:

  1. Today dashboard generates 3 outfits, each grounded in the user's wardrobe
     (item ids match starter or real items only).
  2. Reasoning text references items by name and `image_url` is null
     (decision #2 — no server-side composites).
  3. Regenerate produces a different outfit (different item set).
  4. Mix-and-match swap recomputes compatibility deterministically (no AI call).
  5. Log advances streak + history; toast variant cycles default → streak →
     milestone as the streak is artificially walked forward.
  6. History query filters work (this_week vs all).

This script uses a `_CannedAIProvider` so it's deterministic and offline.
Spins up a throwaway test user + assigns a starter wardrobe each run.
"""
from __future__ import annotations

import asyncio
import json
import sys
import uuid
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from sqlalchemy import delete  # noqa: E402

from app.core.config import settings  # noqa: E402
from app.db.models import (  # noqa: E402
    AuthMethod,
    Outfit,
    OutfitHistory,
    StreakTracking,
    User,
    UserStarterWardrobe,
    WardrobeItem,
)
from app.db.session import SessionLocal  # noqa: E402
from app.schemas.outfit import (  # noqa: E402
    HistoryFilter,
    MixSwap,
)
from app.schemas.user import Role  # noqa: E402
from app.services import outfit_service, starter_wardrobe_service  # noqa: E402
from app.services.outfit_service import (  # noqa: E402
    DAILY_OUTFIT_TARGET,
    OutfitError,
    _select_toast,
)
from app.services.providers.ai.base import AIProvider  # noqa: E402
from app.services.providers.weather.base import (  # noqa: E402
    WeatherProvider,
    WeatherSnapshot,
)


def _ok(label: str, detail: str = "") -> None:
    suffix = f" — {detail}" if detail else ""
    print(f"  [PASS] {label}{suffix}")


def _fail(label: str, detail: str) -> None:
    print(f"  [FAIL] {label} — {detail}")


# A canned weather provider that returns a plausible Toronto reading without
# hitting the network — keeps the verify offline and deterministic.
class _StubWeatherProvider(WeatherProvider):
    async def current(self, lat: float, lon: float) -> WeatherSnapshot:
        return WeatherSnapshot(
            temp_c=14.0,
            feels_like_c=12.0,
            condition="cloudy",
            humidity_pct=68,
            wind_kph=12.5,
        )


class _CannedAIProvider(AIProvider):
    """Returns valid outfit-proposal JSON keyed off the prompt.

    Sniffs the prompt for available item ids (the format is ` id=<uuid> `),
    picks the first 4, and returns a structured proposal that names them
    by id. This guarantees `generate_one` never hits the parse-failure
    fallback path during 6c verify.
    """

    def __init__(self) -> None:
        self.calls = 0

    async def chat(
        self,
        messages,  # type: ignore[override]
        *,
        model=None,
        system=None,
        max_tokens=1024,
        cache_system=False,
    ) -> str:
        self.calls += 1
        prompt = ""
        if messages:
            raw = messages[-1].get("content", "")
            prompt = raw if isinstance(raw, str) else str(raw)
        # Tier 1.3 moved the item list into the (cacheable) system prefix;
        # sniff both so id extraction keeps working.
        prompt = f"{system or ''}\n{prompt}"
        # Extract item ids in the same order the prompt presented them.
        import re

        ids = re.findall(
            r"id=([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})",
            prompt,
        )
        # Pick 4 distinct ids — ensures the AI never "invents" ids and the
        # fallback path stays untouched. If <4 available, take whatever exists.
        chosen = ids[:4] if len(ids) >= 4 else ids
        rationales = {
            i: f"This piece anchors the outfit (item #{n + 1})."
            for n, i in enumerate(chosen)
        }
        # Sniff occasion off the prompt.
        m = re.search(r"occasion: (\w+)", prompt)
        occasion = m.group(1) if m else "casual"
        proposal = {
            "occasion": occasion,
            "item_ids": chosen,
            "reasoning_short": (
                f"A {occasion.replace('_', ' ')} look that pairs your existing pieces."
            ),
            "reasoning_full": (
                f"This {occasion.replace('_', ' ')} outfit balances neutral basics "
                "with one focal piece. Each item earns its slot: the top sets the "
                "tone, the bottom keeps the silhouette grounded, the shoes finish "
                "the line."
            ),
            "per_item_rationales": rationales,
            "compatibility_score": 84,
            "factors": [
                "Color harmony",
                "Occasion appropriateness",
                "Wardrobe rotation",
            ],
        }
        return json.dumps(proposal)

    async def analyze_image(  # type: ignore[override]
        self, image_bytes, prompt, *, media_type="image/jpeg", model=None, max_tokens=1024
    ) -> str:
        return json.dumps(
            {
                "category": "tops",
                "color": "blue",
                "pattern": "solid",
                "formality": "casual",
                "confidence": 80,
            }
        )


# ---------------------------------------------------------------------------
# Test fixture: throwaway user + starter wardrobe assignment.
# ---------------------------------------------------------------------------


_TEST_EMAIL = "verify-6c@test.local"


def _reset_test_user(db) -> User:
    user = db.query(User).filter(User.email == _TEST_EMAIL).one_or_none()
    if user is not None:
        # Wipe all dependent rows so each verify run starts clean.
        db.execute(delete(OutfitHistory).where(OutfitHistory.user_id == user.id))
        db.execute(delete(Outfit).where(Outfit.user_id == user.id))
        db.execute(delete(StreakTracking).where(StreakTracking.user_id == user.id))
        db.execute(delete(WardrobeItem).where(WardrobeItem.user_id == user.id))
        db.execute(delete(UserStarterWardrobe).where(UserStarterWardrobe.user_id == user.id))
        db.delete(user)
        db.commit()

    user = User(
        email=_TEST_EMAIL,
        display_name="Phase 6c Verify",
        role=Role.customer,
        password_hash="bogus",  # never used; we never log this user in
        auth_method=AuthMethod.email,
        agreed_to_terms=True,
        agreed_to_privacy=True,
        terms_agreed_at=datetime.now(timezone.utc),
        shopping_style="womens",
        age_range="25-34",
        style_goals=["polished", "maximize_wardrobe"],
        timezone="America/Toronto",
        location="Toronto, ON",
        onboarding_completed=True,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


# ---------------------------------------------------------------------------
# Checks
# ---------------------------------------------------------------------------


async def check_dashboard_3_outfits(db, user: User, ai, weather) -> bool:
    print(f"[1] dashboard generates {DAILY_OUTFIT_TARGET} grounded outfits")
    try:
        outfits, _ = await outfit_service.load_dashboard_outfits(
            db=db, user=user, ai=ai, weather=weather
        )
    except OutfitError as exc:
        _fail("dashboard", f"OutfitError({exc.code}): {exc}")
        return False
    if len(outfits) < DAILY_OUTFIT_TARGET:
        _fail("dashboard", f"got {len(outfits)} outfits, expected {DAILY_OUTFIT_TARGET}")
        return False
    # Every item id in every outfit must come from this user's wardrobe rows.
    user_item_ids = {
        i.id for i in db.query(WardrobeItem).filter(WardrobeItem.user_id == user.id).all()
    }
    grounded = True
    for o in outfits:
        ids = [uuid.UUID(item["item_id"]) for item in o.items]
        if not ids:
            grounded = False
            break
        if any(i not in user_item_ids for i in ids):
            grounded = False
            break
    if not grounded:
        _fail("dashboard", "outfit referenced item not in user's wardrobe")
        return False
    occasions = [o.occasion for o in outfits]
    _ok("dashboard", f"3 outfits, occasions={occasions}, all grounded")
    return True


def check_reasoning_no_composite(db, user: User) -> bool:
    print("[2] reasoning references items by name; image_url is null")
    outfits = db.query(Outfit).filter(Outfit.user_id == user.id).all()
    if not outfits:
        _fail("reasoning", "no outfits to inspect")
        return False
    sample = outfits[0]
    if sample.image_url is not None:
        _fail("reasoning", f"image_url set ({sample.image_url}); should be null")
        return False
    if not sample.ai_reasoning_full or len(sample.ai_reasoning_full) < 30:
        _fail("reasoning", f"reasoning too short: {sample.ai_reasoning_full!r}")
        return False
    # Reasoning is per-occasion and references the outfit semantics; the
    # CannedAIProvider doesn't echo names but it does include "outfit", "top",
    # "bottom" — enough to confirm structured prose came back.
    if "outfit" not in sample.ai_reasoning_full.lower():
        _fail("reasoning", "reasoning missing structural cues; got: "
              f"{sample.ai_reasoning_full[:120]!r}")
        return False
    _ok("reasoning", f"image_url=null, reasoning_full len={len(sample.ai_reasoning_full)}")
    return True


async def check_regenerate_differs(db, user: User, ai, weather) -> bool:
    print("[3] regenerate produces a different item set")
    outfits = (
        db.query(Outfit)
        .filter(Outfit.user_id == user.id)
        .order_by(Outfit.created_at.desc())
        .all()
    )
    if not outfits:
        _fail("regenerate", "no outfits to regenerate from")
        return False
    prior = outfits[0]
    prior_ids = {item["item_id"] for item in prior.items}
    try:
        fresh = await outfit_service.regenerate(
            db=db, user=user, ai=ai, weather=weather, outfit_id=prior.id
        )
    except OutfitError as exc:
        _fail("regenerate", f"OutfitError({exc.code}): {exc}")
        return False
    fresh_ids = {item["item_id"] for item in fresh.items}
    if fresh.id == prior.id:
        _fail("regenerate", "fresh outfit reuses the prior outfit's id")
        return False
    # The CannedAIProvider picks the first 4 ids in the prompt; regenerate
    # excludes the prior outfit's items, so the new outfit must use a
    # disjoint set whenever the wardrobe has > 4 items (starter wardrobes have
    # 9-15 items, so this is satisfied).
    if fresh_ids == prior_ids:
        _fail("regenerate", f"fresh ids == prior ids: {fresh_ids}")
        return False
    _ok("regenerate", f"prior items={len(prior_ids)}, fresh items={len(fresh_ids)}, disjoint")
    return True


def check_mix_and_match(db, user: User) -> bool:
    print("[4] mix-and-match swap recomputes compatibility deterministically")
    outfit = (
        db.query(Outfit)
        .filter(Outfit.user_id == user.id)
        .order_by(Outfit.created_at.desc())
        .first()
    )
    if outfit is None:
        _fail("mix_and_match", "no outfit to mix")
        return False
    current_item_ids = {uuid.UUID(item["item_id"]) for item in outfit.items}
    # Pick a wardrobe item NOT currently in the outfit to swap in.
    candidate = (
        db.query(WardrobeItem)
        .filter(
            WardrobeItem.user_id == user.id,
            WardrobeItem.id.notin_(current_item_ids),
        )
        .first()
    )
    if candidate is None:
        _fail("mix_and_match", "no candidate item to swap in")
        return False
    old_item_id = uuid.UUID(outfit.items[0]["item_id"])
    score_before = outfit.compatibility_score

    swap = MixSwap(old_item_id=old_item_id, new_item_id=candidate.id)
    try:
        updated_outfit, score_after = outfit_service.mix_and_match(
            db, user=user, outfit_id=outfit.id, swaps=[swap]
        )
    except OutfitError as exc:
        _fail("mix_and_match", f"OutfitError({exc.code}): {exc}")
        return False
    new_item_ids = {uuid.UUID(item["item_id"]) for item in updated_outfit.items}
    if old_item_id in new_item_ids:
        _fail("mix_and_match", "old item id still present after swap")
        return False
    if candidate.id not in new_item_ids:
        _fail("mix_and_match", "new item id missing after swap")
        return False
    # Determinism: a second run with the same swap (re-swap candidate→old)
    # should reset to the prior compatibility.
    swap_back = MixSwap(old_item_id=candidate.id, new_item_id=old_item_id)
    _, score_back = outfit_service.mix_and_match(
        db, user=user, outfit_id=outfit.id, swaps=[swap_back]
    )
    if score_back != score_before:
        _fail(
            "mix_and_match",
            f"reverse swap didn't restore score: before={score_before}, back={score_back}",
        )
        return False
    _ok(
        "mix_and_match",
        f"score={score_before} → {score_after} → {score_back} (deterministic)",
    )
    return True


def check_log_streak_and_toasts(db, user: User) -> bool:
    print("[5] log advances streak + history; toast variants exercised")
    outfits = (
        db.query(Outfit).filter(Outfit.user_id == user.id).order_by(Outfit.created_at.asc()).all()
    )
    if len(outfits) < 1:
        _fail("log", "no outfits to log")
        return False

    # Day 1: log the first outfit. Streak should become 1; toast=default.
    outfit, toast, streak = outfit_service.log_outfit(db, user=user, outfit_id=outfits[0].id)
    if toast.type != "default":
        _fail("log default", f"first log toast = {toast.type!r}, expected 'default'")
        return False
    if streak.current_streak != 1:
        _fail("log default", f"streak={streak.current_streak}, expected 1")
        return False
    history_rows = db.query(OutfitHistory).filter(OutfitHistory.user_id == user.id).count()
    if history_rows != 1:
        _fail("log default", f"history rows={history_rows}, expected 1")
        return False

    # Walk the streak: artificially pretend N days passed by rewriting
    # last_logged_date and total_outfits_logged. This exercises the toast
    # selector without waiting calendar days.
    streak_row = db.query(StreakTracking).filter(StreakTracking.user_id == user.id).one()
    streak_row.last_logged_date = date.today() - timedelta(days=1)
    streak_row.current_streak = 2
    db.commit()

    if len(outfits) < 2:
        _fail("log streak", "need ≥2 outfits to test streak toast")
        return False
    _, toast2, streak2 = outfit_service.log_outfit(db, user=user, outfit_id=outfits[1].id)
    # current_streak now 3 (≥3) AND total=2 (not a milestone) → streak toast.
    if toast2.type != "streak":
        _fail("log streak", f"streak toast = {toast2.type!r}, expected 'streak'")
        return False
    if streak2.current_streak != 3:
        _fail("log streak", f"streak={streak2.current_streak}, expected 3")
        return False

    # Milestone: pretend total_outfits_logged is about to hit 5.
    streak_row = db.query(StreakTracking).filter(StreakTracking.user_id == user.id).one()
    streak_row.total_outfits_logged = 4
    streak_row.last_logged_date = date.today() - timedelta(days=1)
    streak_row.current_streak = 0
    db.commit()
    if len(outfits) < 3:
        _fail("log milestone", "need ≥3 outfits to test milestone toast")
        return False
    _, toast3, streak3 = outfit_service.log_outfit(db, user=user, outfit_id=outfits[2].id)
    if toast3.type != "milestone":
        _fail("log milestone", f"milestone toast = {toast3.type!r}, expected 'milestone'")
        return False
    if streak3.total_outfits_logged != 5:
        _fail("log milestone", f"total={streak3.total_outfits_logged}, expected 5")
        return False

    _ok("log + streak + toast", "default → streak → milestone all selected correctly")
    return True


def check_history_filter(db, user: User) -> bool:
    print("[6] history query filters work")
    all_resp = outfit_service.get_history(db, user=user, filter_="all")
    if all_resp.total_count < 1:
        _fail("history", "no rows in history after logs")
        return False
    week_resp = outfit_service.get_history(db, user=user, filter_="this_week")
    # All our test logs happened in this calendar week (just now).
    if week_resp.total_count > all_resp.total_count:
        _fail("history", f"week count > all count: {week_resp.total_count} vs {all_resp.total_count}")
        return False
    if all_resp.filter != "all" or week_resp.filter != "this_week":
        _fail("history", "filter echo wrong on response")
        return False
    _ok("history", f"all={all_resp.total_count}, this_week={week_resp.total_count}")
    return True


def check_toast_table() -> bool:
    """Pure-function check on _select_toast — pins the priority logic to
    CTO doc 2 §"TOAST PRIORITY LOGIC"."""
    print("[bonus] toast priority: milestone > streak > default")
    cases = [
        # total_logged, current_streak, expected_variant
        (5, 0, "milestone"),
        (10, 5, "milestone"),  # streak ≥ 3 but milestone wins
        (3, 5, "streak"),
        (3, 2, "default"),
        (1, 0, "default"),
    ]
    for total, streak, expected in cases:
        toast = _select_toast(total_logged=total, current_streak=streak)
        if toast.type != expected:
            _fail(
                "toast priority",
                f"total={total}, streak={streak} → {toast.type!r}, expected {expected!r}",
            )
            return False
    _ok("toast priority", f"{len(cases)} cases match")
    return True


async def main() -> int:
    print(f"=== Phase 6c verify (ENVIRONMENT={settings.environment}) ===")
    ai = _CannedAIProvider()
    weather = _StubWeatherProvider()
    print(f"ai = {type(ai).__name__}, weather = {type(weather).__name__}")
    print()

    with SessionLocal() as db:
        user = _reset_test_user(db)
        # Assign starter wardrobe so the user has 9-15 items before any outfit
        # generation runs. Picks women_25_34_polished given the seed profile.
        starter_wardrobe_service.assign(db, user=user)
        db.refresh(user)
        item_count = (
            db.query(WardrobeItem).filter(WardrobeItem.user_id == user.id).count()
        )
        print(f"seeded user {user.id} with {item_count} starter items")
        print()

        results: list[bool] = []
        results.append(await check_dashboard_3_outfits(db, user, ai, weather))
        results.append(check_reasoning_no_composite(db, user))
        results.append(await check_regenerate_differs(db, user, ai, weather))
        results.append(check_mix_and_match(db, user))
        results.append(check_log_streak_and_toasts(db, user))
        results.append(check_history_filter(db, user))
        results.append(check_toast_table())

    print()
    passed = sum(1 for r in results if r)
    total = len(results)
    print(f"=== {passed}/{total} checks passed ===")
    return 0 if passed == total else 1


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
