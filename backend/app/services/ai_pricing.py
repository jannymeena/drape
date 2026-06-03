"""Per-model Claude pricing → cost estimation for the dev usage log (§5.3).

All values are USD per 1,000,000 tokens (MTok). Source: Anthropic "Model pricing"
table. `cost_usd()` uses `input` + `output`; the cache_* columns are recorded for
§5.4 (prompt caching) and aren't used yet. Not used for billing.
"""
from __future__ import annotations

# Columns: input (base) · output · cache_write_5m · cache_write_1h · cache_read.
PRICING: dict[str, dict[str, float]] = {
    # Opus 4.5–4.8 (current tier)
    "claude-opus-4-8": {"input": 5, "output": 25, "cache_write_5m": 6.25, "cache_write_1h": 10, "cache_read": 0.50},
    "claude-opus-4-7": {"input": 5, "output": 25, "cache_write_5m": 6.25, "cache_write_1h": 10, "cache_read": 0.50},
    "claude-opus-4-6": {"input": 5, "output": 25, "cache_write_5m": 6.25, "cache_write_1h": 10, "cache_read": 0.50},
    "claude-opus-4-5": {"input": 5, "output": 25, "cache_write_5m": 6.25, "cache_write_1h": 10, "cache_read": 0.50},
    # Opus 4.1 / 4 (older tier — pricier)
    "claude-opus-4-1": {"input": 15, "output": 75, "cache_write_5m": 18.75, "cache_write_1h": 30, "cache_read": 1.50},
    "claude-opus-4-0": {"input": 15, "output": 75, "cache_write_5m": 18.75, "cache_write_1h": 30, "cache_read": 1.50},  # Opus 4 (deprecated)
    # Sonnet 4.x
    "claude-sonnet-4-6": {"input": 3, "output": 15, "cache_write_5m": 3.75, "cache_write_1h": 6, "cache_read": 0.30},
    "claude-sonnet-4-5": {"input": 3, "output": 15, "cache_write_5m": 3.75, "cache_write_1h": 6, "cache_read": 0.30},
    "claude-sonnet-4-0": {"input": 3, "output": 15, "cache_write_5m": 3.75, "cache_write_1h": 6, "cache_read": 0.30},  # Sonnet 4 (deprecated)
    # Haiku
    "claude-haiku-4-5": {"input": 1, "output": 5, "cache_write_5m": 1.25, "cache_write_1h": 2, "cache_read": 0.10},
    "claude-3-5-haiku": {"input": 0.80, "output": 4, "cache_write_5m": 1, "cache_write_1h": 1.60, "cache_read": 0.08},  # Haiku 3.5 (retired exc. Bedrock/Vertex)
}

# Default per family when a model id matches no key/prefix (latest/current tier).
_FAMILY_DEFAULT: dict[str, str] = {
    "opus": "claude-opus-4-8",
    "sonnet": "claude-sonnet-4-6",
    "haiku": "claude-haiku-4-5",
}
_FALLBACK = "claude-sonnet-4-6"


def _rate(model: str) -> dict[str, float]:
    if model in PRICING:
        return PRICING[model]
    # Dated suffix, e.g. "claude-opus-4-1-20250805" → "claude-opus-4-1".
    for key in sorted(PRICING, key=len, reverse=True):
        if model.startswith(key):
            return PRICING[key]
    # Unknown id: fall back to the family's current tier.
    for fam, default in _FAMILY_DEFAULT.items():
        if fam in model:
            return PRICING[default]
    return PRICING[_FALLBACK]


def cost_usd(model: str, input_tokens: int, output_tokens: int) -> float:
    """Estimated USD cost for a single call (base input + output tokens)."""
    p = _rate(model)
    return input_tokens * p["input"] / 1_000_000 + output_tokens * p["output"] / 1_000_000
