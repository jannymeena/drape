"""Weekly trend brief: web research per audience, stored, refreshed weekly by
the worker, and fed to the outfit + advisor prompts while fresh."""
from __future__ import annotations

import asyncio
from datetime import date, datetime, timedelta, timezone

import pytest

from app.db.models import TrendBrief
from app.services import outfit_service, trend_service
from app.services.providers.ai.anthropic import AnthropicProvider
from app.services.providers.ai.base import AIProviderError, ResearchResult
from app.workers.trend_worker import TrendWorker
from tests.services.test_outfit_shop_fill import _PickAll

NOW = datetime(2026, 10, 1, 12, tzinfo=timezone.utc)


class _Researcher(_PickAll):
    """A fake provider whose web research returns a canned brief."""

    def __init__(self, text: str = "- Dresses with knee boots\n- Chocolate brown") -> None:
        super().__init__()
        self.text = text
        self.prompts: list[str] = []

    async def web_research(self, prompt, *, model, system=None, max_searches=6, country=None):
        self.prompts.append(prompt)
        return ResearchResult(
            text=self.text, model=model, sources=[{"url": "https://vogue.com/x", "title": "Vogue"}]
        )


def _brief(db, audience: str, age: timedelta, text: str = "- old news") -> TrendBrief:
    row = TrendBrief(
        audience=audience, brief=text, sources=[], model="m", created_at=NOW - age
    )
    db.add(row)
    db.commit()
    return row


def _refresh(db, ai, audience="womens", now=NOW):
    return asyncio.run(
        trend_service.refresh_if_due(db, ai=ai, audience=audience, model="claude-sonnet-5-5", now=now)
    )


def test_research_prompt_names_audience_month_and_season():
    prompt = trend_service.research_prompt("mens", date(2026, 10, 1))
    assert "menswear" in prompt and "October 2026" in prompt and "fall in Canada" in prompt
    assert "Search the web first" in prompt
    assert "winter" in trend_service.research_prompt("womens", date(2026, 1, 5))


def test_first_refresh_researches_and_stores(db):
    ai = _Researcher()
    row = _refresh(db, ai)
    assert row is not None
    assert row.audience == "womens"
    assert row.brief.startswith("- Dresses with knee boots")
    assert row.sources == [{"url": "https://vogue.com/x", "title": "Vogue"}]
    assert "womenswear" in ai.prompts[0]


def test_fresh_brief_is_not_researched_again(db):
    _brief(db, "womens", timedelta(days=3))
    ai = _Researcher()
    assert _refresh(db, ai) is None
    assert ai.prompts == []


def test_week_old_brief_is_refreshed(db):
    _brief(db, "womens", timedelta(days=7))
    assert _refresh(db, _Researcher()) is not None
    assert db.query(TrendBrief).count() == 2


def test_empty_research_stores_nothing(db):
    with pytest.raises(AIProviderError):
        _refresh(db, _Researcher(text="   "))
    assert db.query(TrendBrief).count() == 0


def test_briefs_for_picks_the_audience_and_skips_stale(db):
    _brief(db, "womens", timedelta(days=2), "- womens now")
    _brief(db, "mens", timedelta(days=30), "- mens stale")
    assert [b.brief for b in trend_service.briefs_for(db, shopping_style="womens", now=NOW)] == [
        "- womens now"
    ]
    assert trend_service.briefs_for(db, shopping_style="mens", now=NOW) == []
    # Shops for everything -> every fresh audience.
    assert [b.audience for b in trend_service.briefs_for(db, shopping_style=None, now=NOW)] == [
        "womens"
    ]


def test_prompt_block_is_empty_without_briefs():
    assert trend_service.prompt_block([]) == ""


def test_outfit_system_prompt_carries_the_brief(db):
    brief = _brief(db, "womens", timedelta(days=1), "- Dresses with knee boots")
    system = outfit_service._build_system_context(
        items=[],
        style_goals=None,
        using_starter_wardrobe=False,
        trends=trend_service.prompt_block([brief]),
    )
    assert "What's in fashion right now" in system
    assert "Womenswear, researched 30 September 2026:\n- Dresses with knee boots" in system
    assert system.index("What's in fashion") < system.index("Respond with ONLY")


def test_advisor_sees_the_brief(authed_client, db):
    from tests.api.routes.test_shop import _ShopAI, _use_shop_ai

    user = authed_client.test_user
    user.shopping_style = "womens"
    db.commit()
    db.add(TrendBrief(audience="womens", brief="- Chocolate brown", sources=[], model="m"))
    db.commit()
    _use_shop_ai()
    authed_client.post("/api/v1/shop/advisor/ask", json={"question": "What's in?"})
    assert "- Chocolate brown" in _ShopAI.calls[-1]["system"]


# ---------------------------------------------------------------------------
# Worker
# ---------------------------------------------------------------------------


class _Broken(_Researcher):
    async def web_research(self, prompt, **kwargs):
        raise AIProviderError("ai_call_failed", "search is down")


def test_worker_survives_failures_and_backs_off(session_factory):
    worker = TrendWorker(session_factory=session_factory, ai=_Broken(), model="m")
    asyncio.run(worker.refresh_once())  # must not raise
    assert set(worker._retry_at) == {"womens", "mens"}


def test_worker_fills_every_audience(session_factory, db):
    worker = TrendWorker(session_factory=session_factory, ai=_Researcher(), model="m")
    asyncio.run(worker.refresh_once())
    assert sorted(b.audience for b in db.query(TrendBrief)) == ["mens", "womens"]


# ---------------------------------------------------------------------------
# Anthropic provider: web search tool, pause_turn, sources
# ---------------------------------------------------------------------------


class _Obj:
    def __init__(self, **kw):
        self.__dict__.update(kw)


def _usage(searches: int = 1):
    return _Obj(input_tokens=1000, output_tokens=200,
                server_tool_use=_Obj(web_search_requests=searches))


class _Messages:
    def __init__(self, responses):
        self.responses = list(responses)
        self.calls: list[dict] = []

    async def create(self, **kwargs):
        self.calls.append(kwargs)
        return self.responses.pop(0)


def _provider(responses) -> AnthropicProvider:
    p = AnthropicProvider("k", text_model="claude-sonnet-5-5", vision_model="claude-haiku-4-5")
    p._client = _Obj(messages=_Messages(responses))
    return p


def test_web_research_resumes_after_pause_and_collects_cited_sources():
    paused = _Obj(
        stop_reason="pause_turn",
        usage=_usage(),
        content=[
            _Obj(type="text", text="Let me search.", citations=None),
            _Obj(type="server_tool_use"),
        ],
    )
    done = _Obj(
        stop_reason="end_turn",
        usage=_usage(),
        content=[
            _Obj(type="web_search_tool_result",
                 content=[_Obj(url="https://elle.com/a", title="Elle")]),
            _Obj(type="text", text="- Knee boots with dresses\n",
                 citations=[_Obj(url="https://vogue.com/b", title="Vogue")]),
            _Obj(type="text", text="- Brown is the new black", citations=None),
        ],
    )
    provider = _provider([paused, done])
    result = asyncio.run(
        provider.web_research("q", model="claude-sonnet-5-5", system="s", country="CA")
    )
    assert result.text == "- Knee boots with dresses\n- Brown is the new black"
    assert result.sources == [{"url": "https://vogue.com/b", "title": "Vogue"}]

    first, second = provider._client.messages.calls
    assert first["tools"] == [{
        "type": "web_search_20260209", "name": "web_search", "max_uses": 6,
        "user_location": {"type": "approximate", "country": "CA"},
    }]
    assert first["output_config"] == {"effort": "medium"}
    # Resumed with the paused assistant turn appended — no extra user message.
    assert [m["role"] for m in second["messages"]] == ["user", "assistant"]


def test_web_research_falls_back_to_search_results_for_sources():
    done = _Obj(
        stop_reason="end_turn",
        usage=_usage(),
        content=[
            _Obj(type="web_search_tool_result",
                 content=[_Obj(url="https://elle.com/a", title="Elle")]),
            _Obj(type="text", text="- Trend", citations=None),
        ],
    )
    result = asyncio.run(_provider([done]).web_research("q", model="claude-sonnet-5-5"))
    assert result.sources == [{"url": "https://elle.com/a", "title": "Elle"}]


def test_web_research_on_haiku_uses_the_basic_tool_without_effort():
    done = _Obj(stop_reason="end_turn", usage=_usage(),
                content=[_Obj(type="text", text="- Trend", citations=None)])
    provider = _provider([done])
    asyncio.run(provider.web_research("q", model="claude-haiku-4-5"))
    call = provider._client.messages.calls[0]
    assert call["tools"][0]["type"] == "web_search_20250305"
    assert "output_config" not in call


def test_web_research_gives_up_after_repeated_pauses():
    paused = [
        _Obj(stop_reason="pause_turn", usage=_usage(), content=[_Obj(type="server_tool_use")])
        for _ in range(5)
    ]
    with pytest.raises(AIProviderError) as exc:
        asyncio.run(_provider(paused).web_research("q", model="claude-sonnet-5-5"))
    assert exc.value.code == "research_incomplete"


def test_long_brief_is_cut_at_a_bullet_boundary(db):
    bullet = "- " + "word " * 60 + "\n"
    row = _refresh(db, _Researcher(text=bullet * 20))
    assert len(row.brief) <= 2500
    assert row.brief.endswith("word")  # a whole bullet, not a half-written one
    assert row.brief.count("\n- ") + 1 == len(row.brief.split("\n"))
