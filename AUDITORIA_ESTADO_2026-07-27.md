# Auditoría de estado de BattleGraf

**Fecha:** 27 de julio de 2026  
**Repositorio revisado:** `D:\battlegraf`  
**Vault revisado:** `C:\Users\edwin\Documents\Minedu-Hackathon\Obsidian`

## Dictamen

BattleGraf **no está terminado**. Al comenzar esta auditoría era un prototipo
con avances parciales en las fases 0 a 4 y una fase 5 apenas modelada. La captura
que indicaba “fase 4/5 finalizada” no coincidía con una ejecución integrada:
Flutter y FastAPI usaban contratos diferentes para una batalla y el grafo real
no podía mostrarse correctamente.

Tras las correcciones de esta revisión existe un **MVP técnico parcial y
testeable** para:

- autenticación y usuarios básicos por colegio;
- carga de material y banco de preguntas;
- generación y aprobación de preguntas;
- creación y juego REST de batallas 1 contra 1;
- actualización del estado mediante WebSocket autenticado;
- tareas de alternativas, respuesta abierta y archivo en el backend;
- XP, rangos, clasificaciones y clanes;
- pantallas Flutter de estudiante para lobby, batalla, tareas y progresión.

Esto todavía no equivale a un piloto escolar completo ni a un producto
publicable.

## Trazabilidad del requerimiento original

| Requerimiento | Estado comprobado | Observación |
|---|---|---|
| Colegio como entidad raíz | Parcial | Existe modelo y API básica; falta onboarding integral en una sola operación. |
| Secciones por aula | Parcial | Se pueden crear y asociar usuarios; falta CRUD completo y administración móvil. |
| Director, subdirector, tutor, profesor y alumno | Parcial | Los roles y varias restricciones existen; faltan asignaciones profesor-materia-sección. |
| Credenciales y permisos por usuario | Parcial | JWT y RBAC básico; falta revocación inmediata de tokens y gestión completa de cuentas. |
| Materias configurables por colegio | Pendiente | Hay enum global de materias, no catálogo/configuración institucional. |
| Clanes y rangos configurables | Parcial | Backend, membresía y rangos por colegio disponibles; falta panel de gestión completo. |
| Material PDF, PPT/PPTX, DOCX e imagen | Parcial | PDF, DOCX, PPTX y TXT funcionan. No hay OCR para imágenes. |
| Agente que crea preguntas/tareas/clases | Parcial | Genera preguntas con fallback; no crea todavía clases o tareas completas desde IA. |
| Banco de 100 preguntas por materia | Parcial | Banco persistente, aprobación, rotación y contador existen; no se fuerza todavía el objetivo de 100. |
| Cinco preguntas por nodo | Implementado | Se asignan cinco aprobadas por nodo y se evita repetir una pregunta ya usada en ese nodo. |
| Grafo mínimo de cuatro capas | Implementado | Validación y configuración desde la creación de batalla. |
| Tres a cuatro nodos por capa | Implementado con bases | Las capas interiores usan el rango; primera y última tienen una base única. |
| Colores por materia | Implementado | Se conservan en el contrato API y en Flutter. |
| Movimiento sólo por conexiones | Implementado | Validado en el servidor para ambos sentidos del tablero. |
| Victoria al llegar a la base rival | Implementado | Se retiró la victoria incorrecta por mayoría de nodos. |
| Robo por menor tiempo | Implementado parcialmente | Menor tiempo roba; en empate conserva el defensor. El tiempo aún nace en el cliente. |
| Batalla por turnos | Implementado | Turnos y estado persistente; falta expiración oficial del turno en servidor. |
| Competencia entre secciones | Pendiente | Sólo existe batalla individual entre estudiantes del mismo colegio. |
| Tareas de alternativas, abiertas y archivo | Backend implementado | Flutter resuelve alternativas/abiertas; selector y subida de archivo aún pendientes. |
| XP por tareas y batallas | Implementado parcialmente | Libro contable idempotente y rango automático; falta cerrar todas las reglas PB/PC/temporadas. |
| Leaderboard por sección y colegio | Implementado en MVP | Endpoints y vista Flutter de progresión. |
| Estilo rojo/morado retro, sin emojis | Parcial | Tema y tablero siguen esa dirección; falta QA visual y animación final en dispositivos. |
| iPhone y Android | Parcial | Proyecto Flutter y configuración de red; no se generaron builds de distribución. |

## Estado por fase

| Fase | Estado real al cierre de esta auditoría | Falta principal |
|---|---|---|
| 0. Fundación | Avanzada, no cerrada | Probar Docker/Compose en un host compatible y endurecer configuración productiva. |
| 1. Gestión de colegios | Parcial | Materias institucionales, asignaciones docentes, importación CSV y onboarding UI. |
| 2. Banco e IA | Parcial funcional | OCR de imágenes, edición/eliminación, generación controlada de 100 y costos/rate limit. |
| 3. Grafos y batallas | MVP funcional | Reloj oficial, invitación/aceptación, reconexión, concurrencia y E2E con dos clientes. |
| 4. Flutter core | MVP parcial | Resultados, configuración completa, administración docente, archivos y QA en equipos reales. |
| 5. Tareas y progresión | MVP backend + estudiante parcial | UI docente, archivo móvil, políticas de retraso/recalificación y reglas avanzadas. |
| 6. Secciones y dashboard | No iniciada | Equipos, agregación por sección, métricas y exportación. |
| 7. Producción | No iniciada | Seguridad, carga, observabilidad, offline, accesibilidad, publicación y operación. |

## Defectos importantes encontrados y corregidos

### Batallas

- El backend devolvía `node_states`, mientras Flutter esperaba un objeto
  `graph`; la pantalla podía mostrar “Grafo no disponible”.
- El jugador 2 no podía avanzar desde su extremo porque el recorrido sólo se
  calculaba hacia capas crecientes.
- Era posible responder una pregunta ajena al nodo o atacar un nodo
  inaccesible mediante la API.
- El robo se resolvía después de sobrescribir el mejor tiempo, por lo que se
  concedía incorrectamente; también faltaba conservar al defensor en empate.
- Existía una condición de victoria por mayoría no definida en el requerimiento.
- Los nodos recibían sólo tres preguntas y podían quedar con listas vacías.
- Se permitían combinaciones inválidas de participantes.

### Integración y seguridad

- La URL móvil apuntaba a un puerto distinto y a `localhost`, que no representa
  al host desde Android Emulator.
- Android no declaraba permiso de Internet y iOS no tenía excepción local de
  desarrollo.
- El WebSocket aceptaba conexiones y reenvío de mensajes sin autenticar.
- Varias consultas de bancos, secciones y usuarios no comprobaban
  consistentemente el colegio del actor.
- Se podía filtrar la respuesta correcta a clientes que no debían verla.
- La carga local permitía rutas y tipos sin suficientes límites.
- Las cuentas desactivadas aún podían iniciar una sesión nueva.

### Calidad e infraestructura

- Pytest no resolvía correctamente el paquete y las fixtures asíncronas fallaban
  por alcance.
- CI instalaba dependencias sin el extra de desarrollo.
- El Docker Compose no iniciaba la API y referenciaba una aplicación Celery
  inexistente.
- El README indicaba usar Alembic aunque no había configuración ni revisiones.
- Ruff reportaba 143 incidencias y mypy 17 antes de las correcciones.

## Implementación añadida en esta revisión

- Motor de grafo y batalla corregido, con pruebas unitarias.
- Contrato único de batalla FastAPI/Flutter, probado con una respuesta real.
- Selección de preguntas por nodo sin exponer la respuesta correcta.
- WebSocket autenticado y limitado a participantes.
- XP de batalla idempotente.
- CRUD de ciclo de vida de tareas y entregas, calificación y XP.
- Rangos predeterminados, rango automático, libro de XP, leaderboards y clanes.
- Vistas Flutter de tareas y progresión.
- Validación de archivos y extracción de PPTX.
- Migración Alembic inicial compatible con una instalación limpia y con la base
  SQLite local anterior.
- API y trabajador Celery incluidos en Docker Compose.
- CI corregido y comandos de validación documentados.

## Evidencia de validación

Al cierre:

- `pytest`: **26 pruebas aprobadas**.
- `ruff`: **sin incidencias**.
- `mypy`: **sin incidencias en 87 archivos fuente**.
- `black --check`: formato consistente después de aplicar Black.
- `flutter analyze`: **sin incidencias**.
- `flutter test`: **7 pruebas aprobadas**.
- Alembic: migración aprobada en una base limpia y en una copia de
  `backend\battlegraf.db`.
- Docker Compose: **no ejecutado**; el Docker instalado en la máquina no dispone
  del comando Compose v2 y no existe el binario `docker-compose`.

## Riesgos y siguiente orden recomendado

1. Ejecutar un E2E con dos clientes Flutter reales contra PostgreSQL/Redis y
   resolver reloj, reintentos y reconexión.
2. Terminar fase 1: catálogo de materias, asignaciones docentes, importación CSV
   y onboarding del colegio.
3. Completar las interfaces docentes de preguntas, tareas, calificación, rangos
   y clanes.
4. Implementar políticas explícitas de tareas, PB/XP/PC, temporadas,
   convivencia y auditoría de acciones.
5. Construir fase 6 (competencias entre secciones y dashboards).
6. Hacer seguridad, carga, accesibilidad, observabilidad, copias de seguridad y
   builds firmados antes de cualquier uso con estudiantes.

## Criterio para declarar el MVP terminado

No debe declararse terminado hasta que, como mínimo, un colegio pueda
configurarse sin intervención manual, dos alumnos puedan completar una batalla
en dispositivos distintos con tiempo oficial del servidor, un profesor pueda
crear/revisar preguntas y tareas desde la app, el XP sea trazable, y todo el
recorrido pase una prueba E2E sobre la infraestructura de despliegue.
