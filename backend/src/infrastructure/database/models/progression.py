"""ORM models for ranks and clans."""

import uuid

from sqlalchemy import ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .base import Base, UUIDMixin


class RankModel(Base, UUIDMixin):
    """A rank in the progression system."""

    __tablename__ = "ranks"

    school_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("schools.id"), nullable=False)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    level: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    xp_required: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    icon_url: Mapped[str | None] = mapped_column(String(500), nullable=True)

    users: Mapped[list["UserModel"]] = relationship("UserModel", back_populates="rank")


class ClanModel(Base, UUIDMixin):
    """A clan within a section."""

    __tablename__ = "clans"

    section_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("sections.id"), nullable=False)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    total_score: Mapped[int] = mapped_column(Integer, default=0, nullable=False)

    members: Mapped[list["UserModel"]] = relationship("UserModel", back_populates="clan")
