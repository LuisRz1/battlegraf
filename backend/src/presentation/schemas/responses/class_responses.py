"""Response schemas for classes."""

from datetime import datetime
from pydantic import BaseModel

class ClassResponse(BaseModel):
    id: str
    name: str
    subject: str | None
    code: str
    professor_name: str
    school_name: str
    is_active: bool
    student_count: int

class EnrollmentResponse(BaseModel):
    id: str
    class_name: str
    student_name: str
    enrolled_at: datetime
