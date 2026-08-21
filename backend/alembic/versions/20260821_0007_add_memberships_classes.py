"""add memberships classes

Revision ID: 20260821_0007
Revises: 20260818_0006
Create Date: 2026-08-21 10:10:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = '20260821_0007'
down_revision: Union[str, None] = '20260818_0006'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Add columns to users
    op.add_column('users', sa.Column('last_name', sa.String(length=255), server_default='', nullable=False))
    op.add_column('users', sa.Column('phone', sa.String(length=20), server_default='', nullable=False))

    # Create school_codes
    op.create_table('school_codes',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('school_id', sa.UUID(), nullable=False),
        sa.Column('code', sa.String(length=8), nullable=False),
        sa.Column('is_active', sa.Boolean(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(['school_id'], ['schools.id'], ),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_school_codes_code'), 'school_codes', ['code'], unique=True)

    # Create school_memberships
    op.create_table('school_memberships',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('user_id', sa.UUID(), nullable=False),
        sa.Column('school_id', sa.UUID(), nullable=False),
        sa.Column('role', sa.String(length=50), nullable=False),
        sa.Column('xp', sa.Integer(), nullable=False),
        sa.Column('rank_id', sa.UUID(), nullable=True),
        sa.Column('clan_id', sa.UUID(), nullable=True),
        sa.Column('is_active', sa.Boolean(), nullable=False),
        sa.Column('can_view_students', sa.Boolean(), nullable=False),
        sa.Column('joined_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('left_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(['clan_id'], ['clans.id'], ),
        sa.ForeignKeyConstraint(['rank_id'], ['ranks.id'], ),
        sa.ForeignKeyConstraint(['school_id'], ['schools.id'], ),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('user_id', 'school_id')
    )

    # Create classes
    op.create_table('classes',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('professor_id', sa.UUID(), nullable=False),
        sa.Column('school_id', sa.UUID(), nullable=False),
        sa.Column('name', sa.String(length=255), nullable=False),
        sa.Column('subject', sa.String(length=50), nullable=True),
        sa.Column('code', sa.String(length=8), nullable=False),
        sa.Column('is_active', sa.Boolean(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(['professor_id'], ['users.id'], ),
        sa.ForeignKeyConstraint(['school_id'], ['schools.id'], ),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_classes_code'), 'classes', ['code'], unique=True)

    # Create class_enrollments
    op.create_table('class_enrollments',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('class_id', sa.UUID(), nullable=False),
        sa.Column('student_id', sa.UUID(), nullable=False),
        sa.Column('enrolled_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('is_active', sa.Boolean(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(['class_id'], ['classes.id'], ),
        sa.ForeignKeyConstraint(['student_id'], ['users.id'], ),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('class_id', 'student_id')
    )

    # Create membership_snapshots
    op.create_table('membership_snapshots',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('membership_id', sa.UUID(), nullable=False),
        sa.Column('user_id', sa.UUID(), nullable=False),
        sa.Column('school_name', sa.String(length=255), nullable=False),
        sa.Column('role', sa.String(length=50), nullable=False),
        sa.Column('final_xp', sa.Integer(), nullable=False),
        sa.Column('final_rank_name', sa.String(length=255), nullable=True),
        sa.Column('battles_played', sa.Integer(), nullable=False),
        sa.Column('battles_won', sa.Integer(), nullable=False),
        sa.Column('classes_taught', sa.JSON(), nullable=True),
        sa.Column('materials_count', sa.Integer(), nullable=False),
        sa.Column('snapshot_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(['membership_id'], ['school_memberships.id'], ),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ),
        sa.PrimaryKeyConstraint('id')
    )


def downgrade() -> None:
    op.drop_table('membership_snapshots')
    op.drop_table('class_enrollments')
    op.drop_index(op.f('ix_classes_code'), table_name='classes')
    op.drop_table('classes')
    op.drop_table('school_memberships')
    op.drop_index(op.f('ix_school_codes_code'), table_name='school_codes')
    op.drop_table('school_codes')
    op.drop_column('users', 'phone')
    op.drop_column('users', 'last_name')
