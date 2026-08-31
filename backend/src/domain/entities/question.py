"""Entidades de dominio para preguntas y tareas."""

from dataclasses import dataclass, field
from datetime import datetime
from uuid import UUID, uuid4

from ..enums import Subject, TaskType


@dataclass
class Question:
    """Pregunta de alternativa multiple en el banco."""

    id: UUID = field(default_factory=uuid4)
    subject: Subject = Subject.MATH
    school_id: UUID = field(default_factory=uuid4)
    bank_id: UUID = field(default_factory=uuid4)
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
    due_date: datetime | None = None
    xp_reward: int = 10
    status: str = "draft"
    options: dict[str, str] = field(default_factory=dict)
    correct_option: str | None = None
    created_at: datetime = field(default_factory=datetime.utcnow)


@dataclass
class TaskSubmission:
    """A student's current submission for a task."""

    id: UUID = field(default_factory=uuid4)
    task_id: UUID = field(default_factory=uuid4)
    student_id: UUID = field(default_factory=uuid4)
    answer: str = ""
    file_url: str | None = None
    is_graded: bool = False
    score: int = 0
    feedback: str = ""
    xp_awarded: int = 0
    submitted_at: datetime = field(default_factory=datetime.utcnow)
    graded_at: datetime | None = None


@dataclass
class Rank:
    """Rango en el sistema de progresion."""

    id: UUID = field(default_factory=uuid4)
    school_id: UUID = field(default_factory=uuid4)
    name: str = ""
    level: int = 1
    xp_required: int = 0
    icon_url: str | None = None


@dataclass
class Clan:
    """Clan dentro de una seccion."""

    id: UUID = field(default_factory=uuid4)
    section_id: UUID = field(default_factory=uuid4)
    name: str = ""
    total_score: int = 0
    created_at: datetime = field(default_factory=datetime.utcnow)


@dataclass
class XPTransaction:
    """An idempotent, traceable XP movement."""

    id: UUID = field(default_factory=uuid4)
    user_id: UUID = field(default_factory=uuid4)
    amount: int = 0
    source_type: str = ""
    source_id: UUID = field(default_factory=uuid4)
    description: str = ""
    created_at: datetime = field(default_factory=datetime.utcnow)
