"""Request schemas for tasks and progression."""

from datetime import datetime

from pydantic import BaseModel, Field, model_validator

from src.domain.enums import Subject, TaskType


class CreateTaskRequest(BaseModel):
    section_id: str
    subject: Subject
    title: str = Field(min_length=3, max_length=255)
    description: str = Field(default="", max_length=5000)
    task_type: TaskType
    due_date: datetime | None = None
    xp_reward: int = Field(default=20, ge=0, le=100)
    options: dict[str, str] = Field(default_factory=dict)
    correct_option: str | None = None
    publish: bool = False

    @model_validator(mode="after")
    def validate_multiple_choice(self) -> "CreateTaskRequest":
        if self.task_type == TaskType.MULTIPLE_CHOICE:
            normalized = {
                key.strip().upper(): value.strip()
                for key, value in self.options.items()
            }
            if set(normalized) != {"A", "B", "C", "D"}:
                raise ValueError("Multiple-choice tasks require options A, B, C, and D")
            if any(not value for value in normalized.values()):
                raise ValueError("Task options cannot be empty")
            answer = (self.correct_option or "").strip().upper()
            if answer not in normalized:
                raise ValueError("correct_option must be A, B, C, or D")
            self.options = normalized
            self.correct_option = answer
        elif self.options or self.correct_option:
            raise ValueError("Only multiple-choice tasks can define options")
        return self


class UpdateTaskRequest(BaseModel):
    title: str | None = Field(default=None, min_length=3, max_length=255)
    description: str | None = Field(default=None, max_length=5000)
    due_date: datetime | None = None
    xp_reward: int | None = Field(default=None, ge=0, le=100)


class SubmitTaskRequest(BaseModel):
    answer: str = Field(default="", max_length=10000)


class GradeSubmissionRequest(BaseModel):
    score: int = Field(ge=0, le=100)
    feedback: str = Field(default="", max_length=5000)


class CreateRankRequest(BaseModel):
    name: str = Field(min_length=2, max_length=100)
    level: int = Field(ge=1, le=100)
    xp_required: int = Field(ge=0)
    icon_url: str | None = Field(default=None, max_length=500)


class CreateClanRequest(BaseModel):
    section_id: str
    name: str = Field(min_length=2, max_length=100)
