"""Abstract repository ports for questions and question banks."""

from abc import ABC, abstractmethod
from collections.abc import Sequence
from uuid import UUID

from src.domain.entities import Question, QuestionBank


class QuestionBankRepository(ABC):
    """Port for question bank persistence."""

    @abstractmethod
    async def create(self, bank: QuestionBank) -> QuestionBank:
        ...

    @abstractmethod
    async def get_by_id(self, bank_id: UUID) -> QuestionBank | None:
        ...

    @abstractmethod
    async def get_by_school_and_subject(self, school_id: UUID, subject: str) -> QuestionBank | None:
        ...

    @abstractmethod
    async def list_by_school(self, school_id: UUID) -> Sequence[QuestionBank]:
        ...

    @abstractmethod
    async def update(self, bank: QuestionBank) -> QuestionBank:
        ...


class QuestionRepository(ABC):
    """Port for question persistence."""

    @abstractmethod
    async def create(self, question: Question) -> Question:
        ...

    @abstractmethod
    async def create_many(self, questions: Sequence[Question]) -> Sequence[Question]:
        ...

    @abstractmethod
    async def get_by_id(self, question_id: UUID) -> Question | None:
        ...

    @abstractmethod
    async def list_by_bank(self, bank_id: UUID) -> Sequence[Question]:
        ...

    @abstractmethod
    async def list_by_school(self, school_id: UUID) -> Sequence[Question]:
        ...

    @abstractmethod
    async def update(self, question: Question) -> Question:
        ...
