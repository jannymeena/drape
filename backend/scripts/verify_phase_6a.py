"""Phase 6a verify — AIProvider (mock + real) + WeatherProvider (Open-Meteo).

Usage (from backend/, with the venv active):

    python scripts/verify_phase_6a.py

The five checks correspond to plan.md §7 Phase 6a Verify:

  1. ai.chat() returns a non-empty string.
  2. ai.analyze_image() returns a JSON string parseable by the scanner service.
  3. weather.current(43.65, -79.38) returns Toronto weather (real Open-Meteo call).
  4. Network failures bubble up as typed AIProviderError / WeatherProviderError.
  5. With ANTHROPIC_API_KEY unset in dev, providers.ai is MockAIProvider and the
     four checks above all pass against canned responses.

Real-key path: if ANTHROPIC_API_KEY is set, the AI checks hit the real API.
"""
from __future__ import annotations

import asyncio
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.core.config import settings  # noqa: E402
from app.core.providers import providers  # noqa: E402
from app.services.providers.ai.base import AIProviderError  # noqa: E402
from app.services.providers.ai.mock import MockAIProvider  # noqa: E402
from app.services.providers.weather.base import WeatherProviderError  # noqa: E402
from app.services.providers.weather.open_meteo import OpenMeteoProvider  # noqa: E402


def _ok(label: str, detail: str = "") -> None:
    suffix = f" — {detail}" if detail else ""
    print(f"  [PASS] {label}{suffix}")


def _fail(label: str, detail: str) -> None:
    print(f"  [FAIL] {label} — {detail}")


async def check_chat() -> bool:
    print("[1] ai.chat() returns a non-empty string")
    try:
        out = await providers.ai.chat([{"role": "user", "content": "hello"}])
    except Exception as exc:  # noqa: BLE001
        _fail("chat", f"raised: {exc!r}")
        return False
    if not isinstance(out, str) or not out:
        _fail("chat", f"non-string or empty: {out!r}")
        return False
    _ok("chat", f"len={len(out)}, preview={out[:60]!r}")
    return True


async def check_analyze_image() -> bool:
    print("[2] ai.analyze_image() returns scanner-parseable JSON")
    fake_jpeg = b"\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01" + b"\x00" * 64
    try:
        out = await providers.ai.analyze_image(fake_jpeg, "describe", media_type="image/jpeg")
    except Exception as exc:  # noqa: BLE001
        _fail("analyze_image", f"raised: {exc!r}")
        return False
    if not isinstance(out, str) or not out:
        _fail("analyze_image", f"non-string or empty: {out!r}")
        return False
    try:
        parsed = json.loads(out)
    except json.JSONDecodeError as exc:
        _fail("analyze_image", f"not parseable JSON: {exc} — out={out[:200]!r}")
        return False
    expected = {"category", "color", "pattern", "formality", "confidence"}
    missing = expected - set(parsed.keys()) if isinstance(parsed, dict) else expected
    if missing:
        _fail("analyze_image", f"missing keys: {missing} — parsed={parsed!r}")
        return False
    _ok("analyze_image", f"keys={sorted(parsed.keys())}")
    return True


async def check_weather() -> bool:
    print("[3] weather.current(43.65, -79.38) returns Toronto weather")
    try:
        snap = await providers.weather.current(43.65, -79.38)
    except WeatherProviderError as exc:
        _fail("weather", f"WeatherProviderError({exc.code}): {exc}")
        return False
    except Exception as exc:  # noqa: BLE001
        _fail("weather", f"unexpected exception: {exc!r}")
        return False
    if not (-60.0 <= snap.temp_c <= 60.0):
        _fail("weather", f"temp_c outside plausible range: {snap.temp_c}")
        return False
    _ok("weather", f"temp_c={snap.temp_c}, condition={snap.condition}")
    return True


async def check_typed_errors() -> bool:
    print("[4] Network failures bubble up as typed errors (not raw httpx)")
    bad = OpenMeteoProvider()
    try:
        # Out-of-range lat → Open-Meteo returns 400 → we wrap into WeatherProviderError.
        await bad.current(999.0, 999.0)
    except WeatherProviderError as exc:
        _ok("WeatherProviderError", f"code={exc.code}")
    except Exception as exc:  # noqa: BLE001
        _fail("weather typed error", f"got non-typed: {exc!r}")
        return False
    else:
        _fail("weather typed error", "no exception raised on bad coords")
        return False

    # AI typed-error check only fires for the real provider; mock never hits the network.
    if isinstance(providers.ai, MockAIProvider):
        _ok("AIProviderError (skipped — MockAIProvider doesn't hit network)")
        return True

    from app.services.providers.ai.anthropic import AnthropicProvider

    bad_ai = AnthropicProvider("sk-ant-invalid-key-for-testing")
    try:
        await bad_ai.chat([{"role": "user", "content": "hello"}])
    except AIProviderError as exc:
        _ok("AIProviderError", f"code={exc.code}")
        return True
    except Exception as exc:  # noqa: BLE001
        _fail("AI typed error", f"got non-typed: {exc!r}")
        return False
    _fail("AI typed error", "no exception raised on bad key")
    return False


def check_mock_wired() -> bool:
    print("[5] In dev with no ANTHROPIC_API_KEY, providers.ai is MockAIProvider")
    if settings.environment != "dev":
        _ok("mock-wired", f"skipped (ENVIRONMENT={settings.environment!r})")
        return True
    if settings.anthropic_api_key:
        _ok("mock-wired", "skipped (ANTHROPIC_API_KEY is set; using real provider)")
        return True
    if isinstance(providers.ai, MockAIProvider):
        _ok("mock-wired", "providers.ai is MockAIProvider")
        return True
    _fail("mock-wired", f"providers.ai is {type(providers.ai).__name__}")
    return False


async def main() -> int:
    print(f"=== Phase 6a verify (ENVIRONMENT={settings.environment}) ===")
    print(f"providers.ai      = {type(providers.ai).__name__}")
    print(f"providers.weather = {type(providers.weather).__name__}")
    print()

    results = [
        await check_chat(),
        await check_analyze_image(),
        await check_weather(),
        await check_typed_errors(),
        check_mock_wired(),
    ]
    print()
    passed = sum(1 for r in results if r)
    total = len(results)
    print(f"=== {passed}/{total} checks passed ===")
    return 0 if passed == total else 1


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
