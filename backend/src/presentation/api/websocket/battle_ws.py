"""WebSocket endpoint for real-time battle updates."""

import math
from datetime import UTC, datetime
from uuid import UUID

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from src.domain.services.battle_engine import BattleEngine
from src.infrastructure.auth.jwt_handler import decode_token
from src.infrastructure.database.repositories import (
    SQLAlchemyBattleRepository,
    SQLAlchemyGraphRepository,
)
from src.infrastructure.database.session import AsyncSessionLocal

from .manager import battle_manager

router = APIRouter()


@router.websocket("/ws/battles/{battle_id}")
async def battle_websocket(websocket: WebSocket, battle_id: str) -> None:
    """WebSocket endpoint for battle updates."""
    token = websocket.query_params.get("token", "")
    payload = decode_token(token)
    if payload is None:
        await websocket.close(code=4401, reason="Authentication required")
        return
    try:
        battle_uuid = UUID(battle_id)
        user_id = UUID(payload["sub"])
    except (KeyError, ValueError):
        await websocket.close(code=4400, reason="Invalid battle or user id")
        return

    async with AsyncSessionLocal() as session:
        battle = await SQLAlchemyBattleRepository(session).get_by_id(battle_uuid)
    if battle is None:
        await websocket.close(code=4404, reason="Battle not found")
        return
    if user_id not in (battle.player_1_id, battle.player_2_id):
        await websocket.close(code=4403, reason="Not a battle participant")
        return

    await battle_manager.connect(battle_uuid, websocket)
    await battle_manager.broadcast(
        battle_uuid,
        {
            "type": "player_joined",
            "battle_id": battle_id,
            "message": "Nuevo jugador conectado",
        },
    )
    try:
        while True:
            data = await websocket.receive_json()
            await _handle_message(battle_uuid, websocket, data)
    except WebSocketDisconnect:
        battle_manager.disconnect(battle_uuid, websocket)
        await battle_manager.broadcast(
            battle_uuid,
            {
                "type": "player_left",
                "battle_id": battle_id,
                "message": "Un jugador se desconecto",
            },
        )


async def _handle_message(battle_id: UUID, websocket: WebSocket, data: dict) -> None:
    message_type = data.get("type", "unknown")
    if message_type == "ping":
        await websocket.send_json({"type": "pong"})
        return

    if message_type == "get_state":
        async with AsyncSessionLocal() as session:
            repo = SQLAlchemyBattleRepository(session)
            battle = await repo.get_by_id_for_update(battle_id)
            if battle:
                graph = await SQLAlchemyGraphRepository(session).get_by_id(
                    battle.graph_id
                )
                if graph is not None:
                    engine = BattleEngine(battle, graph, {})
                    initialized = engine.ensure_turn_clock()
                    expired_turns = engine.expire_turn_if_needed()
                    if initialized or expired_turns:
                        await repo.update(battle)
                        await session.commit()
                now = datetime.now(UTC)
                deadline = battle.turn_deadline_at
                remaining = 0
                if deadline is not None:
                    if deadline.tzinfo is None:
                        deadline = deadline.replace(tzinfo=UTC)
                    remaining = max(
                        0,
                        math.ceil((deadline - now).total_seconds()),
                    )
                await websocket.send_json(
                    {
                        "type": "battle_state",
                        "battle_id": str(battle_id),
                        "status": battle.status.value,
                        "current_turn": battle.current_turn,
                        "turn_number": battle.turn_number,
                        "server_time": now.isoformat(),
                        "turn_deadline_at": (
                            deadline.isoformat() if deadline is not None else None
                        ),
                        "time_remaining": remaining,
                        "winner_id": (
                            str(battle.winner_id) if battle.winner_id else None
                        ),
                    }
                )
        return

    await websocket.send_json(
        {
            "type": "error",
            "battle_id": str(battle_id),
            "message": f"Unsupported message type: {message_type}",
        }
    )
