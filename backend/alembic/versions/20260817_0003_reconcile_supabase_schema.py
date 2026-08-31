"""Reconcile the backend schema with Supabase tables created by the landing.

The landing (Supabase) already created `schools` and `sections` with its own
column set. This migration ADDS the columns the BattleGraph backend expects,
without dropping or renaming landing columns, so both apps share the DB.

Revision ID: 20260817_0003
Revises: 20260728_0002
Create Date: 2026-08-17
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "20260817_0003"
down_revision: str | None = "20260728_0002"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def _columns(table: str) -> set[str]:
    return {
        col["name"]
        for col in sa.inspect(op.get_bind()).get_columns(table)
    }


def upgrade() -> None:
    # ---- schools: backend expects level + is_active ----
    cols = _columns("schools")
    if "level" not in cols:
        op.add_column(
            "schools",
            sa.Column("level", sa.String(length=20), nullable=False, server_default="both"),
        )
    if "is_active" not in cols:
        op.add_column(
            "schools",
            sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        )

    # ---- sections: backend expects name, tutor_id, is_active ----
    cols = _columns("sections")
    if "name" not in cols:
        # The landing stores display_name/section_label; add a friendly `name`
        op.add_column(
            "sections",
            sa.Column("name", sa.String(length=255), nullable=True),
        )
    if "tutor_id" not in cols:
        op.add_column(
            "sections",
            sa.Column("tutor_id", sa.Uuid(), nullable=True),
        )
    if "is_active" not in cols:
        op.add_column(
            "sections",
            sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        )
    # grade: the landing created it as TEXT; the backend writes integer-ish
    # values ("5"), which fits a VARCHAR without a schema crisis.
    # Nothing to do here: model mapping is adjusted to String(20).


def downgrade() -> None:
    # Columns are additive and shared with the landing; do not drop them here.
    raise RuntimeError("Reconciliation migration is not reversible")