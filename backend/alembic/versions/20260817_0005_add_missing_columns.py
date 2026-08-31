"""Add remaining backend columns missing from landing-created tables.

sections has no updated_at; clans lacks total_score and updated_at.

Revision ID: 20260817_0005
Revises: 20260817_0004
Create Date: 2026-08-17
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "20260817_0005"
down_revision: str | None = "20260817_0004"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def _columns(table: str) -> set[str]:
    return {c["name"] for c in sa.inspect(op.get_bind()).get_columns(table)}


def upgrade() -> None:
    if "updated_at" not in _columns("sections"):
        op.add_column(
            "sections",
            sa.Column(
                "updated_at",
                sa.DateTime(timezone=True),
                nullable=False,
                server_default=sa.text("now()"),
            ),
        )
    if "total_score" not in _columns("clans"):
        op.add_column(
            "clans",
            sa.Column("total_score", sa.Integer(), nullable=False, server_default="0"),
        )
    if "updated_at" not in _columns("clans"):
        op.add_column(
            "clans",
            sa.Column(
                "updated_at",
                sa.DateTime(timezone=True),
                nullable=False,
                server_default=sa.text("now()"),
            ),
        )


def downgrade() -> None:
    raise RuntimeError("Reconciliation is not reversible")