"""ORM models for schools, sections, and users."""

import uuid
from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .base import Base, UUIDMixin

if TYPE_CHECKING:
    from .progression import ClanModel, RankModel


class SchoolModel(Base, UUIDMixin):
    """A registered school in the platform."""

    __tablename__ = "schools"

    name: Mapped[str] = mapped_column(String(255), nullable=False)
    region: Mapped[str] = mapped_column(String(255), default="", nullable=False)
    level: Mapped[str] = mapped_column(String(20), default="both", nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    sections: Mapped[list["SectionModel"]] = relationship(
        "SectionModel", back_populates="school", lazy="selectin"
    )
    users: Mapped[list["UserModel"]] = relationship(
        "UserModel", back_populates="school", lazy="selectin"
    )


class AcademicYearModel(Base, UUIDMixin):
    """Período lectivo / año académico de un colegio."""

    __tablename__ = "academic_years"

    school_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("schools.id"), nullable=False
    )
    label: Mapped[str] = mapped_column(String(20), nullable=False)
    starts_on: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    ends_on: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    school: Mapped[SchoolModel] = relationship("SchoolModel")
    sections: Mapped[list["SectionModel"]] = relationship(
        "SectionModel", back_populates="academic_year"
    )


class SectionModel(Base, UUIDMixin):
    """A section/classroom within a school."""

    __tablename__ = "sections"

    school_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("schools.id"), nullable=False
    )
    academic_year_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("academic_years.id"), nullable=True
    )
    name: Mapped[str] = mapped_column(String(255), nullable=True)
    grade: Mapped[str] = mapped_column(String(20), nullable=False, server_default="")
    level: Mapped[str] = mapped_column(String(50), default="primary", nullable=False)
    section_label: Mapped[str] = mapped_column(
        String(20), nullable=False, server_default=""
    )
    code: Mapped[str] = mapped_column(
        String(50), nullable=False, server_default="", index=True
    )
    display_name: Mapped[str] = mapped_column(
        String(255), nullable=False, server_default=""
    )
    tutor_name: Mapped[str | None] = mapped_column(String(255), nullable=True)
    max_students: Mapped[int] = mapped_column(Integer, default=30, nullable=False)
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, server_default="active"
    )
    tutor_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id"), nullable=True
    )
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    school: Mapped[SchoolModel] = relationship("SchoolModel", back_populates="sections")
    academic_year: Mapped[AcademicYearModel | None] = relationship(
        "AcademicYearModel", back_populates="sections"
    )
    users: Mapped[list["UserModel"]] = relationship(
        "UserModel", foreign_keys="UserModel.section_id", back_populates="section"
    )


class UserModel(Base, UUIDMixin):
    """A system user (student, teacher, or administrator)."""

    __tablename__ = "users"

    username: Mapped[str] = mapped_column(
        String(100), unique=True, nullable=False, index=True
    )
    email: Mapped[str] = mapped_column(String(255), nullable=False)
    hashed_password: Mapped[str] = mapped_column(String(255), nullable=False)
    full_name: Mapped[str] = mapped_column(String(255), nullable=False)
    last_name: Mapped[str] = mapped_column(String(255), nullable=False, server_default="")
    phone: Mapped[str] = mapped_column(String(20), nullable=False, server_default="")
    role: Mapped[str] = mapped_column(String(50), nullable=False, index=True)
    school_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("schools.id"), nullable=True
    )
    section_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("sections.id"), nullable=True
    )
    xp: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    rank_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("ranks.id"), nullable=True
    )
    clan_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("clans.id"), nullable=True
    )
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    school: Mapped[SchoolModel | None] = relationship(
        "SchoolModel", back_populates="users"
    )
    section: Mapped[SectionModel | None] = relationship(
        "SectionModel", foreign_keys=[section_id], back_populates="users"
    )
    clan: Mapped["ClanModel | None"] = relationship(
        "ClanModel",
        back_populates="members",
    )
    rank: Mapped["RankModel | None"] = relationship(
        "RankModel",
        back_populates="users",
    )