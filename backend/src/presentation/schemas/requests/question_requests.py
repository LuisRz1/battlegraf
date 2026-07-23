"""Request schemas for question bank endpoints."""

from pydantic import BaseModel, Field


class CreateQuestionBankRequest(BaseModel):
    school_id: str
    subject: str


class GenerateQuestionsRequest(BaseModel):
    count: int = Field(default=10, ge=1, le=100)
    file_path: str = ""


class ApproveQuestionRequest(BaseModel):
    question_id: str
