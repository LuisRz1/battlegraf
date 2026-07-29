"""Use cases for battle management."""

from collections import defaultdict
from datetime import UTC, datetime
from uuid import UUID

from src.domain.entities import Battle, BattleNodeState, Question
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
        num_layers: int = 4,
        min_nodes_per_layer: int = 3,
        max_nodes_per_layer: int = 4,
    ) -> Battle:
        if player_1_id == player_2_id:
            raise ValueError("A student cannot battle themselves")

        players = []
        for user_id in (player_1_id, player_2_id):
            user = await self.user_repo.get_by_id(user_id)
            if not user or not user.is_active:
                raise ValueError("User not found or inactive")
            if user.role != Role.STUDENT:
                raise ValueError("Battles are only between students")
            if user.school_id is None:
                raise ValueError("Both students must belong to a school")
            players.append(user)

        if players[0].school_id != players[1].school_id:
            raise ValueError(
                "Students from different schools cannot use this battle mode"
            )
        effective_school_id = players[0].school_id
        assert effective_school_id is not None
        if school_id is not None and school_id != effective_school_id:
            raise ValueError("Battle school does not match the students' school")

        questions = await self.question_repo.list_by_school(effective_school_id)
        approved = [question for question in questions if question.is_approved]
        if not approved:
            raise ValueError("The school has no approved questions")

        if graph_id:
            graph = await self.graph_repo.get_by_id(graph_id)
            if not graph:
                raise ValueError("Graph not found")
            graph_is_new = False
        else:
            builder = GraphBuilder(
                GraphConfig(
                    num_layers=num_layers,
                    min_nodes_per_layer=min_nodes_per_layer,
                    max_nodes_per_layer=max_nodes_per_layer,
                    subjects=subjects or [Subject.MATH],
                )
            )
            graph = builder.build()
            graph_is_new = True

        by_subject = defaultdict(list)
        for question in approved:
            by_subject[question.subject].append(question)

        subject_offsets: dict[Subject, int] = defaultdict(int)
        assignment_counts: dict[UUID, int] = defaultdict(int)
        for node in graph.nodes:
            pool = by_subject[node.subject]
            if len(pool) < 5:
                raise ValueError(
                    f"At least 5 approved questions are required for {node.subject.label}"
                )
            offset = subject_offsets[node.subject]
            assigned = [pool[(offset + index) % len(pool)] for index in range(5)]
            subject_offsets[node.subject] = (offset + 5) % len(pool)
            node.question_ids = [question.id for question in assigned]
            for question in assigned:
                assignment_counts[question.id] += 1

        if graph_is_new:
            graph = await self.graph_repo.create(graph)
        else:
            for node in graph.nodes:
                await self.graph_repo.update_node_questions(node.id, node.question_ids)

        for question in approved:
            assigned_count = assignment_counts.get(question.id, 0)
            if assigned_count:
                question.usage_count += assigned_count
                await self.question_repo.update(question)

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
        battle = await self.battle_repo.get_by_id_for_update(battle_id)
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

    async def _load_questions(self, graph) -> dict[UUID, Question]:
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
    ):
        battle = await self.battle_repo.get_by_id_for_update(battle_id)
        if not battle:
            raise ValueError("Battle not found")

        player_index = self._get_player_index(battle, player_id)
        graph = await self.graph_repo.get_by_id(battle.graph_id)
        if not graph:
            raise ValueError("Graph not found")

        battle.moves = list(await self.move_repo.list_by_battle(battle_id))
        questions = await self._load_questions(graph)
        engine = BattleEngine(battle, graph, questions)
        server_received_at = datetime.now(UTC)
        if engine.expire_turn_if_needed(server_received_at):
            await self.battle_repo.update(battle)
            return None, battle
        result = engine.answer_question(
            player_index=player_index,
            node_id=node_id,
            question_id=question_id,
            chosen_answer=chosen_answer,
            answered_at=server_received_at,
        )

        await self.move_repo.create(battle.moves[-1])

        await self.battle_repo.update(battle)
        return result, battle

    def _get_player_index(self, battle: Battle, player_id: UUID) -> int:
        if battle.player_1_id == player_id:
            return 0
        if battle.player_2_id == player_id:
            return 1
        raise ValueError("Player is not part of this battle")

    async def _load_questions(self, graph) -> dict[UUID, Question]:
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
