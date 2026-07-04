import uuid
from datetime import datetime
from enum import Enum as PyEnum
from typing import Optional

from sqlalchemy import (
    UUID,
    Boolean,
    Date,
    DateTime,
    Enum,
    ForeignKey,
    Integer,
    LargeBinary,
    Numeric,
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TimestampMixin
from app.schemas.user import Role


class AuthMethod(str, PyEnum):
    email = "email"
    apple = "apple"
    google = "google"


class User(Base, TimestampMixin):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    email: Mapped[str] = mapped_column(String(255), unique=True, nullable=False, index=True)
    role: Mapped[Role] = mapped_column(
        Enum(Role, name="user_role"), nullable=False, default=Role.customer
    )
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    display_name: Mapped[str] = mapped_column(String(120), nullable=False)

    password_hash: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    auth_method: Mapped[AuthMethod] = mapped_column(
        Enum(AuthMethod, name="auth_method"), nullable=False
    )
    apple_id: Mapped[Optional[str]] = mapped_column(
        String(255), unique=True, index=True, nullable=True
    )
    google_id: Mapped[Optional[str]] = mapped_column(
        String(255), unique=True, index=True, nullable=True
    )
    agreed_to_terms: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    agreed_to_privacy: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    terms_agreed_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    # Onboarding state (filled in by Phase 5 routes; defaults are correct for new signups).
    onboarding_completed: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False
    )
    onboarding_last_step: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)

    # Phase 5a — profile setup. shopping_style and style_goals are required to finish
    # onboarding; age_range, location, timezone are optional. CHECK constraints are
    # enforced by Pydantic Literal types in app/schemas/profile.py rather than DB CHECKs,
    # so adding a value (e.g. a new age band) doesn't require a migration.
    shopping_style: Mapped[Optional[str]] = mapped_column(String(30), nullable=True)
    age_range: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    style_goals: Mapped[Optional[list[str]]] = mapped_column(JSONB, nullable=True)
    timezone: Mapped[Optional[str]] = mapped_column(String(64), nullable=True)
    location: Mapped[Optional[str]] = mapped_column(String(120), nullable=True)
    # Editable profile-tab fields (no onboarding step writes these; the Edit
    # Profile screen does). Free-text, validated by Pydantic on the way in.
    gender: Mapped[Optional[str]] = mapped_column(String(30), nullable=True)
    phone: Mapped[Optional[str]] = mapped_column(String(40), nullable=True)
    # Opt-in to sharing the avatar in the (future) DRAPE Community feed.
    community_share_avatar: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False, server_default="false"
    )
    subscription_tier: Mapped[str] = mapped_column(
        String(20), nullable=False, default="free", server_default="free"
    )

    profile: Mapped[Optional["Profile"]] = relationship(
        back_populates="user", uselist=False, cascade="all, delete-orphan"
    )
    settings: Mapped[Optional["UserSettings"]] = relationship(
        back_populates="user", uselist=False, cascade="all, delete-orphan"
    )

    @property
    def avatar_url(self) -> Optional[str]:
        """The user's avatar lives on the 1:1 profile row; surface it here so
        `UserResponse` can expose it without the client knowing about profiles."""
        return self.profile.avatar_url if self.profile else None


class Profile(Base, TimestampMixin):
    __tablename__ = "profiles"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
    )
    avatar_url: Mapped[Optional[str]] = mapped_column(String(512), nullable=True)
    bio: Mapped[Optional[str]] = mapped_column(String(2000), nullable=True)
    # Body/skin analysis derived once from the avatar photo (§5.5): a small
    # {body_type, skin_tone, styling_notes} blob fed into outfit generation so
    # suggestions account for the wearer. Null until an avatar is analyzed.
    body_analysis: Mapped[Optional[dict]] = mapped_column(JSONB, nullable=True)

    user: Mapped["User"] = relationship(back_populates="profile")


class UserSettings(Base, TimestampMixin):
    """1:1 user preferences for the Settings tab (notifications, appearance,
    units) plus a flexible JSONB blob for style preferences. Get-or-created on
    first read so every user has sensible defaults without a signup-time write."""

    __tablename__ = "user_settings"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
    )

    # Notifications
    push_enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True, server_default="true")
    daily_outfit_suggestions: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True, server_default="true")
    outfit_reminders: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True, server_default="true")
    shopping_suggestions: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True, server_default="true")
    wardrobe_insights: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True, server_default="true")
    quiet_hours_enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False, server_default="false")
    email_weekly_summary: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True, server_default="true")
    email_product_deals: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False, server_default="false")
    email_pro_offers: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False, server_default="false")

    # Appearance + units
    theme: Mapped[str] = mapped_column(String(10), nullable=False, default="light", server_default="light")
    unit_system: Mapped[str] = mapped_column(String(10), nullable=False, default="metric", server_default="metric")

    # Flexible style-preferences blob (archetypes, boldness, etc.).
    style_preferences: Mapped[Optional[dict]] = mapped_column(JSONB, nullable=True)

    user: Mapped["User"] = relationship(back_populates="settings")


class SupportTicket(Base, TimestampMixin):
    """A contact / feature-request / bug-report submission. We persist rather
    than email so there's an auditable record; an email/queue side-effect can be
    added later behind the same service call."""

    __tablename__ = "support_tickets"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    kind: Mapped[str] = mapped_column(String(20), nullable=False, index=True)  # contact|feature_request|bug_report
    subject: Mapped[Optional[str]] = mapped_column(String(200), nullable=True)
    message: Mapped[str] = mapped_column(String(5000), nullable=False)
    extra: Mapped[Optional[dict]] = mapped_column(JSONB, nullable=True)
    status: Mapped[str] = mapped_column(String(20), nullable=False, default="open", server_default="open")


class Subscription(Base, TimestampMixin):
    """One row per user. `users.subscription_tier` stays the fast entitlement
    switch every gate reads; this row is the billing record behind it.
    Cancellation is soft: cancel_at_period_end keeps Pro until the paid period
    lapses (lazy expiry on read — no scheduler needed pre-launch)."""

    __tablename__ = "subscriptions"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
    )
    plan: Mapped[str] = mapped_column(String(20), nullable=False)  # pro_monthly|pro_yearly
    status: Mapped[str] = mapped_column(  # active|canceled
        String(20), nullable=False, default="active", server_default="active"
    )
    price_cents: Mapped[int] = mapped_column(Integer, nullable=False)
    currency: Mapped[str] = mapped_column(
        String(3), nullable=False, default="CAD", server_default="CAD"
    )
    current_period_start: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    current_period_end: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    cancel_at_period_end: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False, server_default="false"
    )
    canceled_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    cancellation_reason: Mapped[Optional[str]] = mapped_column(
        String(200), nullable=True
    )
    # none | offered | accepted — the 3-step cancellation retention state.
    retention_offer: Mapped[str] = mapped_column(
        String(20), nullable=False, default="none", server_default="none"
    )
    provider: Mapped[str] = mapped_column(String(20), nullable=False)  # mock|stripe
    provider_subscription_id: Mapped[Optional[str]] = mapped_column(
        String(255), nullable=True
    )


class BillingRecord(Base, TimestampMixin):
    """Append-only charge/credit history shown on the Billing History screen."""

    __tablename__ = "billing_history"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    description: Mapped[str] = mapped_column(String(200), nullable=False)
    amount_cents: Mapped[int] = mapped_column(Integer, nullable=False)
    currency: Mapped[str] = mapped_column(
        String(3), nullable=False, default="CAD", server_default="CAD"
    )
    status: Mapped[str] = mapped_column(  # paid|refunded|failed
        String(20), nullable=False, default="paid", server_default="paid"
    )
    invoice_number: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    occurred_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )


class PaymentMethod(Base, TimestampMixin):
    """Stored payment instrument (tokenized upstream; we keep display fields)."""

    __tablename__ = "payment_methods"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    kind: Mapped[str] = mapped_column(String(20), nullable=False)  # card|apple_pay
    brand: Mapped[str] = mapped_column(String(20), nullable=False)
    last4: Mapped[str] = mapped_column(String(4), nullable=False)
    exp_month: Mapped[int] = mapped_column(Integer, nullable=False)
    exp_year: Mapped[int] = mapped_column(Integer, nullable=False)
    is_default: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False, server_default="false"
    )
    provider_payment_method_id: Mapped[str] = mapped_column(
        String(255), nullable=False
    )


class FeatureRequestVote(Base, TimestampMixin):
    """Public up/down vote on a feature-request ticket. One row per
    (user, ticket); vote is +1 or -1, and clearing a vote deletes the row."""

    __tablename__ = "feature_request_votes"
    __table_args__ = (UniqueConstraint("user_id", "ticket_id"),)

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    ticket_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("support_tickets.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    vote: Mapped[int] = mapped_column(Integer, nullable=False)  # +1 | -1


class RefreshToken(Base):
    __tablename__ = "refresh_tokens"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    token_hash: Mapped[str] = mapped_column(String(64), unique=True, index=True, nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    revoked_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )


class WardrobeItem(Base, TimestampMixin):
    """A single garment in a user's wardrobe.

    Categorical fields (category, formality, pattern, season, added_via) are
    plain VARCHARs — Pydantic Literals in app/schemas/wardrobe.py are the
    source of truth for accepted values. Adding a new category doesn't need
    a migration.

    `cost_per_wear` is denormalized (purchase_price / worn_count) so the
    list view can sort/filter on it without a per-row computation. The
    service updates it whenever worn_count or purchase_price changes.
    """

    __tablename__ = "wardrobe_items"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    # Basic info
    name: Mapped[str] = mapped_column(String(200), nullable=False)
    category: Mapped[str] = mapped_column(String(50), nullable=False, index=True)
    subcategory: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)

    # Images — uploaded via POST /wardrobe/items/{id}/images (Phase 5e).
    images: Mapped[Optional[list[str]]] = mapped_column(JSONB, nullable=True)
    primary_image_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)

    # Attributes
    color_hex: Mapped[Optional[str]] = mapped_column(String(7), nullable=True)
    color_name: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    pattern: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    material: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    formality: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    season: Mapped[Optional[list[str]]] = mapped_column(JSONB, nullable=True)

    # Brand & purchase
    brand: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    purchase_price: Mapped[Optional[float]] = mapped_column(Numeric(10, 2), nullable=True)
    purchase_date: Mapped[Optional[datetime]] = mapped_column(Date, nullable=True)
    description: Mapped[Optional[str]] = mapped_column(String(2000), nullable=True)

    # Usage tracking
    worn_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0, index=True)
    last_worn: Mapped[Optional[datetime]] = mapped_column(Date, nullable=True)
    cost_per_wear: Mapped[Optional[float]] = mapped_column(
        Numeric(10, 2), nullable=True, index=True
    )

    # Favorites
    is_favorite: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False, index=True
    )
    favorited_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    # Starter wardrobe — Phase 5d.
    is_starter_wardrobe: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False, index=True
    )
    starter_template_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("starter_wardrobe_templates.id", ondelete="SET NULL"),
        nullable=True,
    )

    # Provenance
    added_via: Mapped[str] = mapped_column(String(20), nullable=False, default="manual")
    ai_detection_confidence: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)


class WardrobeWearLog(Base):
    """One row per (user, item, day). Drives worn_count / last_worn aggregates
    on wardrobe_items, plus the wear-history analytics in Phase 6d."""

    __tablename__ = "wardrobe_wear_log"
    __table_args__ = (
        UniqueConstraint("user_id", "item_id", "worn_date", name="uq_wear_log_user_item_date"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    item_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("wardrobe_items.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    worn_date: Mapped[datetime] = mapped_column(Date, nullable=False, index=True)
    logged_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )


class UserMeasurements(Base, TimestampMixin):
    """Body measurements stored as a single AES-256-GCM ciphertext blob.

    The plaintext is a UTF-8 JSON object: {"height_cm": 175.0, "weight_kg": 70.0, ...}.
    All values are in metric (cm/kg) regardless of the unit_system the user entered;
    the client converts before submitting.

    Storing as one opaque blob (rather than per-column) means:
      - PIPEDA: no operator with DB read can infer measurements without the DEK/KMS key.
      - Schema can grow (new fields like neck_cm) without a migration.
      - AAD = user_id ensures a row's ciphertext can't be relocated to another user.
    """

    __tablename__ = "user_measurements"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
    )
    ciphertext: Mapped[bytes] = mapped_column(LargeBinary, nullable=False)
    unit_system: Mapped[str] = mapped_column(String(10), nullable=False)
    is_complete: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    completed_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    # Reserved for KMS DEK rotation (Phase 7). Null while running on LocalAesEncryptor.
    encryption_key_id: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)


class StarterWardrobeTemplate(Base, TimestampMixin):
    """Curated outfit kit for new users to bootstrap outfit generation before
    they've added their own items. Seeded as static data in the init migration;
    `template_id` is a stable string the seed/code uses to reference a row.

    `items` is a JSONB array of item-shaped dicts (name/category/color_hex/...)
    matching the WardrobeItem column set the assignment service materializes.
    """

    __tablename__ = "starter_wardrobe_templates"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    template_id: Mapped[str] = mapped_column(
        String(100), unique=True, index=True, nullable=False
    )
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    gender: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    age_range: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    style_profile: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    total_items: Mapped[int] = mapped_column(Integer, nullable=False)
    items: Mapped[list[dict]] = mapped_column(JSONB, nullable=False)
    is_active: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=True, server_default="true"
    )
    version: Mapped[int] = mapped_column(
        Integer, nullable=False, default=1, server_default="1"
    )


class UserStarterWardrobe(Base):
    """Records that a user was assigned a starter wardrobe template, and
    whether it's still active. Auto-deactivates when the user has 15 real
    (non-starter) items — the threshold lives in starter_wardrobe_service.
    """

    __tablename__ = "user_starter_wardrobes"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
    )
    template_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("starter_wardrobe_templates.id", ondelete="RESTRICT"),
        nullable=False,
    )
    is_active: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=True, server_default="true"
    )
    assigned_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    deactivated_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    deactivation_reason: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)


class BannerDismissal(Base):
    """Per-user, per-banner "not now" timestamp (CTO doc 2 banner rules:
    dismissed banners stay hidden for 7 days). One row per (user, banner);
    re-dismissing refreshes dismissed_at."""

    __tablename__ = "banner_dismissals"
    __table_args__ = (UniqueConstraint("user_id", "banner"),)

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    banner: Mapped[str] = mapped_column(String(50), nullable=False)
    dismissed_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )


class WardrobeTransitionTracking(Base):
    """One row per user. Updated whenever a wardrobe item is added or removed,
    plus when a starter wardrobe is assigned. Drives the "X% built from your
    own pieces" UX in the wardrobe tab and the auto-deactivation trigger."""

    __tablename__ = "wardrobe_transition_tracking"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
    )
    real_items_count: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0, server_default="0"
    )
    starter_items_count: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0, server_default="0"
    )
    percentage_real: Mapped[float] = mapped_column(
        Numeric(5, 2), nullable=False, default=0, server_default="0"
    )
    # 1.00 = use 100% starter items in outfits; 0.00 = use 100% real.
    blending_ratio: Mapped[float] = mapped_column(
        Numeric(3, 2), nullable=False, default=1.0, server_default="1.00"
    )
    last_updated: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )


class Outfit(Base, TimestampMixin):
    """A generated outfit suggestion. Items reference wardrobe_items by id but
    are denormalized into JSONB so that historical outfits remain readable even
    if the user later edits or deletes the underlying items.

    `image_url` is intentionally nullable — per `plan.md` decision #2 we don't
    render flat-lay composites server-side; the client lays out the 4-item grid
    from the per-item primary_image_url stored in `items`.
    """

    __tablename__ = "outfits"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    occasion: Mapped[str] = mapped_column(String(50), nullable=False)
    items: Mapped[list[dict]] = mapped_column(JSONB, nullable=False)
    image_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    ai_reasoning_short: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    ai_reasoning_full: Mapped[Optional[str]] = mapped_column(String(4000), nullable=True)
    compatibility_score: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    weather_context: Mapped[Optional[dict]] = mapped_column(JSONB, nullable=True)
    using_starter_wardrobe: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False, server_default="false"
    )
    generation_method: Mapped[str] = mapped_column(String(50), nullable=False)
    is_logged: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False, server_default="false", index=True
    )
    logged_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    worn_count: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0, server_default="0"
    )
    is_favorite: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False, server_default="false", index=True
    )
    favorited_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )


class OutfitHistory(Base):
    """One row per (user, outfit, logged_at). Drives history queries and feeds
    the streak tracker. Deduped on (user_id, outfit_id, logged_at) to make
    repeated taps on Log idempotent within the same instant."""

    __tablename__ = "outfit_history"
    __table_args__ = (
        UniqueConstraint(
            "user_id", "outfit_id", "logged_at", name="uq_outfit_history_user_outfit_at"
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    outfit_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("outfits.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    logged_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, index=True
    )
    shared: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False, server_default="false"
    )


class UsageTracking(Base):
    """One row per (user, week_start_date). Counts outfit generations and
    mix-and-match sessions inside the user's local timezone week. Limits are
    columns (not constants) so a future Pro upgrade can rewrite them in-place
    without touching service code."""

    __tablename__ = "usage_tracking"
    __table_args__ = (
        UniqueConstraint("user_id", "week_start_date", name="uq_usage_user_week"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    # Monday in user's timezone — see usage_service._week_window_local.
    week_start_date: Mapped[datetime] = mapped_column(Date, nullable=False)
    outfits_generated: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0, server_default="0"
    )
    mix_and_match_sessions: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0, server_default="0"
    )
    outfit_limit: Mapped[int] = mapped_column(
        Integer, nullable=False, default=21, server_default="21"
    )
    mix_limit: Mapped[int] = mapped_column(
        Integer, nullable=False, default=3, server_default="3"
    )
    last_reset: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    next_reset: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )


class StreakTracking(Base):
    """One row per user. Updated whenever an outfit is logged. The 6d analytics
    will read from this; 6c writes the row on every successful /outfits/{id}/log
    so the toast metadata can decide between milestone, streak, and default."""

    __tablename__ = "streak_tracking"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
    )
    current_streak: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0, server_default="0"
    )
    longest_streak: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0, server_default="0"
    )
    last_logged_date: Mapped[Optional[datetime]] = mapped_column(Date, nullable=True)
    streak_started_at: Mapped[Optional[datetime]] = mapped_column(Date, nullable=True)
    total_outfits_logged: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0, server_default="0"
    )


class PasswordResetToken(Base):
    __tablename__ = "password_reset_tokens"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    token_hash: Mapped[str] = mapped_column(String(64), unique=True, index=True, nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    used_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )


class AIResponseCache(Base):
    """Content-addressed cache of `analyze_image` responses (§5.1).

    Durable memoization, not a volatile cache: the same garment photo always
    yields the same detection, so we key on a hash of the inputs and serve
    repeats for free. An eviction would mean re-paying Claude, which is why this
    lives in Postgres rather than Redis. Only `analyze_image` is cached.

    `cache_key` = sha256(model + media_type + image_bytes + prompt). The token
    columns are nullable — the provider interface returns only text today, so
    they stay empty until/unless usage is surfaced (§5.4).
    """

    __tablename__ = "ai_response_cache"

    cache_key: Mapped[str] = mapped_column(String(64), primary_key=True)
    model: Mapped[str] = mapped_column(String(100), nullable=False)
    call_type: Mapped[str] = mapped_column(String(32), nullable=False)
    response_text: Mapped[str] = mapped_column(Text, nullable=False)
    input_tokens: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    output_tokens: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
