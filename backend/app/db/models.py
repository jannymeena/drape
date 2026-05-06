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
    UniqueConstraint,
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
    subscription_tier: Mapped[str] = mapped_column(
        String(20), nullable=False, default="free", server_default="free"
    )

    profile: Mapped[Optional["Profile"]] = relationship(
        back_populates="user", uselist=False, cascade="all, delete-orphan"
    )


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

    user: Mapped["User"] = relationship(back_populates="profile")


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

    # Images — populated client-side until Phase 5e wires ImageStorageProvider.
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
