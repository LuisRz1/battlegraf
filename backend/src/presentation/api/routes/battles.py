"""Battle endpoints for creation, startup, node selection, and answer submission."""

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from src.application.battle.use_cases import CreateBattle, GetBattle, StartBattle, SubmitAnswer
from src.domain.enums import Role
from src.infrastructure.auth.dependencies import get_current_user, require_role
from src.infrastructure.database.repositories import (
    SQLAlchemyBattleMoveRepository,
    SQLAlchemyBattleRepository,
    SQLAlchemyGraphRepository,
    SQLAlchemyQuestionRepository,
    SQLAlchemyUserRepository,
)
from src.infrastructure.database.session import get_db
from src.presentation.schemas.requests.battle_requests import (
    CreateBattleRequest,
    SelectNodeRequest,
    StartBattleRequest,
    SubmitAnswerRequest,
)
from src.presentation.schemas.responses.battle_responses import (
    AnswerResultResponse,
    BattleNodeStateResponse,
    BattleResponse,
)

router = APIRouter(prefix="/battles", tags=["Battles"])


def _battle_response(battle, graph=None) -> BattleResponse:
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
        winner_id=str(battle.winner_id) if battle.winner_id else None,
        turn_timeout_seconds=battle.turn_timeout_seconds,
        node_states=[
            BattleNodeStateResponse(
                node_id=str(s.node_id),
                layer=node_lookup.get(s.node_id).layer if s.node_id in node_lookup else 0,
                subject=node_lookup.get(s.node_id).subject.value if s.node_id in node_lookup else "",
                color=node_lookup.get(s.node_id).color if s.node_id in node_lookup else "",
                connected_to=[str(c) for c in node_lookup.get(s.node_id).connected_to] if s.node_id in node_lookup else [],
                question_ids=[str(q) for q in node_lookup.get(s.node_id).question_ids] if s.node_id in node_lookup else [],
                owner=s.owner,
                attempt_count=s.attempt_count,
                best_time_ms=s.best_time_ms,
            )
            for s in battle.node_states.values()
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
        result.append(_battle_response(battle, graph))
    return result


@router.post("", response_model=BattleResponse, status_code=status.HTTP_201_CREATED)
async def create_battle(
    body: CreateBattleRequest,
    session: AsyncSession = Depends(get_db),
    payload: dict = Depends(require_role(Role.STUDENT, Role.PROFESSOR, Role.TUTOR, Role.DIRECTOR)),
):
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
            school_id=UUID(payload.get("school_id")) if payload.get("school_id") else None,
        )
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    await session.commit()
    graph = await graph_repo.get_by_id(battle.graph_id)
    return _battle_response(battle, graph)


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
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    await session.commit()
    graph = await graph_repo.get_by_id(battle.graph_id)
    return _battle_response(battle, graph)


@router.post("/{battle_id}/select-node", response_model=BattleResponse)
async def select_node(
    battle_id: str,
    body: SelectNodeRequest,
    session: AsyncSession = Depends(get_db),
    payload: dict = Depends(get_current_user),
):
    battle_repo = SQLAlchemyBattleRepository(session)
    graph_repo = SQLAlchemyGraphRepository(session)
    question_repo = SQLAlchemyQuestionRepository(session)
    battle = await GetBattle(battle_repo).execute(UUID(battle_id))
    graph = await graph_repo.get_by_id(battle.graph_id)
    if not graph:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Graph not found")

    from src.domain.services.battle_engine import BattleEngine

    questions = {q.id: q for q in await question_repo.list_by_ids([])}
    engine = BattleEngine(battle, graph, questions)
    player_index = 0 if battle.player_1_id == UUID(payload["sub"]) else 1
    try:
        engine.select_node(player_index, UUID(body.node_id))
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    return _battle_response(battle, graph)


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
            body.response_time_ms,
        )
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    await session.commit()
    return _answer_result_response(result, battle)


@router.get("/{battle_id}", response_model=BattleResponse)
async def get_battle(
    battle_id: str,
    session: AsyncSession = Depends(get_db),
    _=Depends(get_current_user),
):
    battle_repo = SQLAlchemyBattleRepository(session)
    graph_repo = SQLAlchemyGraphRepository(session)
    use_case = GetBattle(battle_repo)
    try:
        battle = await use_case.execute(UUID(battle_id))
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    graph = await graph_repo.get_by_id(battle.graph_id)
    return _battle_response(battle, graph)
