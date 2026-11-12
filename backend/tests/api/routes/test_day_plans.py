"""Day plans — GET/PUT/DELETE /today/plans (Plan your week / Plan a day).

Dates are relative to the user's local app day, so the suite runs on any
date. "Three weeks in" histories are seeded straight into the tables: past
days can't be written through the API.
"""
from __future__ import annotations

from datetime import date, timedelta
from typing import get_args

from app.core.localtime import user_today
from app.data import occasion_rules
from app.db.models import DayPlan, WeeklyPlanRule
from app.schemas.day_plan import DayOccasion
from app.services.day_plan_service import OUTFIT_OCCASION

BASE = "/api/v1/today/plans"


def _today(client) -> date:
    return user_today(client.test_user)


def _put(client, day: date, occasion="work_day", dress="smart_casual", **extra):
    body = {"occasion": occasion, "dress_level": dress, **extra}
    if isinstance(body.get("until"), date):
        body["until"] = body["until"].isoformat()
    return client.put(f"{BASE}/{day.isoformat()}", json=body)


def _days(client, start: date, end: date) -> dict[date, dict]:
    r = client.get(BASE, params={"from": start.isoformat(), "to": end.isoformat()})
    assert r.status_code == 200, r.text
    return {date.fromisoformat(d["date"]): d for d in r.json()["days"]}


def _occasion(day: dict) -> str | None:
    return day["plan"]["occasion"] if day["plan"] else None


def _seed_rule(db, user, *, weekday, occasion, starts_on, ends_on=None):
    db.add(
        WeeklyPlanRule(
            user_id=user.id,
            weekday=weekday,
            occasion=occasion,
            dress_level="smart_casual",
            starts_on=starts_on,
            ends_on=ends_on,
        )
    )
    db.commit()


# ---------------------------------------------------------------------------
# Reads + one-off plans
# ---------------------------------------------------------------------------


def test_default_read_is_the_next_seven_days_all_empty(authed_client):
    r = authed_client.get(BASE)
    assert r.status_code == 200
    days = r.json()["days"]
    today = _today(authed_client)
    assert [d["date"] for d in days] == [
        (today + timedelta(days=i)).isoformat() for i in range(7)
    ]
    assert all(d["plan"] is None and d["source"] is None for d in days)
    assert not any(d["repeats_weekly"] for d in days)


def test_save_just_one_day(authed_client):
    day = _today(authed_client) + timedelta(days=2)
    r = _put(authed_client, day, "interview", "business", note="  Client pitch ")
    assert r.status_code == 200, r.text
    assert r.json() == {
        "date": day.isoformat(),
        "plan": {"occasion": "interview", "dress_level": "business", "note": "Client pitch"},
        "source": "day",
        "repeats_weekly": False,
    }
    days = _days(authed_client, day, day + timedelta(days=7))
    assert _occasion(days[day]) == "interview"
    assert days[day + timedelta(days=7)]["plan"] is None


def test_saving_a_day_again_replaces_it(authed_client, db):
    day = _today(authed_client) + timedelta(days=1)
    _put(authed_client, day, "work_day", note="Pitch")
    _put(authed_client, day, "day_off", "casual", note="  ")
    days = _days(authed_client, day, day)
    assert days[day]["plan"] == {"occasion": "day_off", "dress_level": "casual", "note": None}
    assert db.query(DayPlan).filter_by(user_id=authed_client.test_user.id).count() == 1


def test_validation(authed_client):
    today = _today(authed_client)
    assert _put(authed_client, today, "brunch").status_code == 422  # not a day occasion
    assert _put(authed_client, today, dress="black_tie").status_code == 422
    assert _put(authed_client, today, note="x" * 101).status_code == 422
    assert _put(authed_client, today, note="x" * 100).status_code == 200

    past = _put(authed_client, today - timedelta(days=1))
    assert past.status_code == 422
    assert past.json()["detail"]["error"] == "past_date"
    assert _put(authed_client, today + timedelta(days=400)).json()["detail"]["error"] == "too_far"
    bad_until = _put(authed_client, today + timedelta(days=3), until=today)
    assert bad_until.json()["detail"]["error"] == "bad_until"

    r = authed_client.get(BASE, params={"from": today.isoformat(), "to": (today - timedelta(days=1)).isoformat()})
    assert r.json()["detail"]["error"] == "bad_range"
    r = authed_client.get(BASE, params={"from": today.isoformat(), "to": (today + timedelta(days=62)).isoformat()})
    assert r.json()["detail"]["error"] == "bad_range"


def test_clearing_a_one_off_day_removes_it(authed_client, db):
    day = _today(authed_client) + timedelta(days=1)
    _put(authed_client, day)
    r = authed_client.delete(f"{BASE}/{day.isoformat()}")
    assert r.status_code == 200
    assert r.json()["plan"] is None
    assert db.query(DayPlan).count() == 0  # nothing to hide, so no skip row


def test_plans_are_per_user(authed_client, make_user, auth_headers):
    day = _today(authed_client) + timedelta(days=1)
    _put(authed_client, day)
    other = make_user(email="other@example.com")
    r = authed_client.get(BASE, headers=auth_headers(other))
    assert all(d["plan"] is None for d in r.json()["days"])


# ---------------------------------------------------------------------------
# Repeats
# ---------------------------------------------------------------------------


def test_repeat_every_weekday_from_now_on(authed_client):
    day = _today(authed_client) + timedelta(days=1)
    r = _put(authed_client, day, "remote_day", "casual", scope="from_now")
    assert r.status_code == 200
    assert r.json()["source"] == "weekly"
    assert r.json()["repeats_weekly"] is True

    days = _days(authed_client, day, day + timedelta(days=21))
    for i in (0, 7, 14, 21):
        assert _occasion(days[day + timedelta(days=i)]) == "remote_day"
        assert days[day + timedelta(days=i)]["source"] == "weekly"
    assert days[day + timedelta(days=1)]["plan"] is None


def test_permanent_change_three_weeks_in_keeps_the_past(authed_client, db):
    """Repeat started 3 weeks ago; "every Thursday from now on" changes the
    future only — the past Thursdays still show what was planned then."""
    user = authed_client.test_user
    next_one = _today(authed_client) + timedelta(days=7)
    _seed_rule(
        db, user, weekday=next_one.weekday(), occasion="work_day",
        starts_on=next_one - timedelta(days=28),
    )

    r = _put(authed_client, next_one, "remote_day", "casual", scope="from_now")
    assert r.status_code == 200

    days = _days(authed_client, next_one - timedelta(days=28), next_one + timedelta(days=14))
    for weeks_back in (1, 2, 3, 4):
        assert _occasion(days[next_one - timedelta(days=7 * weeks_back)]) == "work_day"
    for weeks_on in (0, 1, 2):
        assert _occasion(days[next_one + timedelta(days=7 * weeks_on)]) == "remote_day"

    rules = db.query(WeeklyPlanRule).order_by(WeeklyPlanRule.starts_on).all()
    assert [(r.occasion, r.starts_on, r.ends_on) for r in rules] == [
        ("work_day", next_one - timedelta(days=28), next_one - timedelta(days=1)),
        ("remote_day", next_one, None),
    ]


def test_stop_repeating_keeps_the_past(authed_client, db):
    user = authed_client.test_user
    next_one = _today(authed_client) + timedelta(days=7)
    _seed_rule(
        db, user, weekday=next_one.weekday(), occasion="work_day",
        starts_on=next_one - timedelta(days=21),
    )

    r = authed_client.delete(f"{BASE}/{next_one.isoformat()}", params={"scope": "from_now"})
    assert r.status_code == 200
    assert r.json() == {
        "date": next_one.isoformat(), "plan": None, "source": None, "repeats_weekly": False,
    }
    days = _days(authed_client, next_one - timedelta(days=21), next_one + timedelta(days=14))
    assert _occasion(days[next_one - timedelta(days=14)]) == "work_day"
    assert _occasion(days[next_one - timedelta(days=7)]) == "work_day"
    assert days[next_one]["plan"] is None
    assert days[next_one + timedelta(days=7)]["plan"] is None


def test_temporary_change_for_one_day(authed_client):
    day = _today(authed_client) + timedelta(days=1)
    _put(authed_client, day, "work_day", scope="from_now")

    r = _put(authed_client, day + timedelta(days=7), "travel", "casual")
    assert r.json()["source"] == "day"
    assert r.json()["repeats_weekly"] is True  # the client knows it's an exception

    days = _days(authed_client, day, day + timedelta(days=14))
    assert _occasion(days[day]) == "work_day"
    assert _occasion(days[day + timedelta(days=7)]) == "travel"
    assert _occasion(days[day + timedelta(days=14)]) == "work_day"  # repeat resumes


def test_temporary_change_until_a_date(authed_client):
    day = _today(authed_client) + timedelta(days=1)
    _put(authed_client, day, "work_day", scope="from_now")

    _put(authed_client, day, "remote_day", "casual", until=day + timedelta(days=14))

    days = _days(authed_client, day, day + timedelta(days=28))
    for i in (0, 7, 14):
        assert _occasion(days[day + timedelta(days=i)]) == "remote_day"
    assert _occasion(days[day + timedelta(days=21)]) == "work_day"
    assert days[day + timedelta(days=1)]["plan"] is None  # other weekdays untouched


def test_clearing_one_repeating_day_skips_just_that_date(authed_client):
    day = _today(authed_client) + timedelta(days=1)
    _put(authed_client, day, "work_day", scope="from_now")

    r = authed_client.delete(f"{BASE}/{day.isoformat()}")
    assert r.json() == {
        "date": day.isoformat(), "plan": None, "source": None, "repeats_weekly": True,
    }
    days = _days(authed_client, day, day + timedelta(days=7))
    assert days[day]["plan"] is None
    assert _occasion(days[day + timedelta(days=7)]) == "work_day"


def test_clearing_a_stretch_of_repeating_days(authed_client):
    day = _today(authed_client) + timedelta(days=1)
    _put(authed_client, day, "work_day", scope="from_now")

    authed_client.delete(
        f"{BASE}/{day.isoformat()}", params={"until": (day + timedelta(days=7)).isoformat()}
    )
    days = _days(authed_client, day, day + timedelta(days=14))
    assert days[day]["plan"] is None
    assert days[day + timedelta(days=7)]["plan"] is None
    assert _occasion(days[day + timedelta(days=14)]) == "work_day"


def test_a_new_repeat_drops_old_skips_but_keeps_one_off_plans(authed_client):
    day = _today(authed_client) + timedelta(days=1)
    _put(authed_client, day, "work_day", scope="from_now")
    authed_client.delete(f"{BASE}/{(day + timedelta(days=7)).isoformat()}")  # skip
    _put(authed_client, day + timedelta(days=14), "interview", "business")  # one-off

    _put(authed_client, day, "remote_day", "casual", scope="from_now")

    days = _days(authed_client, day, day + timedelta(days=21))
    assert _occasion(days[day]) == "remote_day"
    assert _occasion(days[day + timedelta(days=7)]) == "remote_day"  # skip went with the old repeat
    assert _occasion(days[day + timedelta(days=14)]) == "interview"  # deliberate edit stays
    assert _occasion(days[day + timedelta(days=21)]) == "remote_day"


def test_saving_from_now_on_a_day_with_its_own_plan_shows_the_repeat(authed_client):
    day = _today(authed_client) + timedelta(days=1)
    _put(authed_client, day, "interview", "business")
    r = _put(authed_client, day, "work_day", scope="from_now")
    assert r.json()["source"] == "weekly"
    assert r.json()["plan"]["occasion"] == "work_day"


def test_repeat_until_a_date(authed_client):
    day = _today(authed_client) + timedelta(days=1)
    _put(authed_client, day, "school", scope="from_now", until=day + timedelta(days=7))
    days = _days(authed_client, day, day + timedelta(days=14))
    assert _occasion(days[day]) == "school"
    assert _occasion(days[day + timedelta(days=7)]) == "school"
    assert days[day + timedelta(days=14)]["plan"] is None


def test_replacing_a_repeat_on_its_first_day(authed_client, db):
    day = _today(authed_client) + timedelta(days=1)
    _put(authed_client, day, "work_day", scope="from_now")
    _put(authed_client, day, "remote_day", "casual", scope="from_now")
    rules = db.query(WeeklyPlanRule).all()
    assert [(r.occasion, r.starts_on, r.ends_on) for r in rules] == [("remote_day", day, None)]


def test_clear_from_now_rejects_until(authed_client):
    day = _today(authed_client) + timedelta(days=1)
    r = authed_client.delete(
        f"{BASE}/{day.isoformat()}",
        params={"scope": "from_now", "until": (day + timedelta(days=7)).isoformat()},
    )
    assert r.status_code == 422
    assert r.json()["detail"]["error"] == "bad_until"


# ---------------------------------------------------------------------------
# Elsewhere: dashboard frame, data export, occasion mapping
# ---------------------------------------------------------------------------


def test_dashboard_carries_today_and_tomorrow(authed_client):
    today = _today(authed_client)
    _put(authed_client, today + timedelta(days=1), "workout", "athleisure")
    r = authed_client.get("/api/v1/today/dashboard")
    assert r.status_code == 200
    plans = r.json()["day_plans"]
    assert [p["date"] for p in plans] == [today.isoformat(), (today + timedelta(days=1)).isoformat()]
    assert plans[0]["plan"] is None
    assert plans[1]["plan"]["occasion"] == "workout"


def test_data_export_includes_plans(authed_client):
    day = _today(authed_client) + timedelta(days=1)
    _put(authed_client, day, "interview", "business", note="Pitch")
    _put(authed_client, day + timedelta(days=1), "work_day", scope="from_now")
    r = authed_client.get("/api/v1/account/export")
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["day_plans"][0]["note"] == "Pitch"
    assert body["weekly_plan_rules"][0]["occasion"] == "work_day"


def test_every_day_occasion_maps_to_a_stylist_occasion():
    assert set(OUTFIT_OCCASION) == set(get_args(DayOccasion))
    assert set(OUTFIT_OCCASION.values()) <= set(occasion_rules.occasion_keys())
