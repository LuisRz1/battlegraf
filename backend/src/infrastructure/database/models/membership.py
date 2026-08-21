"""ORM models for memberships, classes, and codes."""

import uuid
from datetime import datetime
from typing import TYPE_CHECKING, Any

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, JSON, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .base import Base, UUIDMixin

if TYPE_CHECKING:
    from .school import SchoolModel, UserModel
    from .progression import ClanModel, RankModel

class SchoolCodeModel(Base, UUIDMixin):
    """Codes used by schools for registration."""
    __tablename__ = "school_codes"

    school_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("schools.id"), nullable=False)
    code: Mapped[str] = mapped_column(String(8), unique=True, index=True, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    school: Mapped["SchoolModel"] = relationship("SchoolModel")

class SchoolMembershipModel(Base, UUIDMixin):
    """User membership in a school."""
    __tablename__ = "school_memberships"

    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), nullable=False)
    school_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("schools.id"), nullable=False)
    role: Mapped[str] = mapped_column(String(50), nullable=False)
    xp: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    rank_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("ranks.id"), nullable=True)
    clan_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("clans.id"), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    can_view_students: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    joined_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, nullable=False)
    left_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    __table_args__ = (UniqueConstraint("user_id", "school_id"),)

    user: Mapped["UserModel"] = relationship("UserModel")
    school: Mapped["SchoolModel"] = relationship("SchoolModel")
    rank: Mapped["RankModel | None"] = relationship("RankModel")
    clan: Mapped["ClanModel | None"] = relationship("ClanModel")

class ClassModel(Base, UUIDMixin):
    """Class managed by a professor."""
    __tablename__ = "classes"

    professor_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), nullable=False)
    school_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("schools.id"), nullable=False)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    subject: Mapped[str | None] = mapped_column(String(50), nullable=True)
    code: Mapped[str] = mapped_column(String(8), unique=True, index=True, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    professor: Mapped["UserModel"] = relationship("UserModel")
    school: Mapped["SchoolModel"] = relationship("SchoolModel")

class ClassEnrollmentModel(Base, UUIDMixin):
    """Student enrollment in a class."""
    __tablename__ = "class_enrollments"

    class_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("classes.id"), nullable=False)
    student_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), nullable=False)
    enrolled_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    __table_args__ = (UniqueConstraint("class_id", "student_id"),)

    class_: Mapped["ClassModel"] = relationship("ClassModel", backref="enrollments")
    student: Mapped["UserModel"] = relationship("UserModel", backref="class_enrollments")

class MembershipSnapshotModel(Base, UUIDMixin):
    """Snapshot of a user's school membership when they leave."""
    __tablename__ = "membership_snapshots"

    membership_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("school_memberships.id"), nullable=False)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), nullable=False)
    school_name: Mapped[str] = mapped_column(String(255), nullable=False)
    role: Mapped[str] = mapped_column(String(50), nullable=False)
    final_xp: Mapped[int] = mapped_column(Integer, nullable=False)
    final_rank_name: Mapped[str | None] = mapped_column(String(255), nullable=True)
    battles_played: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    battles_won: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    classes_taught: Mapped[Any | None] = mapped_column(JSON, nullable=True)
    materials_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    snapshot_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, nullable=False)

    membership: Mapped["SchoolMembershipModel"] = relationship("SchoolMembershipModel")
    user: Mapped["UserModel"] = relationship("UserModel")
