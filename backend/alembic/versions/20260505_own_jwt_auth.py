"""own-JWT auth: drop firebase_uid, add password/oauth/consent columns, refresh+reset token tables

Revision ID: 7a1c4d9b2e10
Revises: e292f510c528
Create Date: 2026-05-05 00:00:00.000000
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "7a1c4d9b2e10"
down_revision: Union[str, Sequence[str], None] = "e292f510c528"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


AUTH_METHOD_ENUM = sa.Enum("password", "apple", "google", name="auth_method")


def upgrade() -> None:
    # Pre-prod: no real users exist yet, and firebase_uid is going away. Wipe rows to
    # let us add NOT NULL columns cleanly without per-row backfill.
    op.execute("DELETE FROM users")

    op.drop_index("ix_users_firebase_uid", table_name="users")
    op.drop_column("users", "firebase_uid")

    AUTH_METHOD_ENUM.create(op.get_bind(), checkfirst=True)

    op.add_column("users", sa.Column("password_hash", sa.String(length=255), nullable=True))
    op.add_column("users", sa.Column("auth_method", AUTH_METHOD_ENUM, nullable=False))
    op.add_column("users", sa.Column("apple_id", sa.String(length=255), nullable=True))
    op.add_column("users", sa.Column("google_id", sa.String(length=255), nullable=True))
    op.add_column(
        "users",
        sa.Column("agreed_to_terms", sa.Boolean(), nullable=False, server_default=sa.false()),
    )
    op.add_column(
        "users",
        sa.Column("agreed_to_privacy", sa.Boolean(), nullable=False, server_default=sa.false()),
    )
    op.add_column(
        "users",
        sa.Column("terms_agreed_at", sa.DateTime(timezone=True), nullable=True),
    )

    op.create_index("ix_users_apple_id", "users", ["apple_id"], unique=True)
    op.create_index("ix_users_google_id", "users", ["google_id"], unique=True)

    op.create_table(
        "refresh_tokens",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "user_id",
            sa.Integer(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("token_hash", sa.String(length=64), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("revoked_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
    )
    op.create_index("ix_refresh_tokens_token_hash", "refresh_tokens", ["token_hash"], unique=True)
    op.create_index("ix_refresh_tokens_user_id", "refresh_tokens", ["user_id"])

    op.create_table(
        "password_reset_tokens",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "user_id",
            sa.Integer(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("token_hash", sa.String(length=64), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("used_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
    )
    op.create_index(
        "ix_password_reset_tokens_token_hash",
        "password_reset_tokens",
        ["token_hash"],
        unique=True,
    )
    op.create_index(
        "ix_password_reset_tokens_user_id", "password_reset_tokens", ["user_id"]
    )


def downgrade() -> None:
    op.drop_index("ix_password_reset_tokens_user_id", table_name="password_reset_tokens")
    op.drop_index("ix_password_reset_tokens_token_hash", table_name="password_reset_tokens")
    op.drop_table("password_reset_tokens")

    op.drop_index("ix_refresh_tokens_user_id", table_name="refresh_tokens")
    op.drop_index("ix_refresh_tokens_token_hash", table_name="refresh_tokens")
    op.drop_table("refresh_tokens")

    op.drop_index("ix_users_google_id", table_name="users")
    op.drop_index("ix_users_apple_id", table_name="users")

    op.drop_column("users", "terms_agreed_at")
    op.drop_column("users", "agreed_to_privacy")
    op.drop_column("users", "agreed_to_terms")
    op.drop_column("users", "google_id")
    op.drop_column("users", "apple_id")
    op.drop_column("users", "auth_method")
    op.drop_column("users", "password_hash")

    AUTH_METHOD_ENUM.drop(op.get_bind(), checkfirst=True)

    op.add_column(
        "users",
        sa.Column("firebase_uid", sa.String(length=128), nullable=True),
    )
    op.create_index("ix_users_firebase_uid", "users", ["firebase_uid"], unique=True)
