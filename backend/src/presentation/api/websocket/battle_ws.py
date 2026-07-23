"""WebSocket endpoint for real-time battle updates."""

from uuid import UUID

from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from sqlalchemy.ext.asyncio import AsyncSession

from src.infrastructure.database.session import AsyncSessionLocal
from src.infrastructure.database.repositories import SQLAlchemyBattleRepository
from .manager import battle_manager

router = APIRouter()


@router.websocket("/ws/battles/{battle_id}")
async def battle_websocket(websocket: WebSocket, battle_id: str) -> None:
    """WebSocket endpoint for battle updates."""
    battle_uuid = UUID(battle_id)
    await battle_manager.connect(battle_uuid, websocket)
    await battle_manager.broadcast(
        battle_uuid,
        {"type": "player_joined", "battle_id": battle_id, "message": "Nuevo jugador conectado"},
    )
    try:
        while True:
            data = await websocket.receive_json()
            await _handle_message(battle_uuid, websocket, data)
    except WebSocketDisconnect:
        battle_manager.disconnect(battle_uuid, websocket)
        await battle_manager.broadcast(
            battle_uuid,
            {"type": "player_left", "battle_id": battle_id, "message": "Un jugador se desconecto"},
        )


async def _handle_message(battle_id: UUID, websocket: WebSocket, data: dict) -> None:
    message_type = data.get("type", "unknown")
    if message_type == "ping":
        await websocket.send_json({"type": "pong"})
        return

    if message_type == "get_state":
        async with AsyncSessionLocal() as session:
            repo = SQLAlchemyBattleRepository(session)
            battle = await repo.get_by_id(battle_id)
            if battle:
                await websocket.send_json({
                    "type": "battle_state",
                    "battle_id": str(battle_id),
                    "status": battle.status.value,
                    "current_turn": battle.current_turn,
                    "winner_id": str(battle.winner_id) if battle.winner_id else None,
                })
        return

    await battle_manager.broadcast(
        battle_id,
        {"type": "message", "battle_id": str(battle_id), "data": data},
    )
