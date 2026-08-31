"""Persistence for tasks, ranks, clans, and the XP ledger."""

import uuid
from collections.abc import Sequence

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from src.domain.entities import (
    Clan,
    Rank,
    Task,
    TaskSubmission,
    XPTransaction,
)
from src.domain.enums import Subject, TaskType
from src.infrastructure.database.models import (
    ClanModel,
    RankModel,
    TaskModel,
    TaskSubmissionModel,
    XPTransactionModel,
)


class SQLAlchemyTaskRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    @staticmethod
    def _to_entity(model: TaskModel) -> Task:
        return Task(
            id=model.id,
            creator_id=model.creator_id,
            section_id=model.section_id,
            subject=Subject(model.subject),
            title=model.title,
            description=model.description,
            task_type=TaskType(model.task_type),
            due_date=model.due_date,
            xp_reward=model.xp_reward,
            status=model.status,
            options=dict(model.options or {}),
            correct_option=model.correct_option,
            created_at=model.created_at,
        )

    async def create(self, task: Task) -> Task:
        model = TaskModel(
            id=task.id,
            creator_id=task.creator_id,
            section_id=task.section_id,
            subject=task.subject.value,
            title=task.title,
            description=task.description,
            task_type=task.task_type.value,
            due_date=task.due_date,
            xp_reward=task.xp_reward,
            status=task.status,
            options=task.options,
            correct_option=task.correct_option,
        )
        self._session.add(model)
        await self._session.flush()
        return self._to_entity(model)

    async def get_by_id(self, task_id: uuid.UUID) -> Task | None:
        model = await self._session.get(TaskModel, task_id)
        return self._to_entity(model) if model else None

    async def list_by_section(
        self,
        section_id: uuid.UUID,
        *,
        published_only: bool = False,
    ) -> Sequence[Task]:
        query = select(TaskModel).where(TaskModel.section_id == section_id)
        if published_only:
            query = query.where(TaskModel.status == "published")
        query = query.order_by(TaskModel.due_date.asc(), TaskModel.created_at.desc())
        result = await self._session.execute(query)
        return [self._to_entity(model) for model in result.scalars().all()]

    async def list_by_creator(self, creator_id: uuid.UUID) -> Sequence[Task]:
        result = await self._session.execute(
            select(TaskModel)
            .where(TaskModel.creator_id == creator_id)
            .order_by(TaskModel.created_at.desc())
        )
        return [self._to_entity(model) for model in result.scalars().all()]

    async def update(self, task: Task) -> Task:
        model = await self._session.get(TaskModel, task.id)
        if model is None:
            raise ValueError("Task not found")
        model.title = task.title
        model.description = task.description
        model.subject = task.subject.value
        model.task_type = task.task_type.value
        model.due_date = task.due_date
        model.xp_reward = task.xp_reward
        model.status = task.status
        model.options = task.options
        model.correct_option = task.correct_option
        await self._session.flush()
        return self._to_entity(model)


class SQLAlchemyTaskSubmissionRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    @staticmethod
    def _to_entity(model: TaskSubmissionModel) -> TaskSubmission:
        return TaskSubmission(
            id=model.id,
            task_id=model.task_id,
            student_id=model.student_id,
            answer=model.answer,
            file_url=model.file_url,
            is_graded=model.is_graded,
            score=model.score,
            feedback=model.feedback,
            xp_awarded=model.xp_awarded,
            submitted_at=model.submitted_at,
            graded_at=model.graded_at,
        )

    async def create(self, submission: TaskSubmission) -> TaskSubmission:
        model = TaskSubmissionModel(
            id=submission.id,
            task_id=submission.task_id,
            student_id=submission.student_id,
            answer=submission.answer,
            file_url=submission.file_url,
            is_graded=submission.is_graded,
            score=submission.score,
            feedback=submission.feedback,
            xp_awarded=submission.xp_awarded,
            submitted_at=submission.submitted_at,
            graded_at=submission.graded_at,
        )
        self._session.add(model)
        await self._session.flush()
        return self._to_entity(model)

    async def get_by_id(
        self,
        submission_id: uuid.UUID,
    ) -> TaskSubmission | None:
        model = await self._session.get(TaskSubmissionModel, submission_id)
        return self._to_entity(model) if model else None

    async def get_by_task_and_student(
        self,
        task_id: uuid.UUID,
        student_id: uuid.UUID,
    ) -> TaskSubmission | None:
        result = await self._session.execute(
            select(TaskSubmissionModel)
            .where(TaskSubmissionModel.task_id == task_id)
            .where(TaskSubmissionModel.student_id == student_id)
        )
        model = result.scalar_one_or_none()
        return self._to_entity(model) if model else None

    async def list_by_task(
        self,
        task_id: uuid.UUID,
    ) -> Sequence[TaskSubmission]:
        result = await self._session.execute(
            select(TaskSubmissionModel)
            .where(TaskSubmissionModel.task_id == task_id)
            .order_by(TaskSubmissionModel.submitted_at.desc())
        )
        return [self._to_entity(model) for model in result.scalars().all()]

    async def update(self, submission: TaskSubmission) -> TaskSubmission:
        model = await self._session.get(TaskSubmissionModel, submission.id)
        if model is None:
            raise ValueError("Task submission not found")
        model.answer = submission.answer
        model.file_url = submission.file_url
        model.is_graded = submission.is_graded
        model.score = submission.score
        model.feedback = submission.feedback
        model.xp_awarded = submission.xp_awarded
        model.submitted_at = submission.submitted_at
        model.graded_at = submission.graded_at
        await self._session.flush()
        return self._to_entity(model)


class SQLAlchemyRankRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    @staticmethod
    def _to_entity(model: RankModel) -> Rank:
        return Rank(
            id=model.id,
            school_id=model.school_id,
            name=model.name,
            level=model.level,
            xp_required=model.xp_required,
            icon_url=model.icon_url,
        )

    async def create(self, rank: Rank) -> Rank:
        model = RankModel(
            id=rank.id,
            school_id=rank.school_id,
            name=rank.name,
            level=rank.level,
            xp_required=rank.xp_required,
            icon_url=rank.icon_url,
        )
        self._session.add(model)
        await self._session.flush()
        return self._to_entity(model)

    async def list_by_school(self, school_id: uuid.UUID) -> Sequence[Rank]:
        result = await self._session.execute(
            select(RankModel)
            .where(RankModel.school_id == school_id)
            .order_by(RankModel.xp_required.asc())
        )
        return [self._to_entity(model) for model in result.scalars().all()]

    async def get_for_xp(self, school_id: uuid.UUID, xp: int) -> Rank | None:
        result = await self._session.execute(
            select(RankModel)
            .where(RankModel.school_id == school_id)
            .where(RankModel.xp_required <= xp)
            .order_by(RankModel.xp_required.desc())
            .limit(1)
        )
        model = result.scalar_one_or_none()
        return self._to_entity(model) if model else None


class SQLAlchemyClanRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    @staticmethod
    def _to_entity(model: ClanModel) -> Clan:
        return Clan(
            id=model.id,
            section_id=model.section_id,
            name=model.name,
            total_score=model.total_score,
            created_at=model.created_at,
        )

    async def create(self, clan: Clan) -> Clan:
        model = ClanModel(
            id=clan.id,
            section_id=clan.section_id,
            name=clan.name,
            total_score=clan.total_score,
        )
        self._session.add(model)
        await self._session.flush()
        return self._to_entity(model)

    async def get_by_id(self, clan_id: uuid.UUID) -> Clan | None:
        model = await self._session.get(ClanModel, clan_id)
        return self._to_entity(model) if model else None

    async def list_by_section(self, section_id: uuid.UUID) -> Sequence[Clan]:
        result = await self._session.execute(
            select(ClanModel)
            .where(ClanModel.section_id == section_id)
            .order_by(ClanModel.name.asc())
        )
        return [self._to_entity(model) for model in result.scalars().all()]


class SQLAlchemyXPTransactionRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    @staticmethod
    def _to_entity(model: XPTransactionModel) -> XPTransaction:
        return XPTransaction(
            id=model.id,
            user_id=model.user_id,
            amount=model.amount,
            source_type=model.source_type,
            source_id=model.source_id,
            description=model.description,
            created_at=model.created_at,
        )

    async def get_by_source(
        self,
        user_id: uuid.UUID,
        source_type: str,
        source_id: uuid.UUID,
    ) -> XPTransaction | None:
        result = await self._session.execute(
            select(XPTransactionModel)
            .where(XPTransactionModel.user_id == user_id)
            .where(XPTransactionModel.source_type == source_type)
            .where(XPTransactionModel.source_id == source_id)
        )
        model = result.scalar_one_or_none()
        return self._to_entity(model) if model else None

    async def create(self, transaction: XPTransaction) -> XPTransaction:
        model = XPTransactionModel(
            id=transaction.id,
            user_id=transaction.user_id,
            amount=transaction.amount,
            source_type=transaction.source_type,
            source_id=transaction.source_id,
            description=transaction.description,
        )
        self._session.add(model)
        await self._session.flush()
        return self._to_entity(model)

    async def list_by_user(
        self,
        user_id: uuid.UUID,
    ) -> Sequence[XPTransaction]:
        result = await self._session.execute(
            select(XPTransactionModel)
            .where(XPTransactionModel.user_id == user_id)
            .order_by(XPTransactionModel.created_at.desc())
        )
        return [self._to_entity(model) for model in result.scalars().all()]
