"""Abstract repository ports for battles, graphs, and battle moves."""

from abc import ABC, abstractmethod
from collections.abc import Sequence
from uuid import UUID

from src.domain.entities import Battle, BattleMove, Graph


class GraphRepository(ABC):
    """Port for graph persistence."""

    @abstractmethod
    async def create(self, graph: Graph) -> Graph:
        ...

    @abstractmethod
    async def get_by_id(self, graph_id: UUID) -> Graph | None:
        ...

    @abstractmethod
    async def list_all(self) -> Sequence[Graph]:
        ...


class BattleRepository(ABC):
    """Port for battle persistence."""

    @abstractmethod
    async def create(self, battle: Battle) -> Battle:
        ...

    @abstractmethod
    async def get_by_id(self, battle_id: UUID) -> Battle | None:
        ...

    @abstractmethod
    async def update(self, battle: Battle) -> Battle:
        ...

    @abstractmethod
    async def list_by_player(self, player_id: UUID) -> Sequence[Battle]:
        ...


class BattleMoveRepository(ABC):
    """Port for battle move persistence."""

    @abstractmethod
    async def create(self, move: BattleMove) -> BattleMove:
        ...

    @abstractmethod
    async def list_by_battle(self, battle_id: UUID) -> Sequence[BattleMove]:
        ...
