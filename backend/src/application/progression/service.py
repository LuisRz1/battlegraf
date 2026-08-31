"""Idempotent XP awarding and automatic rank progression."""

from uuid import UUID

from src.domain.entities import User, XPTransaction
from src.infrastructure.database.repositories import (
    SQLAlchemyRankRepository,
    SQLAlchemyUserRepository,
    SQLAlchemyXPTransactionRepository,
)


class ProgressionService:
    def __init__(
        self,
        user_repo: SQLAlchemyUserRepository,
        rank_repo: SQLAlchemyRankRepository,
        xp_repo: SQLAlchemyXPTransactionRepository,
    ) -> None:
        self.user_repo = user_repo
        self.rank_repo = rank_repo
        self.xp_repo = xp_repo

    async def award_xp(
        self,
        user_id: UUID,
        amount: int,
        source_type: str,
        source_id: UUID,
        description: str,
    ) -> tuple[User, XPTransaction | None]:
        if amount < 0:
            raise ValueError("XP award cannot be negative")
        user = await self.user_repo.get_by_id(user_id)
        if user is None or not user.is_active:
            raise ValueError("User not found or inactive")

        existing = await self.xp_repo.get_by_source(
            user_id,
            source_type,
            source_id,
        )
        if existing is not None:
            return user, existing
        if amount == 0:
            return user, None

        user.add_xp(amount)
        if user.school_id is not None:
            rank = await self.rank_repo.get_for_xp(user.school_id, user.xp)
            user.rank_id = rank.id if rank else None
        user = await self.user_repo.update(user)

        transaction = await self.xp_repo.create(
            XPTransaction(
                user_id=user.id,
                amount=amount,
                source_type=source_type,
                source_id=source_id,
                description=description,
            )
        )
        return user, transaction
