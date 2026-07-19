"""Entidades de dominio para preguntas y tareas."""

from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional
from uuid import UUID, uuid4

from ..enums import Subject, TaskType


@dataclass
class Question:
    """Pregunta de alternativa multiple en el banco."""

    id: UUID = field(default_factory=uuid4)
    subject: Subject = Subject.MATH
    school_id: UUID = field(default_factory=uuid4)
    creator_id: UUID = field(default_factory=uuid4)
    text: str = ""
    option_a: str = ""
    option_b: str = ""
    option_c: str = ""
    option_d: str = ""
    correct_option: str = ""  # "A", "B", "C", or "D"
    explanation: str = ""
    is_approved: bool = False
    usage_count: int = 0
    created_at: datetime = field(default_factory=datetime.utcnow)

    def check_answer(self, answer: str) -> bool:
        return answer.upper() == self.correct_option.upper()

    @property
    def options(self) -> dict[str, str]:
        return {
            "A": self.option_a,
            "B": self.option_b,
            "C": self.option_c,
            "D": self.option_d,
        }


@dataclass
class QuestionBank:
    """Banco de preguntas de una materia en un colegio."""

    id: UUID = field(default_factory=uuid4)
    school_id: UUID = field(default_factory=uuid4)
    subject: Subject = Subject.MATH
    total_generated: int = 0
    total_approved: int = 0
    created_at: datetime = field(default_factory=datetime.utcnow)


@dataclass
class Task:
    """Tarea asignada por un profesor a una seccion."""

    id: UUID = field(default_factory=uuid4)
    creator_id: UUID = field(default_factory=uuid4)
    section_id: UUID = field(default_factory=uuid4)
    subject: Subject = Subject.MATH
    title: str = ""
    description: str = ""
    task_type: TaskType = TaskType.MULTIPLE_CHOICE
    due_date: Optional[datetime] = None
    xp_reward: int = 10
    created_at: datetime = field(default_factory=datetime.utcnow)


@dataclass
class Rank:
    """Rango en el sistema de progresion."""

    id: UUID = field(default_factory=uuid4)
    school_id: UUID = field(default_factory=uuid4)
    name: str = ""
    level: int = 1
    xp_required: int = 0
    icon_url: Optional[str] = None


@dataclass
class Clan:
    """Clan dentro de una seccion."""

    id: UUID = field(default_factory=uuid4)
    section_id: UUID = field(default_factory=uuid4)
    name: str = ""
    total_score: int = 0
    created_at: datetime = field(default_factory=datetime.utcnow)
