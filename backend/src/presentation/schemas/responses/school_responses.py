"""Response schemas for schools, sections and academic years."""

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
    grade: str
    level: str
    academic_year_id: Optional[str] = None
    section_label: Optional[str] = None
    code: Optional[str] = None
    display_name: Optional[str] = None
    tutor_name: Optional[str] = None
    max_students: int = 30
    status: str = "active"
    tutor_id: Optional[str] = None
    is_active: bool = True
    created_at: datetime


class AcademicYearResponse(BaseModel):
    id: str
    school_id: str
    label: str
    starts_on: Optional[datetime] = None
    ends_on: Optional[datetime] = None
    is_active: bool = True
    created_at: datetime
    updated_at: datetime
