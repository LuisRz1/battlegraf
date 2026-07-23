"""Response schemas for schools and sections."""

from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class SchoolResponse(BaseModel):
    id: str
    name: str
    region: str
    level: str
    is_active: bool
    created_at: datetime


class SectionResponse(BaseModel):
    id: str
    school_id: str
    name: str
    grade: int
    level: str
    tutor_id: Optional[str]
    is_active: bool
    created_at: datetime
