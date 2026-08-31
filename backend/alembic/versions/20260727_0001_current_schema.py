"""Create the current BattleGraph schema and upgrade legacy local databases.

Revision ID: 20260727_0001
Revises:
Create Date: 2026-07-27
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op
from src.infrastructure.database.models import Base

revision: str = "20260727_0001"
down_revision: str | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def _column_names(table_name: str) -> set[str]:
    return {
        column["name"] for column in sa.inspect(op.get_bind()).get_columns(table_name)
    }


def upgrade() -> None:
    bind = op.get_bind()
    existing_tables = set(sa.inspect(bind).get_table_names())

    # New installations receive the complete schema from the same metadata used
    # by the application and test suite.
    Base.metadata.create_all(bind=bind)

    # The repository previously started through create_all without Alembic. These
    # additions preserve an ignored local SQLite database created by that version.
    if "tasks" in existing_tables:
        columns = _column_names("tasks")
        if "status" not in columns:
            op.add_column(
                "tasks",
                sa.Column(
                    "status",
                    sa.String(length=20),
                    nullable=False,
                    server_default="draft",
                ),
            )
        if "options" not in columns:
            op.add_column(
                "tasks",
                sa.Column(
                    "options",
                    sa.JSON(),
                    nullable=False,
                    server_default=sa.text("'[]'"),
                ),
            )
        if "correct_option" not in columns:
            op.add_column(
                "tasks",
                sa.Column("correct_option", sa.String(length=1), nullable=True),
            )

    if "task_submissions" in existing_tables:
        columns = _column_names("task_submissions")
        if "feedback" not in columns:
            op.add_column(
                "task_submissions",
                sa.Column(
                    "feedback",
                    sa.Text(),
                    nullable=False,
                    server_default="",
                ),
            )
        if "xp_awarded" not in columns:
            op.add_column(
                "task_submissions",
                sa.Column(
                    "xp_awarded",
                    sa.Integer(),
                    nullable=False,
                    server_default="0",
                ),
            )
        if "graded_at" not in columns:
            op.add_column(
                "task_submissions",
                sa.Column("graded_at", sa.DateTime(timezone=True), nullable=True),
            )


def downgrade() -> None:
    # This is an initial baseline. Dropping it would destroy all project data,
    # so a downgrade must be performed through a deliberate backup/restore.
    raise RuntimeError("The BattleGraph baseline migration is not reversible")
