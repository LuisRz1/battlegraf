"""SQLAlchemy implementations for question and question bank repositories."""

import uuid
from collections.abc import Sequence
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from src.domain.entities import Question, QuestionBank
from src.domain.enums import Subject
from src.domain.interfaces.repositories import QuestionBankRepository, QuestionRepository
from src.infrastructure.database.models import QuestionBankModel, QuestionModel


class SQLAlchemyQuestionBankRepository(QuestionBankRepository):
    """Repository for QuestionBank entities."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    def _to_entity(self, model: QuestionBankModel) -> QuestionBank:
        return QuestionBank(
            id=model.id,
            school_id=model.school_id,
            subject=Subject(model.subject),
            total_generated=model.total_generated,
            total_approved=model.total_approved,
            created_at=model.created_at,
        )

    async def create(self, bank: QuestionBank) -> QuestionBank:
        model = QuestionBankModel(
            id=bank.id,
            school_id=bank.school_id,
            subject=bank.subject.value,
            total_generated=bank.total_generated,
            total_approved=bank.total_approved,
        )
        self._session.add(model)
        await self._session.flush()
        return self._to_entity(model)

    async def get_by_id(self, bank_id: uuid.UUID) -> QuestionBank | None:
        result = await self._session.execute(
            select(QuestionBankModel).where(QuestionBankModel.id == bank_id)
        )
        model = result.scalar_one_or_none()
        return self._to_entity(model) if model else None

    async def get_by_school_and_subject(self, school_id: uuid.UUID, subject: str) -> QuestionBank | None:
        result = await self._session.execute(
            select(QuestionBankModel)
            .where(QuestionBankModel.school_id == school_id)
            .where(QuestionBankModel.subject == subject)
        )
        model = result.scalar_one_or_none()
        return self._to_entity(model) if model else None

    async def list_by_school(self, school_id: uuid.UUID) -> Sequence[QuestionBank]:
        result = await self._session.execute(
            select(QuestionBankModel).where(QuestionBankModel.school_id == school_id)
        )
        return [self._to_entity(m) for m in result.scalars().all()]

    async def update(self, bank: QuestionBank) -> QuestionBank:
        result = await self._session.execute(
            select(QuestionBankModel).where(QuestionBankModel.id == bank.id)
        )
        model = result.scalar_one_or_none()
        if not model:
            raise ValueError("Question bank not found")
        model.total_generated = bank.total_generated
        model.total_approved = bank.total_approved
        await self._session.flush()
        return self._to_entity(model)


class SQLAlchemyQuestionRepository(QuestionRepository):
    """Repository for Question entities."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    def _to_entity(self, model: QuestionModel) -> Question:
        return Question(
            id=model.id,
            subject=Subject(model.subject),
            school_id=model.school_id,
            bank_id=model.bank_id,
            creator_id=model.creator_id,
            text=model.text,
            option_a=model.option_a,
            option_b=model.option_b,
            option_c=model.option_c,
            option_d=model.option_d,
            correct_option=model.correct_option,
            explanation=model.explanation,
            is_approved=model.is_approved,
            usage_count=model.usage_count,
            created_at=model.created_at,
        )

    async def create(self, question: Question) -> Question:
        model = QuestionModel(
            id=question.id,
            subject=question.subject.value,
            school_id=question.school_id,
            bank_id=question.bank_id,
            creator_id=question.creator_id,
            text=question.text,
            option_a=question.option_a,
            option_b=question.option_b,
            option_c=question.option_c,
            option_d=question.option_d,
            correct_option=question.correct_option,
            explanation=question.explanation,
            is_approved=question.is_approved,
            usage_count=question.usage_count,
        )
        self._session.add(model)
        await self._session.flush()
        return self._to_entity(model)

    async def create_many(self, questions: Sequence[Question]) -> Sequence[Question]:
        models = [
            QuestionModel(
                id=q.id,
                subject=q.subject.value,
                school_id=q.school_id,
                bank_id=q.bank_id,
                creator_id=q.creator_id,
                text=q.text,
                option_a=q.option_a,
                option_b=q.option_b,
                option_c=q.option_c,
                option_d=q.option_d,
                correct_option=q.correct_option,
                explanation=q.explanation,
                is_approved=q.is_approved,
                usage_count=q.usage_count,
            )
            for q in questions
        ]
        self._session.add_all(models)
        await self._session.flush()
        return [self._to_entity(m) for m in models]

    async def get_by_id(self, question_id: uuid.UUID) -> Question | None:
        result = await self._session.execute(
            select(QuestionModel).where(QuestionModel.id == question_id)
        )
        model = result.scalar_one_or_none()
        return self._to_entity(model) if model else None

    async def list_by_bank(self, bank_id: uuid.UUID) -> Sequence[Question]:
        result = await self._session.execute(
            select(QuestionModel).where(QuestionModel.bank_id == bank_id)
        )
        return [self._to_entity(m) for m in result.scalars().all()]

    async def list_by_school(self, school_id: uuid.UUID) -> Sequence[Question]:
        result = await self._session.execute(
            select(QuestionModel).where(QuestionModel.school_id == school_id)
        )
        return [self._to_entity(m) for m in result.scalars().all()]

    async def list_by_ids(self, question_ids: list[uuid.UUID]) -> Sequence[Question]:
        if not question_ids:
            return []
        result = await self._session.execute(
            select(QuestionModel).where(QuestionModel.id.in_(question_ids))
        )
        return [self._to_entity(m) for m in result.scalars().all()]

    async def update(self, question: Question) -> Question:
        result = await self._session.execute(
            select(QuestionModel).where(QuestionModel.id == question.id)
        )
        model = result.scalar_one_or_none()
        if not model:
            raise ValueError("Question not found")
        model.is_approved = question.is_approved
        model.usage_count = question.usage_count
        await self._session.flush()
        return self._to_entity(model)
