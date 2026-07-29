"""Battle endpoints for creation, startup, node selection, and answer submission."""

import math
from datetime import UTC, datetime
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from src.application.battle.use_cases import (
    CreateBattle,
    GetBattle,
    StartBattle,
    SubmitAnswer,
)
from src.application.progression import ProgressionService
from src.domain.enums import Role
from src.infrastructure.auth.dependencies import get_current_user, require_role
from src.infrastructure.database.repositories import (
    SQLAlchemyBattleMoveRepository,
    SQLAlchemyBattleRepository,
    SQLAlchemyGraphRepository,
    SQLAlchemyQuestionRepository,
    SQLAlchemyRankRepository,
    SQLAlchemyUserRepository,
    SQLAlchemyXPTransactionRepository,
)
from src.infrastructure.database.session import get_db
from src.presentation.api.websocket.manager import battle_manager
from src.presentation.schemas.requests.battle_requests import (
    CreateBattleRequest,
    SelectNodeRequest,
    StartBattleRequest,
    SubmitAnswerRequest,
)
from src.presentation.schemas.responses.battle_responses import (
    AnswerResultResponse,
    BattleNodeStateResponse,
    BattleQuestionResponse,
    BattleResponse,
)
from src.presentation.schemas.responses.graph_responses import (
    GraphNodeResponse,
    GraphResponse,
)

router = APIRouter(prefix="/battles", tags=["Battles"])


def _as_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=UTC)
    return value.astimezone(UTC)


async def _reconcile_turn_clock(
    battle,
    graph,
    battle_repo: SQLAlchemyBattleRepository,
    session: AsyncSession,
):
    from src.domain.services.battle_engine import BattleEngine

    engine = BattleEngine(battle, graph, {})
    initialized = engine.ensure_turn_clock()
    expired_turns = engine.expire_turn_if_needed()
    if initialized or expired_turns:
        await battle_repo.update(battle)
        await session.commit()
    return battle, expired_turns


def _node_state_response(state, node_lookup: dict) -> BattleNodeStateResponse:
    node = node_lookup.get(state.node_id)
    return BattleNodeStateResponse(
        node_id=str(state.node_id),
        layer=node.layer if node else 0,
        subject=node.subject.value if node else "",
        color=node.color if node else "",
        connected_to=(
            [str(connected_id) for connected_id in node.connected_to] if node else []
        ),
        question_ids=(
            [str(question_id) for question_id in node.question_ids] if node else []
        ),
        owner=state.owner,
        attempt_count=state.attempt_count,
        best_time_ms=state.best_time_ms,
    )


def _battle_response(battle, graph=None) -> BattleResponse:
    server_time = datetime.now(UTC)
    deadline = battle.turn_deadline_at
    time_remaining = 0
    if deadline is not None and battle.status.value == "in_progress":
        time_remaining = max(
            0,
            math.ceil((_as_utc(deadline) - server_time).total_seconds()),
        )
    node_lookup = {}
    if graph:
        node_lookup = {n.id: n for n in graph.nodes}

    return BattleResponse(
        id=str(battle.id),
        player_1_id=str(battle.player_1_id),
        player_2_id=str(battle.player_2_id),
        graph_id=str(battle.graph_id),
        status=battle.status.value,
        current_turn=battle.current_turn,
        turn_number=battle.turn_number,
        current_player_id=str(
            battle.player_1_id if battle.current_turn == 0 else battle.player_2_id
        ),
        winner_id=str(battle.winner_id) if battle.winner_id else None,
        turn_timeout_seconds=battle.turn_timeout_seconds,
        time_remaining=time_remaining,
        server_time=server_time,
        turn_started_at=battle.turn_started_at,
        turn_deadline_at=battle.turn_deadline_at,
        player_positions={
            player_index: str(node_id)
            for player_index, node_id in battle.player_positions.items()
        },
        active_node_id=(
            str(battle.active_node_id) if battle.active_node_id is not None else None
        ),
        graph=(
            GraphResponse(
                id=str(graph.id),
                num_layers=graph.num_layers,
                min_nodes_per_layer=graph.min_nodes_per_layer,
                max_nodes_per_layer=graph.max_nodes_per_layer,
                subjects=[subject.value for subject in graph.subjects],
                nodes=[
                    GraphNodeResponse(
                        id=str(node.id),
                        layer=node.layer,
                        position=node.position,
                        subject=node.subject.value,
                        color=node.color,
                        question_ids=[
                            str(question_id) for question_id in node.question_ids
                        ],
                        connected_to=[str(node_id) for node_id in node.connected_to],
                    )
                    for node in graph.nodes
                ],
                created_at=graph.created_at,
            )
            if graph
            else None
        ),
        node_states=[
            _node_state_response(state, node_lookup)
            for state in battle.node_states.values()
        ],
        moves=[],
        created_at=battle.created_at,
        finished_at=battle.finished_at,
    )


def _answer_result_response(result, battle) -> AnswerResultResponse:
    winner_id = str(battle.winner_id) if battle.winner_id else None
    return AnswerResultResponse(
        is_correct=result.is_correct,
        node_conquered=result.node_conquered,
        node_stolen=result.node_stolen,
        battle_finished=result.battle_finished,
        winner_id=winner_id,
        current_turn=result.current_turn,
        turn_number=result.turn_number,
        response_time_ms=result.response_time_ms,
        turn_deadline_at=battle.turn_deadline_at,
        message=result.message,
    )


@router.get("/me", response_model=list[BattleResponse])
async def list_my_battles(
    session: AsyncSession = Depends(get_db),
    payload: dict = Depends(get_current_user),
):
    """List battles for the current authenticated player."""
    battle_repo = SQLAlchemyBattleRepository(session)
    graph_repo = SQLAlchemyGraphRepository(session)
    battles = await battle_repo.list_by_player(UUID(payload["sub"]))
    result = []
    for battle in battles:
        graph = await graph_repo.get_by_id(battle.graph_id)
        if graph is not None:
            battle, expired_turns = await _reconcile_turn_clock(
                battle, graph, battle_repo, session
            )
            if expired_turns:
                await battle_manager.broadcast(
                    battle.id,
                    {
                        "type": "battle_update",
                        "payload": _battle_response(battle, graph).model_dump(mode="json"),
                    },
                )
        result.append(_battle_response(battle, graph))
    return result


@router.post("", response_model=BattleResponse, status_code=status.HTTP_201_CREATED)
async def create_battle(
    body: CreateBattleRequest,
    session: AsyncSession = Depends(get_db),
    payload: dict = Depends(
        require_role(
            Role.STUDENT,
            Role.PROFESSOR,
            Role.TUTOR,
            Role.SUBDIRECTOR,
            Role.DIRECTOR,
        )
    ),
):
    actor_id = UUID(payload["sub"])
    player_ids = {UUID(body.player_1_id), UUID(body.player_2_id)}
    if payload["role"] == Role.STUDENT.value and actor_id not in player_ids:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Students can only create battles in which they participate",
        )
    if body.min_nodes_per_layer > body.max_nodes_per_layer:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="min_nodes_per_layer cannot exceed max_nodes_per_layer",
        )

    battle_repo = SQLAlchemyBattleRepository(session)
    graph_repo = SQLAlchemyGraphRepository(session)
    question_repo = SQLAlchemyQuestionRepository(session)
    user_repo = SQLAlchemyUserRepository(session)
    use_case = CreateBattle(battle_repo, graph_repo, question_repo, user_repo)
    try:
        battle = await use_case.execute(
            UUID(body.player_1_id),
            UUID(body.player_2_id),
            UUID(body.graph_id) if body.graph_id else None,
            subjects=body.subjects,
            school_id=(
                UUID(payload.get("school_id")) if payload.get("school_id") else None
            ),
            num_layers=body.num_layers,
            min_nodes_per_layer=body.min_nodes_per_layer,
            max_nodes_per_layer=body.max_nodes_per_layer,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)
        ) from exc
    await session.commit()
    graph = await graph_repo.get_by_id(battle.graph_id)
    response = _battle_response(battle, graph)
    await battle_manager.broadcast(
        battle.id,
        {"type": "battle_update", "payload": response.model_dump(mode="json")},
    )
    return response


@router.post("/{battle_id}/start", response_model=BattleResponse)
async def start_battle(
    battle_id: str,
    _body: StartBattleRequest,
    session: AsyncSession = Depends(get_db),
    payload: dict = Depends(get_current_user),
):
    battle_repo = SQLAlchemyBattleRepository(session)
    graph_repo = SQLAlchemyGraphRepository(session)
    question_repo = SQLAlchemyQuestionRepository(session)
    use_case = StartBattle(battle_repo, graph_repo, question_repo)
    try:
        battle = await use_case.execute(
            UUID(battle_id),
            UUID(payload["sub"]),
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)
        ) from exc
    await session.commit()
    graph = await graph_repo.get_by_id(battle.graph_id)
    response = _battle_response(battle, graph)
    await battle_manager.broadcast(
        battle.id,
        {"type": "battle_update", "payload": response.model_dump(mode="json")},
    )
    return response


@router.post("/{battle_id}/select-node", response_model=BattleQuestionResponse)
async def select_node(
    battle_id: str,
    body: SelectNodeRequest,
    session: AsyncSession = Depends(get_db),
    payload: dict = Depends(get_current_user),
):
    battle_repo = SQLAlchemyBattleRepository(session)
    graph_repo = SQLAlchemyGraphRepository(session)
    question_repo = SQLAlchemyQuestionRepository(session)
    try:
        battle = await battle_repo.get_by_id_for_update(UUID(battle_id))
        if battle is None:
            raise ValueError("Battle not found")
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(exc),
        ) from exc
    graph = await graph_repo.get_by_id(battle.graph_id)
    if not graph:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Graph not found"
        )

    from src.domain.services.battle_engine import BattleEngine

    player_id = UUID(payload["sub"])
    if player_id == battle.player_1_id:
        player_index = 0
    elif player_id == battle.player_2_id:
        player_index = 1
    else:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Player is not part of this battle",
        )

    battle.moves = list(
        await SQLAlchemyBattleMoveRepository(session).list_by_battle(battle.id)
    )
    questions = {
        question.id: question
        for question in await question_repo.list_by_ids(
            [question_id for node in graph.nodes for question_id in node.question_ids]
        )
    }
    engine = BattleEngine(battle, graph, questions)
    initialized = engine.ensure_turn_clock()
    expired_turns = engine.expire_turn_if_needed()
    if initialized or expired_turns:
        battle = await battle_repo.update(battle)
        await session.commit()
        if expired_turns:
            await battle_manager.broadcast(
                battle.id,
                {
                    "type": "battle_update",
                    "payload": _battle_response(battle, graph).model_dump(mode="json"),
                },
            )
    try:
        node = engine.select_node(player_index, UUID(body.node_id))
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)
        ) from exc

    used_question_ids = {
        move.question_id for move in battle.moves if move.node_id == node.id
    }
    if battle.active_question_id is not None:
        if battle.active_node_id != node.id:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="A question is already active for this turn",
            )
        question = questions.get(battle.active_question_id)
    else:
        question = next(
            (
                questions[question_id]
                for question_id in node.question_ids
                if question_id not in used_question_ids and question_id in questions
            ),
            None,
        )
    if question is None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="No unused questions remain for this node",
        )
    try:
        engine.start_question(player_index, node.id, question.id)
    except ValueError as exc:
        if str(exc).startswith("Turn expired"):
            await battle_repo.update(battle)
            await session.commit()
            await battle_manager.broadcast(
                battle.id,
                {
                    "type": "battle_update",
                    "payload": _battle_response(battle, graph).model_dump(mode="json"),
                },
            )
        raise HTTPException(
            status_code=(
                status.HTTP_409_CONFLICT
                if str(exc).startswith("Turn expired")
                else status.HTTP_400_BAD_REQUEST
            ),
            detail=str(exc),
        ) from exc
    battle = await battle_repo.update(battle)
    await session.commit()
    if battle.turn_deadline_at is None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Battle turn has no active deadline",
        )
    server_time = datetime.now(UTC)
    return BattleQuestionResponse(
        node_id=str(node.id),
        question_id=str(question.id),
        text=question.text,
        options=question.options,
        server_time=server_time,
        turn_deadline_at=battle.turn_deadline_at,
    )


@router.post("/{battle_id}/answer", response_model=AnswerResultResponse)
async def submit_answer(
    battle_id: str,
    body: SubmitAnswerRequest,
    session: AsyncSession = Depends(get_db),
    payload: dict = Depends(get_current_user),
):
    battle_repo = SQLAlchemyBattleRepository(session)
    graph_repo = SQLAlchemyGraphRepository(session)
    question_repo = SQLAlchemyQuestionRepository(session)
    move_repo = SQLAlchemyBattleMoveRepository(session)
    use_case = SubmitAnswer(battle_repo, graph_repo, question_repo, move_repo)
    try:
        result, battle = await use_case.execute(
            UUID(battle_id),
            UUID(payload["sub"]),
            UUID(body.node_id),
            UUID(body.question_id),
            body.chosen_answer,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)
        ) from exc
    if result is None:
        await session.commit()
        graph = await graph_repo.get_by_id(battle.graph_id)
        battle_response = _battle_response(battle, graph)
        await battle_manager.broadcast(
            battle.id,
            {
                "type": "battle_update",
                "payload": battle_response.model_dump(mode="json"),
            },
        )
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Turn expired before the answer was received",
        )
    if result.battle_finished:
        moves = await move_repo.list_by_battle(battle.id)
        progression = ProgressionService(
            SQLAlchemyUserRepository(session),
            SQLAlchemyRankRepository(session),
            SQLAlchemyXPTransactionRepository(session),
        )
        for player_index, player_id in enumerate(
            (battle.player_1_id, battle.player_2_id)
        ):
            correct_answers = sum(
                move.is_correct and move.player_index == player_index for move in moves
            )
            amount = 10 + min(correct_answers * 2, 20)
            if battle.winner_id == player_id:
                amount += 30
            await progression.award_xp(
                player_id,
                amount,
                "battle",
                battle.id,
                "Batalla finalizada",
            )
    await session.commit()
    graph = await graph_repo.get_by_id(battle.graph_id)
    battle_response = _battle_response(battle, graph)
    await battle_manager.broadcast(
        battle.id,
        {
            "type": "battle_update",
            "payload": battle_response.model_dump(mode="json"),
        },
    )
    return _answer_result_response(result, battle)


@router.get("/{battle_id}", response_model=BattleResponse)
async def get_battle(
    battle_id: str,
    session: AsyncSession = Depends(get_db),
    payload: dict = Depends(get_current_user),
):
    battle_repo = SQLAlchemyBattleRepository(session)
    graph_repo = SQLAlchemyGraphRepository(session)
    use_case = GetBattle(battle_repo)
    try:
        battle = await use_case.execute(UUID(battle_id))
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)
        ) from exc
    user_id = UUID(payload["sub"])
    if payload["role"] == Role.STUDENT.value:
        if user_id not in {battle.player_1_id, battle.player_2_id}:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Player is not part of this battle",
            )
    else:
        player = await SQLAlchemyUserRepository(session).get_by_id(battle.player_1_id)
        if player is None or str(player.school_id) != payload.get("school_id"):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Battle belongs to another school",
            )
    graph = await graph_repo.get_by_id(battle.graph_id)
    if graph is not None:
        battle, expired_turns = await _reconcile_turn_clock(
            battle, graph, battle_repo, session
        )
        if expired_turns:
            await battle_manager.broadcast(
                battle.id,
                {
                    "type": "battle_update",
                    "payload": _battle_response(battle, graph).model_dump(mode="json"),
                },
            )
    return _battle_response(battle, graph)
