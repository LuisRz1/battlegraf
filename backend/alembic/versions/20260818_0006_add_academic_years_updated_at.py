"""Add missing updated_at to academic_years (backend ORM requires it).

Revision ID: 20260818_0006
Revises: 20260817_0005
Create Date: 2026-08-18

Same pattern as 20260817_0005 for sections/clans: the backend ORM
(UUIDMixin) assumes updated_at on every model; the landing-created
table lacked it. Filter-alter on existing rows to respect NOT NULL.
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "20260818_0006"
down_revision: str | None = "20260817_0005"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def _columns(table: str) -> set[str]:
    return {c["name"] for c in sa.inspect(op.get_bind()).get_columns(table)}


def upgrade() -> None:
    if "updated_at" not in _columns("academic_years"):
        op.add_column(
            "academic_years",
            sa.Column(
                "updated_at",
                sa.DateTime(timezone=True),
                nullable=False,
                server_default=sa.text("now()"),
            ),
        )


def downgrade() -> None:
    raise RuntimeError("Reconciliation is not reversible")