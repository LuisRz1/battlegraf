"""Request schemas for question bank endpoints."""

from pydantic import BaseModel, Field

from src.domain.enums import Subject


class CreateQuestionBankRequest(BaseModel):
    school_id: str
    subject: Subject


class GenerateQuestionsRequest(BaseModel):
    count: int = Field(default=10, ge=1, le=100)


class ApproveQuestionRequest(BaseModel):
    question_id: str
