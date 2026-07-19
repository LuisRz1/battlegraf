"""Entidades del dominio — reglas de negocio puras, sin dependencias externas."""

from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional
from uuid import UUID, uuid4

from ..enums import Role, Subject


@dataclass
class User:
    """Usuario del sistema (alumno, profesor, directivo)."""

    id: UUID = field(default_factory=uuid4)
    username: str = ""
    email: str = ""
    hashed_password: str = ""
    full_name: str = ""
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
        return self.role in (Role.DIRECTOR, Role.SUBDIRECTOR, Role.TUTOR, Role.PROFESSOR)

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
    grade: int = 1
    level: str = "primary"
    tutor_id: Optional[UUID] = None
    is_active: bool = True
    created_at: datetime = field(default_factory=datetime.utcnow)
