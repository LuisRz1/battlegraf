"""Graph generation endpoints."""

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from src.application.graph.use_cases import GenerateGraph
from src.domain.enums import Role
from src.infrastructure.auth.dependencies import require_role
from src.infrastructure.database.repositories import SQLAlchemyGraphRepository
from src.infrastructure.database.session import get_db
from src.presentation.schemas.requests.graph_requests import GenerateGraphRequest
from src.presentation.schemas.responses.graph_responses import (
    GraphNodeResponse,
    GraphResponse,
)

router = APIRouter(prefix="/graphs", tags=["Graphs"])

teacher_access = require_role(
    Role.PROFESSOR,
    Role.TUTOR,
    Role.DIRECTOR,
    Role.SUBDIRECTOR,
)


def _graph_response(graph) -> GraphResponse:
    return GraphResponse(
        id=str(graph.id),
        num_layers=graph.num_layers,
        min_nodes_per_layer=graph.min_nodes_per_layer,
        max_nodes_per_layer=graph.max_nodes_per_layer,
        subjects=[s.value for s in graph.subjects],
        nodes=[
            GraphNodeResponse(
                id=str(n.id),
                layer=n.layer,
                position=n.position,
                subject=n.subject.value,
                color=n.color,
                question_ids=[str(q) for q in n.question_ids],
                connected_to=[str(q) for q in n.connected_to],
            )
            for n in graph.nodes
        ],
        created_at=graph.created_at,
    )


@router.get("", response_model=list[GraphResponse])
async def list_graphs(
    session: AsyncSession = Depends(get_db),
    _=Depends(teacher_access),
):
    graph_repo = SQLAlchemyGraphRepository(session)
    graphs = await graph_repo.list_all()
    # invalidar lazy load: los nodos ya estan cargados por el repo
    return [_graph_response(g) for g in graphs]


@router.post("", response_model=GraphResponse, status_code=status.HTTP_201_CREATED)
async def generate_graph(
    body: GenerateGraphRequest,
    session: AsyncSession = Depends(get_db),
    _=Depends(teacher_access),
):
    graph_repo = SQLAlchemyGraphRepository(session)
    use_case = GenerateGraph(graph_repo)
    graph = await use_case.execute(
        num_layers=body.num_layers,
        min_nodes_per_layer=body.min_nodes_per_layer,
        max_nodes_per_layer=body.max_nodes_per_layer,
        subjects=body.subjects,
    )
    await session.commit()
    return _graph_response(graph)


@router.get("/{graph_id}", response_model=GraphResponse)
async def get_graph(
    graph_id: str,
    session: AsyncSession = Depends(get_db),
    _=Depends(teacher_access),
):
    graph_repo = SQLAlchemyGraphRepository(session)
    graph = await graph_repo.get_by_id(UUID(graph_id))
    if graph is None:
        raise HTTPException(status_code=404, detail="Grafo no encontrado")
    return _graph_response(graph)


@router.delete("/{graph_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_graph(
    graph_id: str,
    session: AsyncSession = Depends(get_db),
    _=Depends(teacher_access),
):
    graph_repo = SQLAlchemyGraphRepository(session)
    graph = await graph_repo.get_by_id(UUID(graph_id))
    if graph is None:
        raise HTTPException(status_code=404, detail="Grafo no encontrado")
    await graph_repo.delete(graph.id)
    await session.commit()
