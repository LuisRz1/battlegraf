from enum import Enum


class BattleStatus(str, Enum):
    """Estado de una batalla."""

    PENDING = "pending"           # Esperando que el oponente acepte
    IN_PROGRESS = "in_progress"   # Batalla en curso
    PAUSED = "paused"             # Pausada por desconexion
    FINISHED = "finished"         # Finalizada con ganador
    DRAW = "draw"                 # Empate
    CANCELLED = "cancelled"       # Cancelada

    @property
    def is_active(self) -> bool:
        return self in (BattleStatus.PENDING, BattleStatus.IN_PROGRESS, BattleStatus.PAUSED)
