"""Shared fake providers for outfit-generation tests."""
from __future__ import annotations

import json
import re

from app.services.providers.ai.base import AIProvider
from app.services.providers.weather.base import WeatherProvider, WeatherSnapshot

_ID_RE = re.compile(r"id=(\d+)")


class PickAll(AIProvider):
    """Returns the first offered wardrobe ids (up to 4); records the last
    prompt and system context. Subclasses script `chat` as they need."""

    def __init__(self) -> None:
        self.prompt = ""
        self.system = ""

    async def chat(self, messages, *, model=None, system=None, max_tokens=1024, cache_system=False):
        self.prompt = messages[-1]["content"]
        self.system = system or ""
        return json.dumps(
            {
                "item_ids": _ID_RE.findall(system or "")[:4],
                "reasoning_short": "Sharp.",
                "reasoning_full": "Sharp and simple.",
                "per_item_rationales": {},
                "compatibility_score": 80,
                "factors": [],
            }
        )

    async def analyze_image(self, image_bytes, prompt, *, media_type="image/jpeg", model=None, max_tokens=1024):
        raise NotImplementedError


class Weather(WeatherProvider):
    def __init__(self, feels_like_c: float = 18.0) -> None:
        self.feels = feels_like_c

    async def current(self, lat, lon):
        return WeatherSnapshot(
            temp_c=self.feels, feels_like_c=self.feels, condition="clear",
            humidity_pct=50, wind_kph=5.0,
        )
