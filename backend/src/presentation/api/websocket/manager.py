"""WebSocket connection manager for real-time battle updates."""

from typing import Any
from uuid import UUID

from fastapi import WebSocket


class BattleConnectionManager:
    """Manages WebSocket connections grouped by battle id."""

    def __init__(self) -> None:
        self._connections: dict[UUID, list[WebSocket]] = {}

    async def connect(self, battle_id: UUID, websocket: WebSocket) -> None:
        await websocket.accept()
        self._connections.setdefault(battle_id, []).append(websocket)

    def disconnect(self, battle_id: UUID, websocket: WebSocket) -> None:
        connections = self._connections.get(battle_id, [])
        if websocket in connections:
            connections.remove(websocket)
        if not connections:
            self._connections.pop(battle_id, None)

    async def broadcast(self, battle_id: UUID, message: dict[str, Any]) -> None:
        stale: list[WebSocket] = []
        for ws in list(self._connections.get(battle_id, [])):
            try:
                await ws.send_json(message)
            except RuntimeError:
                stale.append(ws)
        for ws in stale:
            self.disconnect(battle_id, ws)


battle_manager = BattleConnectionManager()
