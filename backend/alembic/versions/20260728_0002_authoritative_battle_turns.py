"""Persist authoritative battle turn clocks and active questions.

Revision ID: 20260728_0002
Revises: 20260727_0001
Create Date: 2026-07-28
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "20260728_0002"
down_revision: str | None = "20260727_0001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def _column_names(table_name: str) -> set[str]:
    return {
        column["name"] for column in sa.inspect(op.get_bind()).get_columns(table_name)
    }


def upgrade() -> None:
    columns = _column_names("battles")
    additions = {
        "turn_number": sa.Column(
            "turn_number",
            sa.Integer(),
            nullable=False,
            server_default="1",
        ),
        "turn_started_at": sa.Column(
            "turn_started_at", sa.DateTime(timezone=True), nullable=True
        ),
        "turn_deadline_at": sa.Column(
            "turn_deadline_at", sa.DateTime(timezone=True), nullable=True
        ),
        "player_positions": sa.Column(
            "player_positions",
            sa.JSON(),
            nullable=False,
            server_default=sa.text("'{}'"),
        ),
        "active_node_id": sa.Column(
            "active_node_id", sa.Uuid(), nullable=True
        ),
        "active_question_id": sa.Column(
            "active_question_id", sa.Uuid(), nullable=True
        ),
        "question_started_at": sa.Column(
            "question_started_at", sa.DateTime(timezone=True), nullable=True
        ),
    }
    for name, column in additions.items():
        if name not in columns:
            op.add_column("battles", column)


def downgrade() -> None:
    columns = _column_names("battles")
    for name in (
        "question_started_at",
        "active_question_id",
        "active_node_id",
        "player_positions",
        "turn_deadline_at",
        "turn_started_at",
        "turn_number",
    ):
        if name in columns:
            op.drop_column("battles", name)
