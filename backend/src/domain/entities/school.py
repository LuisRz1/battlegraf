"""Entidades del dominio — reglas de negocio puras, sin dependencias externas."""

from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional
from uuid import UUID, uuid4

from ..enums import Role


@dataclass
class User:
    """Usuario del sistema (alumno, profesor, directivo)."""

    id: UUID = field(default_factory=uuid4)
    username: str = ""
    email: str = ""
    hashed_password: str = ""
    full_name: str = ""
    last_name: str = ""
    phone: str = ""
    role: Role = Role.STUDENT
    school_id: Optional[UUID] = None
    section_id: Optional[UUID] = None
    xp: int = 0
    rank_id: Optional[UUID] = None
    clan_id: Optional[UUID] = None
    is_active: bool = True
    created_at: datetime = field(default_factory=datetime.utcnow)

    @property
    def is_teacher(self) -> bool:
        return self.role in (
            Role.DIRECTOR,
            Role.SUBDIRECTOR,
            Role.TUTOR,
            Role.PROFESSOR,
        )

    @property
    def is_student(self) -> bool:
        return self.role == Role.STUDENT

    def add_xp(self, amount: int) -> None:
        if amount <= 0:
            raise ValueError("XP amount must be positive")
        self.xp += amount


@dataclass
class School:
    """Entidad raiz: un colegio registrado en la plataforma."""

    id: UUID = field(default_factory=uuid4)
    name: str = ""
    region: str = ""
    level: str = "both"  # "primary", "secondary", "both"
    is_active: bool = True
    created_at: datetime = field(default_factory=datetime.utcnow)


@dataclass
class Section:
    """Seccion o aula dentro de un colegio (ej: '5to Primaria - Seccion A')."""

    id: UUID = field(default_factory=uuid4)
    school_id: UUID = field(default_factory=uuid4)
    name: str = ""
    grade: str = "1"
    level: str = "primary"
    academic_year_id: Optional[UUID] = None
    section_label: str = ""
    code: str = ""
    display_name: str = ""
    tutor_name: Optional[str] = None
    max_students: int = 30
    status: str = "active"
    tutor_id: Optional[UUID] = None
    is_active: bool = True
    created_at: datetime = field(default_factory=datetime.utcnow)

@dataclass
class SchoolCode:
    id: UUID = field(default_factory=uuid4)
    school_id: UUID = field(default_factory=uuid4)
    code: str = ""
    is_active: bool = True

@dataclass
class SchoolMembership:
    id: UUID = field(default_factory=uuid4)
    user_id: UUID = field(default_factory=uuid4)
    school_id: UUID = field(default_factory=uuid4)
    role: str = ""
    xp: int = 0
    rank_id: Optional[UUID] = None
    clan_id: Optional[UUID] = None
    is_active: bool = True
    can_view_students: bool = True
    joined_at: datetime = field(default_factory=datetime.utcnow)
    left_at: Optional[datetime] = None

@dataclass
class ClassName:
    id: UUID = field(default_factory=uuid4)
    professor_id: UUID = field(default_factory=uuid4)
    school_id: UUID = field(default_factory=uuid4)
    name: str = ""
    subject: Optional[str] = None
    code: str = ""
    is_active: bool = True

@dataclass
class ClassEnrollment:
    id: UUID = field(default_factory=uuid4)
    class_id: UUID = field(default_factory=uuid4)
    student_id: UUID = field(default_factory=uuid4)
    enrolled_at: datetime = field(default_factory=datetime.utcnow)
    is_active: bool = True


