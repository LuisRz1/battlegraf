"""ORM models for schools, sections, and users."""

import uuid

from sqlalchemy import Boolean, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .base import Base, UUIDMixin


class SchoolModel(Base, UUIDMixin):
    """A registered school in the platform."""

    __tablename__ = "schools"

    name: Mapped[str] = mapped_column(String(255), nullable=False)
    region: Mapped[str] = mapped_column(String(255), default="", nullable=False)
    level: Mapped[str] = mapped_column(String(20), default="both", nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    sections: Mapped[list["SectionModel"]] = relationship("SectionModel", back_populates="school", lazy="selectin")
    users: Mapped[list["UserModel"]] = relationship("UserModel", back_populates="school", lazy="selectin")


class SectionModel(Base, UUIDMixin):
    """A section/classroom within a school."""

    __tablename__ = "sections"

    school_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("schools.id"), nullable=False)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    grade: Mapped[int] = mapped_column(Integer, nullable=False)
    level: Mapped[str] = mapped_column(String(50), default="primary", nullable=False)
    tutor_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    school: Mapped[SchoolModel] = relationship("SchoolModel", back_populates="sections")
    users: Mapped[list["UserModel"]] = relationship("UserModel", foreign_keys="UserModel.section_id", back_populates="section")


class UserModel(Base, UUIDMixin):
    """A system user (student, teacher, or administrator)."""

    __tablename__ = "users"

    username: Mapped[str] = mapped_column(String(100), unique=True, nullable=False, index=True)
    email: Mapped[str] = mapped_column(String(255), nullable=False)
    hashed_password: Mapped[str] = mapped_column(String(255), nullable=False)
    full_name: Mapped[str] = mapped_column(String(255), nullable=False)
    role: Mapped[str] = mapped_column(String(50), nullable=False, index=True)
    school_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("schools.id"), nullable=True)
    section_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("sections.id"), nullable=True)
    xp: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    rank_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("ranks.id"), nullable=True)
    clan_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("clans.id"), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    school: Mapped[SchoolModel | None] = relationship("SchoolModel", back_populates="users")
    section: Mapped[SectionModel | None] = relationship("SectionModel", foreign_keys=[section_id], back_populates="users")
    clan: Mapped["ClanModel"] = relationship("ClanModel", back_populates="members")
    rank: Mapped["RankModel"] = relationship("RankModel", back_populates="users")
