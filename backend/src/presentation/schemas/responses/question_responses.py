"""Response schemas for question bank endpoints."""

from datetime import datetime

from pydantic import BaseModel


class QuestionBankResponse(BaseModel):
    id: str
    school_id: str
    subject: str
    total_generated: int
    total_approved: int
    created_at: datetime


class QuestionResponse(BaseModel):
    id: str
    bank_id: str
    school_id: str
    creator_id: str
    subject: str
    text: str
    option_a: str
    option_b: str
    option_c: str
    option_d: str
    correct_option: str
    explanation: str
    is_approved: bool
    usage_count: int
    created_at: datetime
