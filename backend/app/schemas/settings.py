from typing import Literal

from pydantic import BaseModel, ConfigDict

Theme = Literal["light", "dark", "auto"]
UnitSystem = Literal["metric", "imperial"]


class SettingsResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    push_enabled: bool
    daily_outfit_suggestions: bool
    outfit_reminders: bool
    shopping_suggestions: bool
    wardrobe_insights: bool
    quiet_hours_enabled: bool
    email_weekly_summary: bool
    email_product_deals: bool
    email_pro_offers: bool
    theme: Theme
    unit_system: UnitSystem
    style_preferences: dict | None = None


class SettingsUpdate(BaseModel):
    """All optional — only provided fields are written (`exclude_unset`)."""

    push_enabled: bool | None = None
    daily_outfit_suggestions: bool | None = None
    outfit_reminders: bool | None = None
    shopping_suggestions: bool | None = None
    wardrobe_insights: bool | None = None
    quiet_hours_enabled: bool | None = None
    email_weekly_summary: bool | None = None
    email_product_deals: bool | None = None
    email_pro_offers: bool | None = None
    theme: Theme | None = None
    unit_system: UnitSystem | None = None
    style_preferences: dict | None = None
