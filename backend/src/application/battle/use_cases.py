"""Use cases for battle management."""

from collections import defaultdict
from uuid import UUID

from src.domain.entities import Battle, BattleNodeState
from src.domain.enums import BattleStatus, Role, Subject
from src.domain.interfaces.repositories import (
    BattleMoveRepository,
    BattleRepository,
    GraphRepository,
    QuestionRepository,
    UserRepository,
)
from src.domain.services.battle_engine import BattleEngine
from src.domain.services.graph_builder import GraphBuilder, GraphConfig


class CreateBattle:
    """Create a pending battle between two players."""

    def __init__(
        self,
        battle_repo: BattleRepository,
        graph_repo: GraphRepository,
        question_repo: QuestionRepository,
        user_repo: UserRepository,
    ) -> None:
        self.battle_repo = battle_repo
        self.graph_repo = graph_repo
        self.question_repo = question_repo
        self.user_repo = user_repo

    async def execute(
        self,
        player_1_id: UUID,
        player_2_id: UUID,
        graph_id: UUID | None = None,
        subjects: list[Subject] | None = None,
        school_id: UUID | None = None,
    ) -> Battle:
        for user_id in (player_1_id, player_2_id):
            user = await self.user_repo.get_by_id(user_id)
            if not user:
                raise ValueError("User not found")
            if user.role != Role.STUDENT:
                raise ValueError("Battles are only between students")

        if graph_id:
            graph = await self.graph_repo.get_by_id(graph_id)
            if not graph:
                raise ValueError("Graph not found")
        else:
            builder = GraphBuilder(GraphConfig(subjects=subjects or [Subject.MATH]))
            graph = builder.build()
            graph = await self.graph_repo.create(graph)

        # Attach questions to graph nodes from school bank
        if school_id:
            questions = await self.question_repo.list_by_school(school_id)
            approved = [q for q in questions if q.is_approved]
            if not approved:
                approved = list(questions)
            if approved:
                by_subject = defaultdict(list)
                for q in approved:
                    by_subject[q.subject.value].append(q)
                for node in graph.nodes:
                    pool = by_subject.get(node.subject.value, approved)
                    assigned = pool[: min(3, len(pool))]
                    node.question_ids = [q.id for q in assigned]
                # Persist the assigned questions to the graph nodes
                for node in graph.nodes:
                    await self.graph_repo.update_node_questions(node.id, node.question_ids)

        battle = Battle(
            player_1_id=player_1_id,
            player_2_id=player_2_id,
            graph_id=graph.id,
            status=BattleStatus.PENDING,
            node_states={n.id: BattleNodeState(node_id=n.id) for n in graph.nodes},
        )
        return await self.battle_repo.create(battle)


class StartBattle:
    """Start a pending battle and persist state."""

    def __init__(
        self,
        battle_repo: BattleRepository,
        graph_repo: GraphRepository,
        question_repo: QuestionRepository,
    ) -> None:
        self.battle_repo = battle_repo
        self.graph_repo = graph_repo
        self.question_repo = question_repo

    async def execute(self, battle_id: UUID, requesting_player_id: UUID) -> Battle:
        battle = await self.battle_repo.get_by_id(battle_id)
        if not battle:
            raise ValueError("Battle not found")
        if battle.status != BattleStatus.PENDING:
            raise ValueError("Battle is not pending")
        if requesting_player_id not in (battle.player_1_id, battle.player_2_id):
            raise ValueError("Player is not part of this battle")

        graph = await self.graph_repo.get_by_id(battle.graph_id)
        if not graph:
            raise ValueError("Graph not found")

        questions = await self._load_questions(graph)
        engine = BattleEngine(battle, graph, questions)
        engine.start_battle()
        return await self.battle_repo.update(battle)

    async def _load_questions(self, graph) -> dict[UUID, object]:
        question_ids: set[UUID] = set()
        for node in graph.nodes:
            question_ids.update(node.question_ids)
        if not question_ids:
            return {}
        questions = await self.question_repo.list_by_ids(list(question_ids))
        return {q.id: q for q in questions}


class SubmitAnswer:
    """Process a player's answer in a battle."""

    def __init__(
        self,
        battle_repo: BattleRepository,
        graph_repo: GraphRepository,
        question_repo: QuestionRepository,
        move_repo: BattleMoveRepository,
    ) -> None:
        self.battle_repo = battle_repo
        self.graph_repo = graph_repo
        self.question_repo = question_repo
        self.move_repo = move_repo

    async def execute(
        self,
        battle_id: UUID,
        player_id: UUID,
        node_id: UUID,
        question_id: UUID,
        chosen_answer: str,
        response_time_ms: int,
    ):
        battle = await self.battle_repo.get_by_id(battle_id)
        if not battle:
            raise ValueError("Battle not found")

        player_index = self._get_player_index(battle, player_id)
        graph = await self.graph_repo.get_by_id(battle.graph_id)
        if not graph:
            raise ValueError("Graph not found")

        questions = await self._load_questions(graph)
        engine = BattleEngine(battle, graph, questions)
        result = engine.answer_question(
            player_index=player_index,
            node_id=node_id,
            question_id=question_id,
            chosen_answer=chosen_answer,
            response_time_ms=response_time_ms,
        )

        for move in battle.moves:
            if not move.id:
                continue
            existing = await self.move_repo.list_by_battle(battle_id)
            existing_ids = {m.id for m in existing}
            if move.id not in existing_ids:
                await self.move_repo.create(move)

        await self.battle_repo.update(battle)
        return result, battle

    def _get_player_index(self, battle: Battle, player_id: UUID) -> int:
        if battle.player_1_id == player_id:
            return 0
        if battle.player_2_id == player_id:
            return 1
        raise ValueError("Player is not part of this battle")

    async def _load_questions(self, graph) -> dict[UUID, object]:
        question_ids: set[UUID] = set()
        for node in graph.nodes:
            question_ids.update(node.question_ids)
        if not question_ids:
            return {}
        questions = await self.question_repo.list_by_ids(list(question_ids))
        return {q.id: q for q in questions}


class GetBattle:
    """Retrieve a battle by id."""

    def __init__(self, battle_repo: BattleRepository) -> None:
        self.battle_repo = battle_repo

    async def execute(self, battle_id: UUID) -> Battle:
        battle = await self.battle_repo.get_by_id(battle_id)
        if not battle:
            raise ValueError("Battle not found")
        return battle
