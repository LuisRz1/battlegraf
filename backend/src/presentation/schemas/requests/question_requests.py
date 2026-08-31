"""Request schemas for question bank endpoints."""

from pydantic import BaseModel, Field


class CreateQuestionBankRequest(BaseModel):
    school_id: str
    subject: str


class UpdateQuestionBankRequest(BaseModel):
    subject: str | None = None


class GenerateQuestionsRequest(BaseModel):
    count: int = Field(default=10, ge=1, le=100)
    file_path: str = ""


class ApproveQuestionRequest(BaseModel):
    question_id: str


class UpdateQuestionRequest(BaseModel):
    text: str | None = None
    option_a: str | None = None
    option_b: str | None = None
    option_c: str | None = None
    option_d: str | None = None
    correct_option: str | None = None
    explanation: str | None = None
    is_approved: bool | None = None
