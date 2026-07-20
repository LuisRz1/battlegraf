"""ORM models for questions, question banks, and tasks."""

import uuid
from datetime import datetime, timezone

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .base import Base, UUIDMixin


class QuestionBankModel(Base, UUIDMixin):
    """A bank of questions for a subject in a school."""

    __tablename__ = "question_banks"

    school_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("schools.id"), nullable=False)
    subject: Mapped[str] = mapped_column(String(50), nullable=False)
    total_generated: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    total_approved: Mapped[int] = mapped_column(Integer, default=0, nullable=False)

    questions: Mapped[list["QuestionModel"]] = relationship("QuestionModel", back_populates="bank", lazy="selectin")


class QuestionModel(Base, UUIDMixin):
    """A multiple-choice question in the bank."""

    __tablename__ = "questions"

    subject: Mapped[str] = mapped_column(String(50), nullable=False)
    school_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("schools.id"), nullable=False)
    bank_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("question_banks.id"), nullable=False)
    creator_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), nullable=False)
    text: Mapped[str] = mapped_column(Text, nullable=False)
    option_a: Mapped[str] = mapped_column(Text, nullable=False)
    option_b: Mapped[str] = mapped_column(Text, nullable=False)
    option_c: Mapped[str] = mapped_column(Text, nullable=False)
    option_d: Mapped[str] = mapped_column(Text, nullable=False)
    correct_option: Mapped[str] = mapped_column(String(1), nullable=False)
    explanation: Mapped[str] = mapped_column(Text, default="", nullable=False)
    is_approved: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    usage_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)

    bank: Mapped[QuestionBankModel] = relationship("QuestionBankModel", back_populates="questions")


class TaskModel(Base, UUIDMixin):
    """A teacher assignment for a section."""

    __tablename__ = "tasks"

    creator_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), nullable=False)
    section_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("sections.id"), nullable=False)
    subject: Mapped[str] = mapped_column(String(50), nullable=False)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str] = mapped_column(Text, default="", nullable=False)
    task_type: Mapped[str] = mapped_column(String(50), nullable=False)
    due_date: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    xp_reward: Mapped[int] = mapped_column(Integer, default=10, nullable=False)


class TaskSubmissionModel(Base, UUIDMixin):
    """A student's submission for a task."""

    __tablename__ = "task_submissions"

    task_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("tasks.id"), nullable=False)
    student_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), nullable=False)
    answer: Mapped[str] = mapped_column(Text, default="", nullable=False)
    file_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    is_graded: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    score: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    submitted_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
