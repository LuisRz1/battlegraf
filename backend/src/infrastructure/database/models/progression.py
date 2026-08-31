"""ORM models for ranks and clans."""

import uuid
from typing import TYPE_CHECKING

from sqlalchemy import ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .base import Base, UUIDMixin

if TYPE_CHECKING:
    from .school import UserModel


class RankModel(Base, UUIDMixin):
    """A rank in the progression system."""

    __tablename__ = "ranks"
    __table_args__ = (
        UniqueConstraint("school_id", "level", name="uq_rank_school_level"),
        UniqueConstraint("school_id", "name", name="uq_rank_school_name"),
    )

    school_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("schools.id"), nullable=False
    )
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    level: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    xp_required: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    icon_url: Mapped[str | None] = mapped_column(String(500), nullable=True)

    users: Mapped[list["UserModel"]] = relationship("UserModel", back_populates="rank")


class ClanModel(Base, UUIDMixin):
    """A clan within a section."""

    __tablename__ = "clans"
    __table_args__ = (
        UniqueConstraint("section_id", "name", name="uq_clan_section_name"),
    )

    section_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("sections.id"), nullable=False
    )
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    total_score: Mapped[int] = mapped_column(Integer, default=0, nullable=False)

    members: Mapped[list["UserModel"]] = relationship(
        "UserModel", back_populates="clan"
    )


class XPTransactionModel(Base, UUIDMixin):
    """An immutable XP ledger entry."""

    __tablename__ = "xp_transactions"
    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "source_type",
            "source_id",
            name="uq_xp_user_source",
        ),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id"),
        nullable=False,
        index=True,
    )
    amount: Mapped[int] = mapped_column(Integer, nullable=False)
    source_type: Mapped[str] = mapped_column(String(50), nullable=False)
    source_id: Mapped[uuid.UUID] = mapped_column(nullable=False)
    description: Mapped[str] = mapped_column(String(500), default="", nullable=False)
