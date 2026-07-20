"""Use cases for question bank management."""

from uuid import UUID

from fastapi import UploadFile

from src.domain.entities import Question, QuestionBank
from src.domain.enums import Subject
from src.domain.interfaces.repositories import (
    QuestionAgent,
    QuestionBankRepository,
    QuestionRepository,
)
from src.infrastructure.storage import LocalStorageService


class CreateQuestionBank:
    """Create a new question bank for a school and subject."""

    def __init__(self, bank_repo: QuestionBankRepository) -> None:
        self.bank_repo = bank_repo

    async def execute(self, school_id: UUID, subject: Subject) -> QuestionBank:
        existing = await self.bank_repo.get_by_school_and_subject(school_id, subject.value)
        if existing:
            return existing
        bank = QuestionBank(school_id=school_id, subject=subject)
        return await self.bank_repo.create(bank)


class UploadMaterial:
    """Save uploaded material to local storage and return the file path."""

    def __init__(self, storage: LocalStorageService) -> None:
        self.storage = storage

    async def execute(self, file: UploadFile) -> str:
        return await self.storage.save(file)


class GenerateQuestions:
    """Generate questions from material text and store them in a bank."""

    def __init__(
        self,
        bank_repo: QuestionBankRepository,
        question_repo: QuestionRepository,
        agent: QuestionAgent,
    ) -> None:
        self.bank_repo = bank_repo
        self.question_repo = question_repo
        self.agent = agent

    async def execute(
        self,
        bank_id: UUID,
        creator_id: UUID,
        file_path: str,
        count: int = 10,
    ) -> list[Question]:
        bank = await self.bank_repo.get_by_id(bank_id)
        if not bank:
            raise ValueError("Question bank not found")

        material_text = await self.agent.extract_text_from_file(file_path)
        generated = await self.agent.generate_questions(material_text, bank.subject, count)

        questions = []
        for item in generated:
            question = Question(
                subject=bank.subject,
                school_id=bank.school_id,
                bank_id=bank.id,
                creator_id=creator_id,
                text=item["text"],
                option_a=item["option_a"],
                option_b=item["option_b"],
                option_c=item["option_c"],
                option_d=item["option_d"],
                correct_option=item["correct_option"],
                explanation=item.get("explanation", ""),
                is_approved=False,
            )
            questions.append(question)

        created = await self.question_repo.create_many(questions)
        bank.total_generated += len(created)
        await self.bank_repo.update(bank)
        return list(created)


class ListQuestions:
    """List questions within a bank."""

    def __init__(self, question_repo: QuestionRepository) -> None:
        self.question_repo = question_repo

    async def execute(self, bank_id: UUID) -> list[Question]:
        return list(await self.question_repo.list_by_bank(bank_id))


class ApproveQuestion:
    """Approve a generated question."""

    def __init__(
        self,
        question_repo: QuestionRepository,
        bank_repo: QuestionBankRepository,
    ) -> None:
        self.question_repo = question_repo
        self.bank_repo = bank_repo

    async def execute(self, question_id: UUID) -> Question:
        question = await self.question_repo.get_by_id(question_id)
        if not question:
            raise ValueError("Question not found")
        question.is_approved = True
        updated = await self.question_repo.update(question)

        bank = await self.bank_repo.get_by_id(question.bank_id)
        if bank:
            bank.total_approved += 1
            await self.bank_repo.update(bank)
        return updated
