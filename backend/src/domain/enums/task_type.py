from enum import Enum


class TaskType(str, Enum):
    """Tipos de tareas que un profesor puede asignar."""

    MULTIPLE_CHOICE = "multiple_choice"
    OPEN_ANSWER = "open_answer"
    FILE_UPLOAD = "file_upload"
