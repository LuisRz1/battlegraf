"""Make landing-only NOT NULL columns friendly to backend inserts.

The landing (Supabase) owns `schools.created_by` and the display columns of
`sections` (section_label, code, display_name). The BattleGraph backend inserts
rows without those fields, so give them server defaults / nullable so both
apps can write to the shared tables.

Revision ID: 20260817_0004
Revises: 20260817_0003
Create Date: 2026-08-17
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "20260817_0004"
down_revision: str | None = "20260817_0003"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # schools.created_by: the backend registers schools without a created_by
    op.alter_column("schools", "created_by", nullable=True)

    # sections display columns: backend writes name/grade/level only
    op.alter_column(
        "sections",
        "section_label",
        nullable=False,
        server_default="",
    )
    op.alter_column(
        "sections",
        "code",
        nullable=False,
        server_default="",
    )
    op.alter_column(
        "sections",
        "display_name",
        nullable=False,
        server_default="",
    )
    # grade: backend sends strings ("5"); landing stores text — align default
    op.alter_column(
        "sections",
        "grade",
        nullable=False,
        server_default="",
    )


def downgrade() -> None:
    # Shared tables: do not restore constraints that block backend inserts.
    raise RuntimeError("Reconciliation migration is not reversible")