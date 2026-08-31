# BATTLEGRAF -- Documento Maestro del Sistema

> Version: 3.0 -- Julio 2026
> Tipo: Especificacion Tecnica Integral
> Estado: Documento de referencia completa

---

## TABLA DE CONTENIDOS

1. [Vision General](#1-vision-general)
2. [Entidades del Sistema](#2-entidades-del-sistema)
3. [Secciones y Grupos por Aula](#3-secciones-y-grupos-por-aula)
4. [Sistema de Roles y Jerarquia](#4-sistema-de-roles-y-jerarquia)
5. [Sistema de Rangos](#5-sistema-de-rangos)
6. [Sistema de Clanes](#6-sistema-de-clanes)
7. [Banco de Preguntas e Inteligencia Artificial](#7-banco-de-preguntas-e-inteligencia-artificial)
8. [Grafos de Batalla -- Mecanica Completa](#8-grafos-de-batalla----mecanica-completa)
9. [Batallas -- Flujo Completo](#9-batallas----flujo-completo)
10. [Sistema de Tareas](#10-sistema-de-tareas)
11. [Configuracion Inicial del Colegio](#11-configuracion-inicial-del-colegio)
12. [Arquitectura Tecnica](#12-arquitectura-tecnica)
13. [API y Endpoints](#13-api-y-endpoints)
14. [Protocolo WebSocket](#14-protocolo-websocket)
15. [Interfaz Visual y Estetica](#15-interfaz-visual-y-estetica)
16. [Analisis de Puntos Debiles](#16-analisis-de-puntos-debiles)
17. [Flujos Alternos Criticos](#17-flujos-alternos-criticos)
18. [Consideraciones de Seguridad](#18-consideraciones-de-seguridad)
19. [Vision a Futuro](#19-vision-a-futuro)
20. [Plan de Implementacion Detallado](#20-plan-de-implementacion-detallado)

---

## 1. VISION GENERAL

### 1.1 Que es BattleGraph

BattleGraph es una plataforma escolar multiplayer de aprendizaje gamificado por grafos. Convierte la practica curricular en batallas estrategicas sobre un tablero de nodos, donde cada respuesta correcta conquista territorio y cada partida genera datos utiles para el docente.

El sistema opera a nivel de colegio: una institucion educativa se registra como entidad raiz y a partir de ahi configura todas sus aulas (secciones), materias, profesores, alumnos, rangos y clanes. Los profesores suben material de clase y un agente de IA genera preguntas de alternativa multiple. Los alumnos compiten entre si en batallas 1v1 sobre grafos por turnos, donde cada nodo representa un reto de una materia especifica.

### 1.2 Problema que resuelve

Las actividades de repaso basadas unicamente en repeticion o preguntas aisladas no sostienen la atencion del estudiante ni permiten que perciba su progreso. El docente necesita reconocer con rapidez que contenidos fueron comprendidos y cuales requieren refuerzo. BattleGraph ataca ambos problemas simultaneamente: motiva al alumno con mecanicas de competencia estrategica y genera datos granulares por materia, nodo y tiempo para el profesor.

### 1.3 Diferenciador clave

Un quiz tradicional mide respuestas y entrega un puntaje. BattleGraph convierte cada respuesta en una decision que modifica un mapa. El grafo cumple tres funciones simultaneas:

- Es el tablero estrategico de la partida
- Representa el progreso visible del estudiante
- Organiza evidencias por contenido para el docente

### 1.4 Contexto del proyecto

BattleGraph nacio en el marco de la Hackathon en Tecnologias Digitales del Minedu 2026, en la Categoria A (Expertos). La propuesta se alinea con el ODS 4 (Educacion de calidad) y ODS 10 (Reduccion de desigualdades). Cuenta con sustento investigativo de OECD, UNESCO, estudios sobre gamificacion educativa, game-based assessment, analitica de aprendizaje y grafos de conocimiento. El Curriculo Nacional del Peru respalda las competencias digitales y el aprendizaje autonomo que BattleGraph promueve.

---

## 2. ENTIDADES DEL SISTEMA

El sistema se compone de las siguientes entidades principales, cada una con sus atributos, relaciones y reglas de negocio.

### 2.1 Colegio (School)

La entidad raiz de todo el sistema. Un colegio se registra y a partir de ahi se configura todo lo demas.

| Atributo | Tipo | Descripcion |
|----------|------|-------------|
| id | UUID | Identificador unico |
| name | String (255) | Nombre oficial del colegio |
| region | String (255) | Ubicacion geografica o region |
| level | String (20) | "primary", "secondary" o "both" |
| is_active | Boolean | Estado del colegio en la plataforma |
| created_at | DateTime | Fecha de registro |

**Relaciones:**
- 1 Colegio tiene N Secciones
- 1 Colegio tiene N Usuarios (alumnos, profesores, directivos)
- 1 Colegio tiene N Bancos de Preguntas
- 1 Colegio tiene N Rangos configurados

**Reglas de negocio:**
- Solo un Director puede crear un colegio
- Al registrar un Director, se crea automaticamente el colegio asociado
- Un colegio inactivo no permite batallas ni acceso de alumnos

### 2.2 Seccion (Section)

Representa un aula real dentro del colegio.

| Atributo | Tipo | Descripcion |
|----------|------|-------------|
| id | UUID | Identificador unico |
| school_id | UUID (FK) | Colegio al que pertenece |
| name | String (255) | Ejemplo: "5to Primaria - Seccion A" |
| grade | Integer | Grado numerico (1-6 primaria, 1-5 secundaria) |
| level | String (50) | "primary" o "secondary" |
| tutor_id | UUID (FK, nullable) | Tutor asignado |
| is_active | Boolean | Si la seccion esta operativa |
| created_at | DateTime | Fecha de creacion |

**Relaciones:**
- 1 Seccion pertenece a 1 Colegio
- 1 Seccion tiene 1 Tutor asignado (opcional)
- 1 Seccion tiene N Alumnos
- 1 Seccion tiene N Clanes internos

### 2.3 Usuario (User)

Entidad unificada para todos los tipos de usuario del sistema.

| Atributo | Tipo | Descripcion |
|----------|------|-------------|
| id | UUID | Identificador unico |
| username | String (100), unique | Nombre de usuario para login |
| email | String (255) | Correo electronico |
| hashed_password | String (255) | Contrasena encriptada con bcrypt |
| full_name | String (255) | Nombre completo |
| role | Enum Role | Director, Subdirector, Tutor, Profesor, Alumno |
| school_id | UUID (FK, nullable) | Colegio al que pertenece |
| section_id | UUID (FK, nullable) | Seccion asignada (alumnos y tutores) |
| xp | Integer | Puntos de experiencia acumulados |
| rank_id | UUID (FK, nullable) | Rango actual del alumno |
| clan_id | UUID (FK, nullable) | Clan al que pertenece (si aplica) |
| is_active | Boolean | Si la cuenta esta activa |
| created_at | DateTime | Fecha de creacion |

**Propiedades derivadas:**
- `is_teacher`: True si el rol es Director, Subdirector, Tutor o Profesor
- `is_student`: True si el rol es Alumno

**Metodos:**
- `add_xp(amount)`: Suma XP al usuario. El monto debe ser positivo.

### 2.4 Materia (Subject)

Las materias escolares disponibles estan definidas como un enum con 12 opciones:

| Materia | Valor interno | Color por defecto |
|---------|--------------|-------------------|
| Matematica | mathematics | #FF4444 (rojo) |
| Comunicacion | language | #4488FF (azul) |
| Ciencia y Tecnologia | science | #44CC44 (verde) |
| Fisica | physics | #FF8844 (naranja) |
| Quimica | chemistry | #AA44FF (violeta) |
| Biologia | biology | #44FF88 (verde claro) |
| Historia | history | #FFAA44 (dorado) |
| Geografia | geography | #44CCAA (turquesa) |
| Civica | civics | #FF4488 (rosa) |
| Ingles | english | #4488CC (azul medio) |
| Arte | art | #CC44FF (magenta) |
| Educacion Fisica | physical_education | #88CC44 (lima) |

Cada materia tiene:
- Un `label` legible en espanol
- Un `default_color` hexadecimal para representarla en el grafo

Las materias son configurables por colegio: el Director selecciona cuales estan habilitadas para su institucion.

### 2.5 Pregunta (Question)

| Atributo | Tipo | Descripcion |
|----------|------|-------------|
| id | UUID | Identificador unico |
| subject | Enum Subject | Materia a la que pertenece |
| school_id | UUID (FK) | Colegio propietario |
| bank_id | UUID (FK) | Banco al que pertenece |
| creator_id | UUID (FK) | Profesor que la creo o aprobo |
| text | Text | Enunciado de la pregunta |
| option_a | Text | Alternativa A |
| option_b | Text | Alternativa B |
| option_c | Text | Alternativa C |
| option_d | Text | Alternativa D |
| correct_option | String (1) | "A", "B", "C" o "D" |
| explanation | Text | Explicacion de la respuesta correcta |
| is_approved | Boolean | Si el profesor la aprobo |
| usage_count | Integer | Veces que se ha usado en batallas |
| created_at | DateTime | Fecha de generacion |

**Metodo:**
- `check_answer(answer)`: Compara la respuesta del alumno con la correcta (case-insensitive)

**Propiedad:**
- `options`: Retorna diccionario {"A": option_a, "B": option_b, ...}

### 2.6 Banco de Preguntas (QuestionBank)

| Atributo | Tipo | Descripcion |
|----------|------|-------------|
| id | UUID | Identificador unico |
| school_id | UUID (FK) | Colegio propietario |
| subject | Enum Subject | Materia del banco |
| total_generated | Integer | Total de preguntas generadas por IA |
| total_approved | Integer | Total de preguntas aprobadas |
| created_at | DateTime | Fecha de creacion |

**Regla:** Se genera 1 banco por materia por colegio. Se buscan 100 preguntas por banco. Solo las preguntas aprobadas por el profesor entran a las batallas.

### 2.7 Nodo del Grafo (GraphNode)

| Atributo | Tipo | Descripcion |
|----------|------|-------------|
| id | UUID | Identificador unico |
| graph_id | UUID (FK) | Grafo al que pertenece |
| layer | Integer | Capa dentro del grafo (0 a N-1) |
| position | Integer | Posicion dentro de la capa |
| subject | Enum Subject | Materia asignada |
| color | String (7) | Color hexadecimal segun la materia |
| question_ids | List[UUID] (JSON) | IDs de las 5 preguntas asignadas |
| connected_to | List[UUID] (JSON) | IDs de nodos conectados (capa anterior) |

### 2.8 Grafo (Graph)

| Atributo | Tipo | Descripcion |
|----------|------|-------------|
| id | UUID | Identificador unico |
| num_layers | Integer | Numero de capas (minimo 4) |
| min_nodes_per_layer | Integer | Nodos minimos por capa (3) |
| max_nodes_per_layer | Integer | Nodos maximos por capa (4) |
| subjects | List[String] (JSON) | Materias usadas en este grafo |
| nodes | Relacion | Lista de GraphNode |
| created_at | DateTime | Fecha de creacion |

**Metodos:**
- `get_start_node(player_index)`: Retorna el nodo inicial del jugador (capa 0 para J1, ultima capa para J2)
- `get_accessible_nodes(from_node_id, conquered_node_ids)`: Retorna los nodos accesibles desde una posicion + nodos ya conquistados

### 2.9 Batalla (Battle)

| Atributo | Tipo | Descripcion |
|----------|------|-------------|
| id | UUID | Identificador unico |
| player_1_id | UUID (FK) | Jugador 1 |
| player_2_id | UUID (FK) | Jugador 2 |
| graph_id | UUID (FK) | Grafo de la batalla |
| status | Enum BattleStatus | Estado actual |
| current_turn | Integer | 0 = turno de J1, 1 = turno de J2 |
| winner_id | UUID (FK, nullable) | Ganador de la batalla |
| turn_timeout_seconds | Integer | Tiempo limite por turno (default: 30s) |
| node_states | Dict[UUID, BattleNodeState] | Estado de cada nodo |
| player_positions | Dict[int, UUID] | Posicion actual de cada jugador |
| moves | List[BattleMove] | Historial de movimientos |
| is_section_battle | Boolean | Si es batalla entre secciones |
| created_at | DateTime | Fecha de inicio |
| finished_at | DateTime (nullable) | Fecha de finalizacion |

**Estados posibles (BattleStatus):**

| Estado | Valor | Descripcion |
|--------|-------|-------------|
| PENDING | pending | Esperando que el oponente acepte |
| IN_PROGRESS | in_progress | Batalla en curso |
| PAUSED | paused | Pausada por desconexion |
| FINISHED | finished | Finalizada con ganador |
| DRAW | draw | Empate |
| CANCELLED | cancelled | Cancelada |

**Propiedad:**
- `is_active`: True si el estado es PENDING, IN_PROGRESS o PAUSED

### 2.10 Estado de Nodo en Batalla (BattleNodeState)

| Atributo | Tipo | Descripcion |
|----------|------|-------------|
| node_id | UUID | Nodo al que corresponde |
| owner | Integer (nullable) | 0 = J1, 1 = J2, None = libre |
| attempt_count | Integer | Intentos realizados sobre este nodo |
| best_time_ms | Integer (nullable) | Mejor tiempo de respuesta (para robo) |

### 2.11 Movimiento de Batalla (BattleMove)

| Atributo | Tipo | Descripcion |
|----------|------|-------------|
| id | UUID | Identificador unico |
| battle_id | UUID (FK) | Batalla a la que pertenece |
| player_index | Integer | 0 o 1 |
| node_id | UUID (FK) | Nodo atacado |
| question_id | UUID (FK) | Pregunta respondida |
| chosen_answer | String (1) | Respuesta elegida |
| is_correct | Boolean | Si la respuesta fue correcta |
| response_time_ms | Integer | Tiempo de respuesta en milisegundos |
| is_steal_attempt | Boolean | Si fue un intento de robo |
| steal_successful | Boolean (nullable) | Si el robo fue exitoso |
| created_at | DateTime | Timestamp del movimiento |

### 2.12 Tarea (Task)

| Atributo | Tipo | Descripcion |
|----------|------|-------------|
| id | UUID | Identificador unico |
| creator_id | UUID (FK) | Profesor que la creo |
| section_id | UUID (FK) | Seccion destino |
| subject | Enum Subject | Materia |
| title | String (255) | Titulo de la tarea |
| description | Text | Descripcion o instrucciones |
| task_type | Enum TaskType | Tipo de tarea |
| due_date | DateTime (nullable) | Fecha limite |
| xp_reward | Integer | XP que otorga al completarla (default: 10) |
| created_at | DateTime | Fecha de creacion |

**Tipos de tarea (TaskType):**

| Tipo | Valor | Descripcion |
|------|-------|-------------|
| MULTIPLE_CHOICE | multiple_choice | Preguntas de alternativas |
| OPEN_ANSWER | open_answer | Respuesta abierta (texto) |
| FILE_UPLOAD | file_upload | Subida de documento |

### 2.13 Entrega de Tarea (TaskSubmission)

| Atributo | Tipo | Descripcion |
|----------|------|-------------|
| id | UUID | Identificador unico |
| task_id | UUID (FK) | Tarea a la que corresponde |
| student_id | UUID (FK) | Alumno que entrega |
| answer | Text | Respuesta (para open_answer y multiple_choice) |
| file_url | String (500, nullable) | URL del archivo subido |
| is_graded | Boolean | Si ya fue calificada |
| score | Integer | Puntaje asignado |
| submitted_at | DateTime | Fecha de entrega |

### 2.14 Rango (Rank)

| Atributo | Tipo | Descripcion |
|----------|------|-------------|
| id | UUID | Identificador unico |
| school_id | UUID (FK) | Colegio que define este rango |
| name | String (255) | Nombre del rango |
| level | Integer | Nivel numerico (1 = mas bajo) |
| xp_required | Integer | XP necesaria para alcanzar este rango |
| icon_url | String (500, nullable) | URL del icono o insignia |

### 2.15 Clan

| Atributo | Tipo | Descripcion |
|----------|------|-------------|
| id | UUID | Identificador unico |
| section_id | UUID (FK) | Seccion a la que pertenece |
| name | String (255) | Nombre del clan |
| total_score | Integer | Puntaje acumulado del clan |
| created_at | DateTime | Fecha de creacion |

---

## 3. SECCIONES Y GRUPOS POR AULA

### 3.1 Concepto

Cada colegio puede tener multiples secciones que representan aulas fisicas reales. Esto permite:

1. **Competencia interna**: Alumnos de la misma seccion compiten entre si
2. **Competencia inter-secciones**: Seccion A vs Seccion B del mismo grado
3. **Competencia inter-grados**: Con restricciones de dificultad apropiadas

### 3.2 Nomenclatura

Las secciones siguen la nomenclatura escolar peruana:
- "5to Primaria - Seccion A"
- "6to Primaria - Seccion A"
- "6to Primaria - Seccion B"
- "1ro Secundaria - Seccion A"
- etc.

### 3.3 Flujo de creacion

1. El Director registra el colegio
2. El Director o Subdirector crea las secciones indicando:
   - Nombre descriptivo
   - Grado numerico
   - Nivel (primaria/secundaria)
   - Tutor asignado (opcional en la creacion, puede asignarse despues)
3. Se pueden crear multiples secciones en una sola operacion (endpoint batch)

### 3.4 Batallas entre secciones

Cuando se activa una batalla entre secciones:
- Un representante o grupo de alumnos de cada seccion participa
- El puntaje es acumulativo de la seccion
- Los resultados alimentan un leaderboard inter-secciones
- El flag `is_section_battle` en la entidad Battle identifica estas batallas

### 3.5 Consideraciones

- Un alumno pertenece a exactamente una seccion
- Si un alumno cambia de seccion, su historial se mantiene pero su posicion en leaderboards cambia
- Los clanes existen dentro de una seccion especifica, no cruzan secciones

---

## 4. SISTEMA DE ROLES Y JERARQUIA

### 4.1 Tabla de roles

| Nivel | Rol | Alcance de vision | Permisos |
|-------|-----|--------------------|----------|
| 1 | Director | Todo el colegio | CRUD de secciones, asignar tutores, ver todas las metricas, modificar cualquier configuracion, crear/eliminar usuarios de cualquier nivel inferior |
| 2 | Subdirector | Nivel asignado (primaria o secundaria) | CRUD de secciones de su nivel, ver metricas de su nivel, gestionar profesores y tutores de su nivel |
| 3 | Tutor | Su seccion asignada | Ver progreso de sus alumnos, dejar tareas, ver batallas de su seccion, gestionar clanes de su seccion |
| 4 | Profesor | Secciones donde imparte su materia | Subir material, ver/editar banco de preguntas de su materia, dejar tareas, ver resultados de su materia en sus secciones |
| 5 | Alumno | Su perfil, su seccion, leaderboard | Jugar batallas, completar tareas, ver su progreso, ver leaderboard |

### 4.2 Logica jerarquica en codigo

El enum `Role` implementa:
- `hierarchy_level`: Retorna el nivel numerico (1 = mayor autoridad)
- `can_manage(other)`: Determina si un rol puede gestionar a otro (nivel menor gana)
- `label`: Etiqueta legible en espanol

### 4.3 Validacion de permisos

El sistema implementa RBAC (Role-Based Access Control) mediante:
- Middleware de autenticacion JWT que extrae el rol del token
- Decoradores/dependencias `require_role(Role.X, Role.Y, ...)` que validan acceso
- Funciones especificas: `require_director`, `require_teacher`
- Validacion de `school_match` para que un usuario solo gestione su propio colegio

### 4.4 Rol adicional: Coordinador Academico

Se contempla como posible adicion futura un rol de Coordinador Academico entre Subdirector y Tutor, con alcance sobre un area curricular especifica (ej: Coordinador de Ciencias). Este rol tendria acceso a los bancos de preguntas y metricas de todas las materias de su area.

---

## 5. SISTEMA DE RANGOS

### 5.1 Funcionamiento

El sistema de rangos es la columna vertebral de la progresion del alumno. Funciona de la siguiente manera:

1. Cada colegio define sus propios rangos (nombre, nivel, XP requerida, icono)
2. Un alumno acumula XP de dos formas:
   - Ganando batallas contra companeros
   - Completando tareas asignadas por profesores
3. Al alcanzar el XP requerido para el siguiente rango, el alumno sube automaticamente
4. Los rangos son visibles en el perfil del alumno y en los leaderboards

### 5.2 Ejemplo de escalera de rangos

| Nivel | Nombre | XP requerida |
|-------|--------|-------------|
| 1 | Novato | 0 |
| 2 | Aprendiz | 100 |
| 3 | Explorador | 300 |
| 4 | Guerrero | 600 |
| 5 | Campeon | 1000 |
| 6 | Maestro | 1500 |
| 7 | Leyenda | 2500 |

Los rangos son completamente configurables por el Director de cada colegio, pudiendo cambiar nombres, cantidades de XP e iconos.

### 5.3 Fuentes de XP

| Accion | XP base |
|--------|---------|
| Ganar batalla 1v1 | Variable (segun configuracion) |
| Completar tarea (multiple choice) | Configurable por tarea (default: 10) |
| Completar tarea (respuesta abierta) | Configurable por tarea |
| Completar tarea (subida de archivo) | Configurable por tarea |
| Robo exitoso de nodo | Bonus adicional |

---

## 6. SISTEMA DE CLANES

### 6.1 Concepto

Los clanes son agrupaciones de alumnos dentro de una misma seccion. Promueven la colaboracion y la identidad grupal.

### 6.2 Estructura

- Un clan pertenece a exactamente una seccion
- Un alumno puede pertenecer a un clan (opcional)
- Cada clan tiene un puntaje acumulado (suma de XP de sus miembros en batallas)
- Los clanes compiten entre si dentro de la misma seccion

### 6.3 Proposito

- Generar sentido de pertenencia
- Promover competencia saludable a nivel grupal
- El puntaje del clan se alimenta de las victorias individuales de sus miembros
- Leaderboard de clanes visible para toda la seccion

### 6.4 Configuracion

El Tutor o Director puede:
- Crear clanes dentro de una seccion
- Asignar alumnos a clanes
- Ver el ranking de clanes
- Los nombres de clanes son libres (ej: "Halcones", "Rayos", etc.)

---

## 7. BANCO DE PREGUNTAS E INTELIGENCIA ARTIFICIAL

### 7.1 Flujo completo de generacion de preguntas

**Actores involucrados:** Profesor (quien sube el material), Sistema (backend), Agente IA (LangChain/OpenAI)

**Precondiciones:**
- El profesor tiene una cuenta activa con rol PROFESSOR, TUTOR o superior
- El profesor esta asignado a al menos una materia y una seccion
- Existe un banco de preguntas creado para la materia del profesor en su colegio (si no existe, se crea automaticamente al solicitar la generacion)
- El profesor tiene al menos un archivo de material de clase listo para subir

**Flujo paso a paso:**

```
PASO 1: SUBIDA DE MATERIAL
  Actor: Profesor
  Accion: Selecciona un archivo de su dispositivo y lo sube al sistema
  Formatos aceptados: PDF, PPT, DOCX, IMG (futuro con OCR), TXT
  Sistema internamente:
    a) Recibe el archivo via endpoint POST /questions/banks/{bank_id}/upload
    b) Valida el formato del archivo (extension permitida)
    c) Valida el tamano del archivo (limite configurable, default sin limite)
    d) Genera un nombre unico para evitar colisiones (UUID + extension original)
    e) Almacena el archivo en ./storage/ (local) o MinIO (produccion)
    f) Retorna la ruta del archivo almacenado al frontend
  Error posible: Formato no soportado -> HTTP 400 con mensaje descriptivo
  Error posible: Archivo corrupto -> HTTP 500, se loguea el error
     |
     v
PASO 2: EXTRACCION DE TEXTO
  Actor: Sistema (automatico al solicitar generacion)
  El sistema recibe la ruta del archivo y ejecuta la extraccion:
    - PDF: Usa pypdf.PdfReader, extrae texto pagina por pagina, concatena con saltos de linea
    - DOCX: Usa python-docx.Document, extrae texto de cada parrafo
    - PPT: Usa python-pptx, extrae texto de cada slide y cada shape de texto
    - TXT: Lee directamente como UTF-8
    - IMG: (Futuro) Ejecutaria OCR con Pillow + pytesseract
  El texto extraido se almacena en memoria, no se persiste por separado
  Si el archivo no tiene texto legible, se retorna cadena vacia
  Error posible: Archivo no encontrado -> FileNotFoundError -> HTTP 404
  Error posible: Extension no soportada -> ValueError -> HTTP 400
     |
     v
PASO 3: GENERACION DE PREGUNTAS POR IA
  Actor: Agente IA
  El sistema envia el texto extraido al agente seleccionado:
    a) Si hay OPENAI_API_KEY configurada -> OpenAIQuestionAgent
       - Construye prompt: "Genera {count} preguntas de alternativa multiple
         basadas en el siguiente texto. Para cada pregunta devuelve un
         objeto JSON con: text, option_a, option_b, option_c, option_d,
         correct_option (A/B/C/D), explanation. Materia: {materia}.
         Responde unicamente con un array JSON."
       - Trunca el material a 4000 caracteres para optimizar tokens
       - Envia al modelo (default: gpt-4o-mini, temperature: 0.7)
       - La llamada a LangChain se ejecuta en un thread pool (asyncio.to_thread)
         para no bloquear el event loop
       - Recibe respuesta, parsea JSON (maneja code blocks ```json...```)
    b) Si NO hay API key -> MockQuestionAgent (fallback)
       - Genera preguntas deterministas basadas en 4 templates internos
       - Util para desarrollo y testing sin consumir tokens
  El agente retorna una lista de diccionarios, cada uno con:
    text, option_a, option_b, option_c, option_d, correct_option, explanation
  Error posible: API key invalida -> RuntimeError -> HTTP 500
  Error posible: Respuesta no parseable como JSON -> ValueError -> HTTP 500
  Error posible: Timeout de la API -> se reintenta o se cae al mock
     |
     v
PASO 4: PERSISTENCIA EN EL BANCO
  Actor: Sistema
  Por cada pregunta generada:
    a) Se crea una entidad Question con:
       - subject = materia del banco
       - school_id = colegio del banco
       - bank_id = banco que solicito la generacion
       - creator_id = UUID del profesor que solicito
       - is_approved = False (SIEMPRE inicia como no aprobada)
       - usage_count = 0
    b) Se persiste en batch via question_repo.create_many()
    c) Se actualiza el contador bank.total_generated += len(creadas)
    d) Se persiste la actualizacion del banco
  Postcondicion: Las preguntas existen en BD pero NO estan disponibles para batallas
     |
     v
PASO 5: REVISION POR EL PROFESOR
  Actor: Profesor
  El profesor accede a la lista de preguntas de su banco:
    - Endpoint: GET /questions/banks/{bank_id}/questions
    - Ve todas las preguntas (aprobadas y no aprobadas)
  Para cada pregunta, el profesor puede:
    a) APROBAR: POST /questions/{question_id}/approve
       - Sistema marca is_approved = True
       - Incrementa bank.total_approved += 1
       - La pregunta ahora es elegible para asignarse a nodos de batalla
    b) RECHAZAR: (futuro) La pregunta se marca como rechazada, no se cuenta
    c) EDITAR: (futuro) Modifica enunciado, opciones o respuesta correcta
       antes de aprobar
  Solo pueden aprobar: Profesor de la materia, Tutor, Subdirector, Director
     |
     v
PASO 6: USO EN BATALLAS
  Actor: Sistema (automatico al crear un grafo)
  Cuando se crea una batalla:
    a) Se obtienen todas las preguntas WHERE is_approved = True AND school_id = colegio
    b) Se agrupan por materia (subject)
    c) Para cada nodo del grafo se asignan 5 preguntas de la materia del nodo
    d) Las preguntas se rotan: no se repiten las mismas entre nodos del mismo grafo
    e) Se actualiza usage_count de cada pregunta asignada
    f) Si no hay suficientes preguntas aprobadas de una materia, se usan
       preguntas aprobadas de otras materias como relleno
```

**Postcondiciones del flujo completo:**
- El banco de la materia tiene N preguntas generadas (total_generated incrementado)
- Las preguntas aprobadas estan disponibles para cualquier batalla del colegio
- El profesor tiene visibilidad completa de su banco
- El material original queda almacenado para futuras regeneraciones

### 7.2 Procesamiento de documentos

El sistema soporta extraccion de texto de:

| Formato | Libreria | Consideraciones |
|---------|----------|-----------------|
| PDF | pypdf | Extraccion de texto por pagina |
| DOCX | python-docx | Extraccion de parrafos |
| TXT | nativo | Lectura directa UTF-8 |
| PPT | python-pptx | Extraccion de slides y texto |
| IMG | Pillow + OCR (futuro) | Requiere integracion con OCR |

El archivo se sube via endpoint `POST /questions/banks/{bank_id}/upload`, se almacena localmente en `./storage/` y se retorna la ruta.

### 7.3 Agente de IA

El sistema tiene dos implementaciones del agente de preguntas:

**OpenAIQuestionAgent (produccion):**
- Usa LangChain + ChatOpenAI
- Modelo configurable (default: gpt-4o-mini)
- Prompt especializado que solicita array JSON con preguntas
- Trunca el material a 4000 caracteres para optimizar tokens
- Parseo de respuesta JSON con manejo de code blocks
- Si no hay API key, cae al agente mock

**MockQuestionAgent (desarrollo/fallback):**
- Genera preguntas deterministas basadas en templates
- 4 templates basicos (matematica, sinonimos, capitales)
- Util para desarrollo y testing sin consumir tokens

### 7.4 Estrategia de ahorro de tokens

Para evitar generar preguntas repetidamente:
- Se crean 100 preguntas por materia en un solo batch
- Estas 100 preguntas se almacenan permanentemente en el banco
- Para cada nodo de batalla se asignan 5 preguntas del banco, rotando
- Las preguntas se reutilizan entre batallas
- Solo se generan nuevas preguntas cuando el profesor sube nuevo material
- El `usage_count` trackea cuantas veces se ha usado cada pregunta

### 7.5 Asignacion de preguntas a nodos

Cuando se crea un grafo de batalla, el sistema ejecuta el siguiente algoritmo de asignacion:

**Paso 1 -- Recoleccion:**
- Se consultan todas las preguntas del colegio: `question_repo.list_by_school(school_id)`
- Se filtran solo las aprobadas: `[q for q in questions if q.is_approved]`
- Si no hay ninguna aprobada (caso desarrollo), se usan TODAS las preguntas como fallback
- Si no hay preguntas en absoluto, los nodos quedan sin preguntas y la batalla puede jugarse pero sin retos (solo movimiento)

**Paso 2 -- Agrupacion por materia:**
- Se crea un diccionario `{subject_value: [list de Question]}`
- Ejemplo: `{"mathematics": [Q1, Q2, Q3...], "language": [Q5, Q6...]}`

**Paso 3 -- Asignacion por nodo:**
- Se recorre cada nodo del grafo en orden de capa y posicion
- Para el nodo actual con materia X:
  - Se busca el pool de preguntas de materia X
  - Si el pool tiene preguntas: se toman las primeras 3 (o hasta 5 si hay suficientes)
  - Si el pool de materia X esta vacio: se toman del pool general (todas las aprobadas)
  - Las preguntas asignadas se registran como `node.question_ids = [q.id for q in assigned]`
  - Se persiste la asignacion: `graph_repo.update_node_questions(node.id, node.question_ids)`

**Paso 4 -- Rotacion (futuro):**
- Para evitar que dos nodos de la misma materia tengan exactamente las mismas preguntas, se implementara un mecanismo de offset/rotacion que selecciona diferentes subconjuntos del pool
- Actualmente la seleccion es por los primeros N del pool; en futuro sera aleatorizada con seed por batalla

**Resultado:** Cada nodo tiene entre 3 y 5 preguntas asignadas. Las preguntas nunca se repiten entre nodos de la misma materia dentro del mismo grafo. Si una materia tiene pocas preguntas, multiples nodos de esa materia podrian compartir algunas (inevitable con bancos pequenos).

### 7.6 Panel de revision del profesor

El profesor de cada materia puede:
- Ver todas las preguntas generadas para su materia
- Aprobar preguntas individuales (`POST /questions/{id}/approve`)
- Editar preguntas antes de aprobarlas (futuro)
- Rechazar preguntas que no cumplan calidad
- Solicitar regeneracion de preguntas especificas (futuro)
- Solo el profesor de la materia y roles superiores ven el banco

### 7.7 Visibilidad del banco segun rol

| Rol | Que ve |
|-----|--------|
| Director | Todos los bancos de todas las materias |
| Subdirector | Bancos de su nivel educativo |
| Tutor | Bancos de las materias de su seccion |
| Profesor | Solo el banco de su materia |
| Alumno | No tiene acceso al banco |

---

## 8. GRAFOS DE BATALLA -- MECANICA COMPLETA

### 8.1 Estructura del grafo

Un grafo de batalla es un grafo aciclico dirigido (DAG) organizado en capas:

```
JUGADOR 1 (Capa 0)
  [M] [C] [F] [H]          <- 4 nodos, uno por materia
     \|/   |   |
  [F] [M] [C]              <- 3 nodos
     \|/   |
  [H] [M] [F] [C]          <- 4 nodos
     |   \|/
  [C] [F] [M]              <- 3 nodos
JUGADOR 2 (Capa N-1)

M = Matematica (rojo)
C = Comunicacion (azul)
F = Fisica (naranja)
H = Historia (dorado)
```

### 8.2 Parametros de configuracion

Al iniciar una batalla, los alumnos seleccionan:

| Parametro | Minimo | Maximo | Default |
|-----------|--------|--------|---------|
| Numero de capas | 4 | Configurable | 4 |
| Nodos minimos por capa | 3 | -- | 3 |
| Nodos maximos por capa | -- | 4 | 4 |

Dentro de cada capa, la cantidad exacta de nodos varia aleatoriamente entre el minimo y el maximo. Esto genera variedad en cada partida.

### 8.3 Algoritmo de construccion (GraphBuilder)

El `GraphBuilder` implementa el siguiente algoritmo:

**Paso 1 -- Generar nodos por capa:**
```
Para cada capa (0 a num_layers-1):
  - Determinar tamano aleatorio entre min_nodes y max_nodes
  - Para cada posicion en la capa:
    - Asignar materia usando round-robin: subjects[(layer + pos) % len(subjects)]
    - Asignar color segun la materia
    - Crear nodo
```

**Paso 2 -- Cablear capas (_wire_layers):**
```
Para cada capa desde la 1:
  - Para cada nodo de la capa actual:
    - Conectar a 1-2 nodos aleatorios de la capa anterior
```

**Paso 3 -- Forzar caminos (_ensure_forced_paths):**
```
Para cada capa desde la 1:
  - Verificar que cada nodo de la capa anterior conecte hacia adelante
  - Si un nodo anterior no tiene conexion forward, conectar a un nodo aleatorio de la capa actual
  - Verificar que cada nodo actual tenga predecesor
  - Si un nodo no tiene predecesor, conectar a un nodo aleatorio de la capa anterior
```

**Paso 4 -- Validacion:**
- El metodo `validate(graph)` verifica que:
  - Existen nodos en el grafo
  - Todos los nodos de cada capa tienen predecesor en la capa anterior
  - Todos los nodos de cada capa tienen sucesor en la capa siguiente
  - Esto garantiza al menos un camino completo de capa 0 a capa N-1

### 8.4 Colores de nodos

Cada nodo hereda el color de su materia asignada. Los colores predefinidos en la paleta mobile (app_theme.dart) son:

| Materia | Color | Hex |
|---------|-------|-----|
| Matematica | Rojo coral | #E63946 |
| Comunicacion | Naranja ambar | #F4A261 |
| Ciencia | Turquesa | #2A9D8F |
| Fisica | Azul oscuro | #264653 |
| Quimica | Terracota | #E76F51 |
| Biologia | Verde esmeralda | #06A77D |
| Historia | Violeta | #9B5DE5 |
| Geografia | Celeste | #00B4D8 |
| Ingles | Rosa intenso | #F15BB5 |
| Arte | Purpura | #8338EC |
| Civica | Azul brillante | #3A86FF |
| Ed. Fisica | Naranja fuego | #FB5607 |

### 8.5 Regla de conexion obligatoria

Un alumno NO puede saltar conexiones. Solo puede avanzar a nodos que esten directamente conectados a sus nodos conquistados:

- Si el nodo de Matematica (capa 1) esta conectado al nodo de Comunicacion (capa 2), el alumno puede ir
- Si en la capa 2 hay un nodo de Fisica que NO esta conectado al nodo de Matematica de la capa 1, el alumno NO puede ir a ese nodo
- Solo los nodos conectados se iluminan como "accesibles" en la interfaz

### 8.6 Rotacion de materias en nodos

Si el colegio tiene menos materias habilitadas que nodos en el grafo:
- Las materias se repiten usando round-robin
- Las PREGUNTAS nunca se repiten entre nodos de la misma materia
- Cada nodo tiene un set unico de 5 preguntas, aunque la materia se repita

---

## 9. BATALLAS -- FLUJO COMPLETO

### 9.1 Creacion de batalla

**Actores:** Alumno retador (J1), Sistema

**Precondiciones:**
- J1 tiene sesion activa y rol STUDENT
- J1 pertenece a un colegio con al menos un banco de preguntas aprobado
- El colegio tiene al menos 2 alumnos registrados

**Flujo detallado:**

```
PASO 1: SELECCION DE OPONENTE
  Actor: J1
  J1 abre la pantalla de batalla y ve la lista de posibles oponentes:
    - Companeros de su misma seccion (competencia interna)
    - Alumnos de otras secciones del mismo colegio (competencia inter-secciones)
  J1 selecciona al oponente (J2)
  Sistema valida:
    a) J2 existe y tiene rol STUDENT -> si no: error "User not found"
    b) J2 != J1 -> si son iguales: error "No puedes retarte a ti mismo"
    c) J2 esta activo -> si no: error "Usuario inactivo"
    d) J2 no esta en otra batalla activa (futuro, actualmente no validado)

PASO 2: CONFIGURACION DEL GRAFO
  Actor: J1 (o ambos jugadores en futuro)
  J1 selecciona los parametros del grafo:
    - Numero de capas: slider o selector (minimo 4)
    - Rango de nodos por capa: entre 3 y 4 (aleatorio dentro del rango)
  Las materias se determinan automaticamente segun las habilitadas en el colegio
  Si el colegio solo tiene 2 materias, los nodos alternaran entre esas 2

PASO 3: GENERACION DEL GRAFO
  Actor: Sistema
  El sistema ejecuta GraphBuilder.build() con la configuracion:
    a) Genera nodos capa por capa con cantidad aleatoria (3-4 por capa)
    b) Asigna materias via round-robin: subjects[(layer + pos) % len(subjects)]
    c) Asigna colores segun la materia
    d) Cablea conexiones entre capas adyacentes (1-2 conexiones por nodo)
    e) Ejecuta _ensure_forced_paths para garantizar que no hay dead-ends
    f) Persiste el grafo completo: graph_repo.create(graph)
  Error posible: No hay materias habilitadas -> usa Subject.MATH por defecto

PASO 4: ASIGNACION DE PREGUNTAS A NODOS
  Actor: Sistema
  Si J1 tiene school_id:
    a) Obtiene todas las preguntas aprobadas del colegio
    b) Agrupa por materia
    c) Para cada nodo: asigna 3-5 preguntas de su materia
    d) Persiste la asignacion: graph_repo.update_node_questions()
  Si no hay preguntas aprobadas: los nodos quedan sin preguntas (modo demo)

PASO 5: CREACION DE LA ENTIDAD BATALLA
  Actor: Sistema
  Se crea una entidad Battle con:
    - player_1_id = J1.id
    - player_2_id = J2.id
    - graph_id = grafo generado
    - status = PENDING
    - node_states = {node.id: BattleNodeState(libre) para cada nodo}
    - current_turn = 0
    - turn_timeout_seconds = 30
  Se persiste: battle_repo.create(battle)
  Se retorna la batalla con el grafo completo al frontend
  Endpoint: POST /api/v1/battles

PASO 6: NOTIFICACION AL OPONENTE
  Actor: Sistema
  (Futuro) J2 recibe una notificacion push o in-app de que fue retado
  (Actual) J2 ve la batalla pendiente al consultar GET /api/v1/battles/me
```

**Postcondicion:** Existe una batalla con estado PENDING, un grafo generado con nodos conectados y preguntas asignadas. Ambos jugadores pueden verla.

### 9.2 Inicio de batalla

**Actores:** J1 o J2 (cualquiera de los dos puede iniciar), Sistema

**Precondiciones:**
- La batalla existe con status = PENDING
- El jugador que solicita el inicio es participante de la batalla
- El grafo de la batalla existe y tiene nodos

**Flujo detallado:**

```
PASO 1: SOLICITUD DE INICIO
  Actor: Uno de los dos jugadores
  El jugador presiona "Iniciar batalla" en la interfaz
  Endpoint: POST /api/v1/battles/{battle_id}/start
  Sistema valida:
    a) La batalla existe -> si no: error 400 "Battle not found"
    b) La batalla esta en PENDING -> si no: error 400 "Battle is not pending"
    c) El solicitante es J1 o J2 -> si no: error 400 "Player is not part of this battle"

PASO 2: CARGA DEL GRAFO Y PREGUNTAS
  Actor: Sistema
  El sistema carga:
    a) El grafo completo con todos sus nodos: graph_repo.get_by_id(graph_id)
    b) Todas las preguntas referenciadas por los nodos: recorre node.question_ids,
       obtiene las preguntas via question_repo.list_by_ids()
    c) Construye un diccionario {question_id: Question} para acceso rapido
  Error posible: Grafo no encontrado -> error 400 "Graph not found"

PASO 3: INICIALIZACION DEL MOTOR DE BATALLA
  Actor: Sistema (BattleEngine)
  Se instancia BattleEngine(battle, graph, questions) y se ejecuta:
    a) engine._ensure_node_states(): crea un BattleNodeState para cada
       nodo del grafo (owner=None, attempt_count=0, best_time_ms=None)
    b) engine.start_battle():
       - Valida que battle.status == PENDING
       - Cambia status a IN_PROGRESS
       - Establece current_turn = 0 (J1 empieza)
    c) engine._set_initial_positions():
       - J1 se posiciona en el primer nodo de la capa 0
       - J2 se posiciona en el primer nodo de la ultima capa (N-1)
       - Las posiciones se guardan en battle.player_positions = {0: nodo_id, 1: nodo_id}
       - Los nodos iniciales NO se conquistan automaticamente, son posiciones de partida

PASO 4: PERSISTENCIA Y RESPUESTA
  Actor: Sistema
  a) Se actualiza la batalla en BD: battle_repo.update(battle)
  b) Se hace commit de la transaccion
  c) Se retorna el estado completo de la batalla incluyendo:
     - Estado de todos los nodos (todos libres)
     - Posiciones de ambos jugadores
     - Turno actual (0 = J1)
     - Timeout por turno

PASO 5: CONEXION WEBSOCKET (PARALELO)
  Actor: Ambos jugadores
  Ambos jugadores se conectan al WebSocket:
    ws://servidor/ws/battles/{battle_id}
  El servidor registra las conexiones en BattleConnectionManager
  Envia broadcast: {"type": "player_joined", ...}
  Cuando ambos estan conectados, la batalla comienza visualmente
```

**Postcondicion:** La batalla esta en IN_PROGRESS. Todos los nodos estan libres. J1 tiene el turno. Ambos jugadores estan conectados via WebSocket y ven el grafo.

### 9.3 Flujo de turno

**Actores:** Jugador en turno (J_activo), Sistema (BattleEngine), Jugador rival (J_rival, observa)

**Precondiciones:**
- La batalla esta en IN_PROGRESS
- Es el turno de J_activo (battle.current_turn == player_index de J_activo)
- El temporizador del turno no ha expirado

**Flujo detallado:**

```
PASO 1: VISUALIZACION DEL GRAFO
  Actor: J_activo (y J_rival que observa en tiempo real)
  El frontend renderiza el grafo con los siguientes estados visuales:
    - Nodos conquistados por J_activo: color del jugador (ej: rojo)
    - Nodos conquistados por J_rival: color del rival (ej: azul)
    - Nodos libres: gris neutro / transparente
    - Nodos ACCESIBLES (donde J_activo puede ir): iluminados con brillo o borde
      pulsante para indicar que son seleccionables
    - Nodos NO accesibles: atenuados, no responden al tap
  El calculo de nodos accesibles se hace con:
    graph.get_accessible_nodes(from_node_id, conquered_node_ids)
    Un nodo es accesible si alguna de sus conexiones (connected_to) apunta
    a un nodo conquistado por J_activo o a su posicion actual

PASO 2: SELECCION DE NODO
  Actor: J_activo
  J_activo toca/clickea un nodo accesible en el grafo
  Endpoint: POST /api/v1/battles/{battle_id}/select-node
  Sistema valida (BattleEngine.select_node):
    a) La batalla esta en IN_PROGRESS -> si no: error "Battle is not in progress"
    b) Es el turno de J_activo -> si no: error "Not your turn"
    c) El nodo existe en el grafo -> si no: error "Node not found"
    d) El nodo es accesible desde las conquistas de J_activo
       -> si no: error "Node is not accessible"
  Si la validacion pasa, se retorna el nodo seleccionado y se presenta una pregunta

PASO 3: PRESENTACION DE LA PREGUNTA
  Actor: Sistema -> J_activo
  El sistema selecciona una pregunta del pool del nodo (node.question_ids)
  Se envia al frontend SOLO:
    - text (enunciado)
    - option_a, option_b, option_c, option_d (las 4 alternativas)
  NUNCA se envia: correct_option ni explanation (seguridad anti-trampa)
  Se inicia un sub-temporizador para responder (dentro del turno)
  El frontend muestra la pregunta con las 4 opciones como botones

PASO 4: RESPUESTA DEL JUGADOR
  Actor: J_activo
  J_activo selecciona una opcion (A, B, C o D) y presiona "Responder"
  El frontend registra:
    - chosen_answer: la opcion seleccionada
    - response_time_ms: milisegundos desde que se mostro la pregunta
  Endpoint: POST /api/v1/battles/{battle_id}/answer
  Body: {node_id, question_id, chosen_answer, response_time_ms}

PASO 5: PROCESAMIENTO DE LA RESPUESTA
  Actor: Sistema (BattleEngine.answer_question)
  El motor ejecuta la siguiente logica interna:

    5a) VALIDACIONES PREVIAS:
      - La batalla esta en IN_PROGRESS
      - Es el turno correcto de quien responde
      - La pregunta existe en el sistema

    5b) VERIFICACION DE RESPUESTA:
      - question.check_answer(chosen_answer) -> compara con correct_option
      - Se incrementa state.attempt_count += 1
      - Si es correcta Y el tiempo es mejor que best_time_ms, se actualiza best_time_ms

    5c) CASO A -- NODO LIBRE (state.owner == None):
      Si la respuesta es CORRECTA:
        -> state.owner = player_index (J_activo conquista el nodo)
        -> node_conquered = True
        -> Mensaje: "Nodo conquistado"
      Si la respuesta es INCORRECTA:
        -> El nodo sigue libre (owner sigue None)
        -> node_conquered = False
        -> Mensaje: "Respuesta incorrecta"
        -> J_activo pierde el turno

    5d) CASO B -- NODO DEL RIVAL (state.owner == J_rival):
      Este es un INTENTO DE ROBO:
      Si la respuesta es CORRECTA Y response_time_ms <= state.best_time_ms:
        -> state.owner = player_index (J_activo ROBA el nodo)
        -> node_stolen = True
        -> Mensaje: "Nodo robado con mejor tiempo"
      Si la respuesta es CORRECTA PERO response_time_ms > state.best_time_ms:
        -> El nodo mantiene su dueno original
        -> La respuesta se marca como incorrecta a efectos del turno
        -> Mensaje: "Respuesta correcta pero tiempo insuficiente para robar"
      Si la respuesta es INCORRECTA:
        -> El nodo mantiene su dueno original
        -> Mensaje: "Respuesta incorrecta"

    5e) CASO C -- NODO PROPIO (state.owner == J_activo):
      Si J_activo intenta ir a un nodo que ya es suyo:
        -> No ocurre conquista ni robo
        -> node_conquered = False
        -> (En la practica el frontend no deberia permitir esto)

PASO 6: REGISTRO DEL MOVIMIENTO
  Actor: Sistema
  Se crea un BattleMove con todos los datos:
    battle_id, player_index, node_id, question_id, chosen_answer,
    is_correct, response_time_ms, is_steal_attempt, steal_successful
  Se persiste en la lista battle.moves y en BD via move_repo.create()

PASO 7: VERIFICACION DE VICTORIA
  Actor: Sistema (BattleEngine._check_victory)
  Se verifican dos condiciones en orden:
    a) VICTORIA POR BASE: J_activo conquisto el nodo inicial de J_rival?
       - Si J_activo es J1: verifica si nodo de capa N-1 tiene owner == 0
       - Si J_activo es J2: verifica si nodo de capa 0 tiene owner == 1
       - Si se cumple: winner_index = player_index de J_activo
    b) VICTORIA POR MAYORIA: J_activo controla la mayoria de nodos?
       - Mayoria = (total_nodos / 2) + 1
       - Se cuentan nodos de cada jugador
       - Si alguno alcanza la mayoria: winner_index = ese jugador
  Si hay ganador:
    - battle.status = FINISHED
    - battle.finished_at = now()
    - battle.winner_id = UUID del jugador ganador
    - Se calcula XP para el ganador (futuro)
  Si NO hay ganador:
    -> Se procede al cambio de turno

PASO 8: CAMBIO DE TURNO
  Actor: Sistema
  battle.current_turn = 1 - battle.current_turn (alterna entre 0 y 1)
  Se persiste el estado actualizado: battle_repo.update(battle)
  Se envia via WebSocket a ambos jugadores:
    {"event": "turn_change", "current_player": "player_X", "turn_timeout": 30}
  El temporizador del nuevo turno comienza para J_rival (que ahora es J_activo)
  El ciclo vuelve al PASO 1 para el nuevo jugador en turno

PASO 9: RESPUESTA AL FRONTEND
  Actor: Sistema -> J_activo
  Se retorna un AnswerResult con:
    is_correct, node_conquered, node_stolen, battle_finished,
    winner_id (si aplica), current_turn, message
  El frontend ejecuta la animacion correspondiente:
    - Conquista: nodo cambia de color con animacion de pulso
    - Robo: nodo cambia de color con efecto de shake
    - Respuesta incorrecta: nodo parpadea en rojo brevemente
    - Victoria: pantalla de celebracion retro con particulas
```

**Postcondicion por turno:** Un nodo cambio de estado (o no si la respuesta fue incorrecta), se registro un movimiento, el turno cambio al otro jugador, y se verifico si hay ganador.

### 9.4 Mecanica de robo de nodos -- Detalle

El robo es una de las mecanicas mas importantes y es lo que separa a BattleGraph de un quiz convencional. Introduce una capa de estrategia temporal ademas de la estrategia espacial del grafo.

**Cuando ocurre un robo:**
- Un jugador en su turno selecciona un nodo que ya fue conquistado por el rival
- El sistema detecta que `state.owner != None` y `state.owner != player_index`
- Se activa la mecanica de robo automaticamente (no hay confirmacion adicional)

**Flujo interno del robo:**
```
1. J_activo selecciona nodo N que tiene owner = J_rival
2. Se presenta una pregunta del pool del nodo N
3. J_activo responde y se mide response_time_ms
4. El motor verifica:
   a) La respuesta es correcta? -> question.check_answer(chosen_answer)
   b) Si es INCORRECTA:
      - is_steal_attempt = True, steal_successful = False
      - J_activo pierde el turno
      - El nodo sigue perteneciendo a J_rival
      - FIN del intento de robo
   c) Si es CORRECTA:
      - Se compara response_time_ms con state.best_time_ms del nodo
      - Si response_time_ms <= best_time_ms:
        -> ROBO EXITOSO
        -> state.owner cambia a J_activo
        -> state.best_time_ms se actualiza al nuevo tiempo
        -> steal_successful = True
      - Si response_time_ms > best_time_ms:
        -> ROBO FALLIDO (respondio bien pero muy lento)
        -> El nodo sigue perteneciendo a J_rival
        -> La respuesta se marca como "incorrecta" a efectos del turno
        -> steal_successful = False
```

**Implicaciones estrategicas:**
- Un jugador que conquista un nodo rapido (ej: 3 segundos) crea un nodo muy dificil de robar
- Un jugador que conquista lento (ej: 25 segundos) deja el nodo vulnerable
- Esto incentiva responder RAPIDO, no solo correctamente
- Un nodo puede ser robado multiples veces durante una batalla
- Cada robo exitoso actualiza el best_time_ms, haciendo el nodo cada vez mas dificil de re-robar
- El defensor NO participa activamente en el robo; la defensa es pasiva basada en su tiempo previo

**Consideracion de latencia:**
- El response_time_ms debe medirse en el SERVIDOR, no en el cliente
- Esto evita que diferencias de latencia entre jugadores afecten la justicia del robo
- El timestamp del servidor al recibir la solicitud menos el timestamp al enviar la pregunta = tiempo real

### 9.5 Condiciones de victoria

El BattleEngine verifica victoria de dos maneras, evaluadas en orden despues de CADA movimiento:

**1. Victoria primaria -- Alcanzar la base rival:**
- J1 (que empezo en capa 0) gana si conquista algun nodo de la capa N-1 (base de J2)
- J2 (que empezo en capa N-1) gana si conquista algun nodo de la capa 0 (base de J1)
- Para llegar a la base rival, el jugador debe haber conquistado un camino completo
  a traves de todas las capas intermedias, respetando las conexiones del grafo
- Esta es la forma principal y mas satisfactoria de ganar

**2. Victoria por mayoria -- Dominar el mapa:**
- Si un jugador controla la mayoria absoluta de nodos del grafo, gana automaticamente
- Mayoria = (total_nodos / 2) + 1
- Ejemplo con grafo de 14 nodos: necesita 8 nodos para ganar por mayoria
- Esta condicion previene partidas infinitas donde ambos jugadores se bloquean mutuamente
- Se verifica DESPUES de la condicion de base rival

**Condicion de empate (pendiente de implementacion):**
- Actualmente no se implementa empate explicito
- Un empate podria ocurrir si: ambos jugadores no pueden avanzar y los nodos estan
  distribuidos exactamente 50-50 (imposible con numero impar de nodos)
- Solucion propuesta: si pasan N turnos sin conquistas, la batalla entra en "muerte subita"
  donde el proximo en conquistar cualquier nodo gana

**Flujo post-victoria:**
```
1. BattleEngine detecta winner_index != None
2. battle.status = FINISHED
3. battle.finished_at = datetime.now(UTC)
4. battle.winner_id = UUID del jugador ganador
5. Se persiste en BD
6. Se envia via WebSocket: {"event": "battle_end", "winner": ..., "reason": ..., "stats": ...}
7. El frontend muestra la pantalla de resultados con:
   - Ganador y perdedor
   - Nodos conquistados por cada jugador
   - Tiempo promedio de respuesta
   - Preguntas acertadas / falladas
   - XP ganada (futuro)
   - Cambio de rango si aplica (futuro)
8. Ambos jugadores pueden volver al lobby
```

### 9.6 Resultado de un movimiento (AnswerResult)

Cada respuesta retorna un objeto AnswerResult con toda la informacion necesaria para que el frontend actualice la interfaz sin hacer consultas adicionales:

| Campo | Tipo | Descripcion |
|-------|------|-------------|
| is_correct | Boolean | Si la respuesta fue correcta (False tambien si fue robo fallido por tiempo) |
| node_conquered | Boolean | Si se conquisto un nodo que estaba libre |
| node_stolen | Boolean | Si se robo exitosamente un nodo del rival |
| battle_finished | Boolean | Si la batalla termino con este movimiento |
| winner_index | Integer (nullable) | 0 o 1 si hay ganador, None si la batalla continua |
| current_turn | Integer | Turno actual DESPUES del movimiento (ya alternado) |
| message | String | Mensaje descriptivo: "Nodo conquistado", "Nodo robado con mejor tiempo", "Respuesta incorrecta" |

**Mensajes posibles del motor:**
- "Respuesta incorrecta" -- La respuesta no coincidio con correct_option
- "Nodo conquistado" -- Se conquisto un nodo libre exitosamente
- "Nodo robado con mejor tiempo" -- Se robo un nodo del rival
- "Respuesta correcta" -- Correcta pero sin efecto (nodo propio o robo fallido)

### 9.7 Temporizador

**Configuracion:**
- Cada turno tiene un tiempo limite configurable (default: 30 segundos)
- El timeout se almacena en `battle.turn_timeout_seconds`
- Puede configurarse al crear la batalla (futuro)

**Flujo del temporizador:**
```
1. Al cambiar de turno, el servidor envia via WebSocket:
   {"event": "turn_change", "current_player": "player_X", "turn_timeout": 30}
2. El frontend inicia una cuenta regresiva visual (animada estilo retro)
3. El servidor tambien lleva un timer interno (server-side truth)
4. Si el tiempo se agota:
   a) El servidor detecta timeout
   b) Se ejecuta un auto-skip: el jugador pierde el turno sin realizar accion
   c) Se cambia el turno automaticamente
   d) Se notifica via WebSocket: {"event": "turn_timeout", "player": "player_X"}
   e) El frontend muestra brevemente "Tiempo agotado" y pasa al siguiente turno
5. Si el jugador responde antes del timeout:
   - El timer se cancela
   - Se procesa la respuesta normalmente
```

**Consideracion de desconexion:**
```
- Si un jugador se desconecta del WebSocket a media batalla:
  1. El servidor detecta WebSocketDisconnect
  2. Envia broadcast: {"type": "player_left", ...}
  3. Se inicia un timer de reconexion de 60 segundos
  4. Si el jugador reconecta antes de 60s:
     - Recibe el estado actual completo de la batalla
     - La partida continua normalmente
  5. Si NO reconecta en 60s:
     - battle.status = PAUSED
     - (Futuro) Se puede cancelar o declarar victoria al jugador presente
  6. Si AMBOS se desconectan:
     - La batalla queda en PAUSED
     - Se puede reanudar si ambos reconectan dentro de 5 minutos
     - Pasados 5 minutos, la batalla se cancella automaticamente (status = CANCELLED)
```

### 9.8 Flujo de fin de batalla y recompensas

**Flujo post-batalla (futuro, diseñado):**
```
1. La batalla termina (status = FINISHED)
2. El sistema calcula recompensas:
   a) Ganador:
      - Recibe XP base por victoria (configurable por colegio)
      - Bonus XP por cada nodo conquistado
      - Bonus XP por cada robo exitoso
      - Se actualiza user.xp via user.add_xp(total_xp)
   b) Perdedor:
      - Recibe XP reducida por participacion (ej: 25% de la base)
      - No pierde XP (la progresion nunca retrocede)
3. Se verifica progresion de rango:
   - Se consultan los rangos del colegio ordenados por xp_required
   - Si user.xp >= siguiente_rango.xp_required:
     -> user.rank_id = siguiente_rango.id
     -> Se notifica al alumno: "Subiste al rango [nombre]!"
4. Se actualiza puntaje del clan (si aplica):
   - clan.total_score += xp_ganada_por_miembro
5. Se registran estadisticas de la batalla para el dashboard:
   - Materias con mas aciertos / errores
   - Tiempo promedio de respuesta por materia
   - Nodos que cambiaron de mano (robos)
6. Los datos quedan disponibles para consulta del profesor y director
```

---

## 10. SISTEMA DE TAREAS

### 10.1 Proposito

Las tareas son la alternativa a las batallas para que un alumno pueda subir de rango. Un profesor deja una tarea asignada a una seccion y los alumnos la completan para ganar XP.

### 10.2 Tipos de tarea

| Tipo | Descripcion | Evaluacion |
|------|-------------|------------|
| multiple_choice | Preguntas de alternativas (similar a batallas) | Automatica por el sistema |
| open_answer | Respuesta abierta (texto) | Manual por el profesor |
| file_upload | Subida de documento (PDF, DOCX, etc.) | Manual por el profesor |

### 10.3 Flujo

**Actores:** Profesor (crea y califica), Alumno (completa y entrega), Sistema (evalua automatico en multiple_choice)

**Flujo detallado:**

```
PASO 1: CREACION DE LA TAREA
  Actor: Profesor
  El profesor accede a la seccion de tareas de su materia
  Completa el formulario de nueva tarea:
    - titulo: nombre descriptivo (ej: "Practica de fracciones - Semana 3")
    - description: instrucciones detalladas para el alumno
    - task_type: selecciona uno de los tres tipos (multiple_choice, open_answer, file_upload)
    - section_id: selecciona la seccion destino (de las que tiene asignadas)
    - subject: se asigna automaticamente segun la materia del profesor
    - due_date: fecha y hora limite de entrega (opcional, puede ser sin fecha)
    - xp_reward: cuantos XP otorga completar esta tarea (default: 10)
    - material adjunto (opcional): PDF o documento de referencia para la tarea
  Endpoint: POST /api/v1/tasks
  Sistema valida:
    a) El profesor tiene rol PROFESSOR, TUTOR o superior
    b) La seccion existe y pertenece al colegio del profesor
    c) El tipo de tarea es valido
  Se persiste la tarea en BD
  Postcondicion: La tarea esta visible para todos los alumnos de la seccion

PASO 2: VISUALIZACION POR EL ALUMNO
  Actor: Alumno
  El alumno accede a su lista de tareas pendientes:
    - Endpoint: GET /api/v1/tasks (filtrado por section_id del alumno)
    - Ve: titulo, descripcion, tipo, fecha limite, XP que otorga
    - Las tareas se muestran ordenadas por fecha limite (las mas proximas primero)
    - Las tareas vencidas se marcan visualmente pero siguen siendo entregables
      (depende de la configuracion del colegio si se aceptan entregas tardias)
  El alumno selecciona una tarea para completarla

PASO 3: COMPLETADO Y ENTREGA
  Actor: Alumno
  Segun el tipo de tarea:

    CASO A -- multiple_choice:
      - El sistema presenta las preguntas de la tarea (tomadas del banco)
      - El alumno responde cada pregunta seleccionando A, B, C o D
      - Al terminar presiona "Entregar"
      - Se crea un TaskSubmission con:
        answer = JSON con las respuestas {"q1": "A", "q2": "C", ...}
      - Evaluacion: AUTOMATICA por el sistema
        -> Se comparan respuestas con correct_option de cada pregunta
        -> Se calcula score = (correctas / total) * 100
        -> is_graded = True (inmediato)
        -> XP se otorga proporcionalmente al score

    CASO B -- open_answer:
      - El alumno ve la descripcion/instrucciones de la tarea
      - Escribe su respuesta en un campo de texto largo
      - Puede incluir formato basico (futuro: markdown)
      - Al terminar presiona "Entregar"
      - Se crea un TaskSubmission con:
        answer = texto de la respuesta
      - Evaluacion: MANUAL por el profesor
        -> is_graded = False (queda pendiente)
        -> El profesor vera la entrega en su panel de tareas por calificar

    CASO C -- file_upload:
      - El alumno ve las instrucciones y sube un archivo (PDF, DOCX, IMG)
      - El archivo se almacena via LocalStorageService o MinIO
      - Se crea un TaskSubmission con:
        file_url = ruta del archivo subido
        answer = "" (vacia, el contenido esta en el archivo)
      - Evaluacion: MANUAL por el profesor
        -> is_graded = False (queda pendiente)
        -> El profesor descarga y revisa el archivo

  Endpoint: POST /api/v1/tasks/{task_id}/submit
  Sistema valida:
    a) La tarea existe
    b) El alumno pertenece a la seccion destino de la tarea
    c) El alumno no ha entregado ya esta tarea (o se permite re-entrega segun config)

PASO 4: CALIFICACION
  Actor: Profesor (para open_answer y file_upload) o Sistema (para multiple_choice)

  Para tareas de calificacion manual:
    - El profesor accede a su panel de entregas pendientes
    - Ve la lista de alumnos que entregaron, con sus respuestas/archivos
    - Para cada entrega:
      a) Lee la respuesta o descarga el archivo
      b) Asigna un score (0-100)
      c) Opcionalmente agrega retroalimentacion escrita (futuro)
      d) Marca como calificada: is_graded = True
    - Endpoint: PUT /api/v1/tasks/{task_id}/submissions/{submission_id}/grade

PASO 5: OTORGAMIENTO DE XP
  Actor: Sistema (automatico al calificar)
  Al marcar una entrega como calificada:
    a) Se calcula XP: task.xp_reward * (submission.score / 100)
       Ejemplo: tarea de 10 XP, alumno obtuvo 80/100 -> recibe 8 XP
    b) Se ejecuta user.add_xp(xp_calculada)
    c) Se verifica si el alumno sube de rango (misma logica que post-batalla)
    d) Se actualiza puntaje del clan si aplica
  El alumno ve en su perfil el XP ganado y su nuevo rango si cambio
```

**Postcondicion:** La tarea esta completada y calificada. El alumno recibio XP proporcional a su desempeno. Su progresion de rango se actualizo.

### 10.4 Datos de entrega

Cada entrega (TaskSubmission) registra los siguientes datos con su proposito:

| Dato | Proposito |
|------|-----------|
| task_id | Vincular la entrega con la tarea original |
| student_id | Identificar que alumno entrego |
| answer | Texto de la respuesta (para multiple_choice y open_answer) |
| file_url | Ruta del archivo subido (para file_upload) |
| is_graded | Indica si el profesor ya reviso y califico esta entrega |
| score | Puntaje asignado por el profesor o el sistema (0-100) |
| submitted_at | Timestamp de cuando el alumno envio la entrega (para detectar entregas tardias) |

---

## 11. CONFIGURACION INICIAL DEL COLEGIO

### 11.1 Flujo de onboarding completo

Este es el proceso paso a paso para configurar un colegio nuevo desde cero. Cada paso incluye el actor responsable, las acciones del sistema y las validaciones que ocurren internamente.

```
PASO 1: REGISTRO DEL DIRECTOR Y CREACION DEL COLEGIO
  Actor: Director (primera persona del colegio en usar el sistema)
  Pantalla: Formulario de registro publico
  El Director completa:
    - username: nombre de usuario unico para login
    - email: correo electronico institucional
    - password: contrasena (se hashea con bcrypt antes de almacenar)
    - full_name: nombre completo del Director
    - school_name: nombre oficial del colegio
    - region: ubicacion geografica (ciudad, departamento)
  Endpoint: POST /api/v1/auth/register/director
  Sistema internamente:
    a) Verifica que el username no exista -> si existe: error 400 "El nombre de usuario ya existe"
    b) Crea la entidad School con nombre y region (level = "both" por defecto)
    c) Persiste el colegio: school_repo.create(school)
    d) Crea la entidad User con rol = DIRECTOR y school_id = colegio recien creado
    e) Hashea la contrasena con bcrypt
    f) Persiste el usuario: user_repo.create(user)
    g) Hace commit de la transaccion (ambos se crean atomicamente)
    h) Retorna datos del usuario creado (sin contrasena, con school_id)
  Postcondicion: El Director tiene cuenta activa, el colegio existe, puede hacer login
  Siguiente accion: El Director hace login (POST /api/v1/auth/login) y recibe JWT

PASO 2: CREACION DE SECCIONES (AULAS)
  Actor: Director (logueado con JWT)
  Pantalla: Panel de administracion > Secciones
  El Director lista todas las aulas fisicas de su colegio y las crea:
    Ejemplo de secciones para un colegio con 3 aulas:
      - {name: "5to Primaria - Seccion A", grade: 5, level: "primary"}
      - {name: "6to Primaria - Seccion A", grade: 6, level: "primary"}
      - {name: "6to Primaria - Seccion B", grade: 6, level: "primary"}
  Puede crear multiples secciones en una sola solicitud (batch):
    Endpoint: POST /api/v1/schools/{school_id}/sections
    Body: {sections: [{name, grade, level, tutor_id?}, ...]}
  Sistema internamente:
    a) Por cada seccion en el array:
       - Crea entidad Section con school_id del colegio del Director
       - Asigna tutor_id si fue proporcionado (puede ser null inicialmente)
       - Persiste: section_repo.create(section)
    b) Commit atomico de todas las secciones
    c) Retorna array con las secciones creadas (IDs incluidos)
  Validacion de roles: Solo Director, Subdirector o Tutor pueden crear secciones
  Postcondicion: Las secciones existen y estan listas para recibir alumnos

PASO 3: CREACION DE PERSONAL DOCENTE
  Actor: Director
  Pantalla: Panel de administracion > Personal
  El Director crea cuentas para cada profesor y tutor del colegio:
    Para cada docente proporciona:
      - username: unico en el sistema
      - email: correo del docente
      - password: contrasena inicial (el docente la cambiara despues)
      - full_name: nombre completo
      - role: "professor" o "tutor"
      - school_id: se asigna automaticamente al colegio del Director
      - section_id: (para tutores) la seccion que tutela
  Endpoint: POST /api/v1/users/staff
  Sistema valida:
    a) El username no existe previamente
    b) El rol es valido (solo professor o tutor permitidos en este endpoint)
    c) El Director tiene school_id (se usa ese si no se proporciona explicitamente)
  Sistema internamente:
    - Hashea contrasena con bcrypt
    - Crea entidad User con todos los datos
    - Persiste y retorna el usuario creado
  Para Subdirectores: se usa el endpoint general POST /api/v1/users con rol "subdirector"
  Postcondicion: Los profesores y tutores tienen cuenta y pueden hacer login

PASO 4: ASIGNACION DE TUTORES A SECCIONES
  Actor: Director
  Si no se asigno tutor al crear la seccion, se actualiza despues:
    - El Director selecciona una seccion y le asigna un tutor
    - Un tutor puede tutorear una o mas secciones
    - El tutor tendra acceso al progreso de los alumnos de sus secciones
  Actualmente: el tutor_id se asigna en la creacion de la seccion
  Futuro: endpoint dedicado PUT /api/v1/sections/{section_id}/tutor
  Postcondicion: Cada seccion tiene un tutor responsable

PASO 5: CONFIGURACION DE MATERIAS HABILITADAS
  Actor: Director
  El Director selecciona cuales de las 12 materias disponibles estan activas
  en su colegio. Ejemplo: un colegio de primaria podria habilitar solo:
    - Matematica, Comunicacion, Ciencia y Tecnologia, Historia, Ingles
  Las materias habilitadas determinan:
    - Que colores de nodos aparecen en los grafos de batalla
    - Para que materias se pueden crear bancos de preguntas
    - Que nodos se generan en los grafos
  Actualmente: se usan todas las materias del enum Subject por defecto
  Futuro: tabla school_subjects para habilitar/deshabilitar por colegio
  Postcondicion: Las materias del colegio estan definidas

PASO 6: CREACION DE PERFILES DE ALUMNOS
  Actor: Director, Subdirector o Tutor
  Tres opciones disponibles:

    OPCION A -- Creacion individual:
      Endpoint: POST /api/v1/users
      Body: {username, email, password, full_name, role: "student",
             school_id, section_id}
      Util para agregar alumnos nuevos durante el periodo

    OPCION B -- Carga masiva JSON:
      Endpoint: POST /api/v1/schools/{school_id}/students/bulk
      Body: {section_id, students: [{username, full_name, password, email?}, ...]}
      El sistema por cada alumno:
        - Genera email como {username}@battlegraf.local si no se proporciona
        - Hashea contrasena, asigna role STUDENT, school_id y section_id
      Retorna: {created: N}

    OPCION C -- Carga masiva CSV (recomendada para colegios grandes):
      Endpoint: POST /api/v1/users/{school_id}/students/csv
      Parametros: school_id (path), section_id (query), file (multipart)
      Formato CSV requerido: encabezados username,full_name,password
      Campo opcional en CSV: email
      El sistema procesa fila por fila:
        a) Lee como UTF-8 con soporte BOM (utf-8-sig)
        b) Valida que los encabezados requeridos existan
        c) Por cada fila:
           - Valida que username, full_name y password no esten vacios
           - Verifica que el username no exista previamente
           - Si existe: agrega a lista de errores con detalle
           - Si no existe: hashea password, crea User, persiste
        d) Commit atomico de todos los alumnos creados
        e) Retorna: {created: N, errors: [{row: X, detail: "..."}, ...], section_id}
      Ejemplo de respuesta con errores parciales:
        {created: 28, errors: [{row: 3, detail: "Campos vacios"},
                               {row: 15, detail: "Usuario 'jperez' ya existe"}],
         section_id: "uuid"}
  Postcondicion: Todos los alumnos tienen cuenta, estan asignados a sus secciones
  y pueden hacer login

PASO 7: CONFIGURACION DE RANGOS
  Actor: Director
  El Director define la escalera de rangos de su colegio:
    - Para cada rango especifica: nombre, nivel numerico, XP requerida, icono (URL)
    - Los rangos se ordenan por xp_required ascendente
    - El primer rango (XP = 0) se asigna automaticamente a todos los alumnos nuevos
  Ejemplo de configuracion:
    Nivel 1: "Novato" (0 XP) - icono: novato.png
    Nivel 2: "Aprendiz" (100 XP) - icono: aprendiz.png
    Nivel 3: "Explorador" (300 XP) - icono: explorador.png
    ...etc
  Futuro: Endpoint CRUD para rangos
  Postcondicion: La escalera de progresion esta definida para el colegio

PASO 8: CREACION DE CLANES (OPCIONAL)
  Actor: Tutor o Director
  Dentro de cada seccion, se pueden crear clanes para agrupar alumnos:
    - Nombre del clan (libre, ej: "Halcones", "Rayos", "Lobos")
    - Se asignan alumnos a cada clan
    - Un alumno puede pertenecer a maximo 1 clan
    - Los clanes compiten entre si dentro de la seccion
  Futuro: Endpoint CRUD para clanes y asignacion de miembros
  Postcondicion: Los clanes estan creados con sus miembros asignados

PASO 9: SUBIDA DE MATERIAL Y GENERACION DE PREGUNTAS
  Actor: Cada profesor de cada materia
  Este paso se repite por cada materia habilitada:
    a) El profesor sube al menos un archivo de material de clase:
       Endpoint: POST /api/v1/questions/banks/{bank_id}/upload
       (Si no existe banco para su materia, primero se crea:
        POST /api/v1/questions/banks con school_id y subject)
    b) Solicita generacion de preguntas:
       Endpoint: POST /api/v1/questions/banks/{bank_id}/generate
       Body: {file_path: "ruta del material", count: 100}
    c) El agente IA genera 100 preguntas de alternativa multiple
    d) El profesor revisa cada pregunta en su panel:
       Endpoint: GET /api/v1/questions/banks/{bank_id}/questions
    e) Aprueba las preguntas de calidad:
       Endpoint: POST /api/v1/questions/{question_id}/approve
    f) Rechaza o ignora las que no sirven
  Postcondicion: Hay preguntas aprobadas en el banco, listas para batallas
  Nota: Este paso puede hacerse gradualmente, no es necesario completarlo
  antes de que los alumnos puedan usar el sistema (pero sin preguntas
  aprobadas las batallas no tendran retos)

PASO 10: SISTEMA OPERATIVO
  Postcondicion general: El colegio esta completamente configurado
  Los alumnos pueden:
    - Hacer login con sus credenciales
    - Ver su perfil (rango, XP, clan, seccion)
    - Iniciar batallas contra companeros
    - Completar tareas dejadas por profesores
    - Ver el leaderboard de su seccion
  Los profesores pueden:
    - Subir nuevo material en cualquier momento
    - Generar mas preguntas
    - Crear tareas para sus secciones
    - Ver el progreso de sus alumnos
  El Director puede:
    - Ver metricas globales del colegio
    - Agregar nuevas secciones o alumnos en cualquier momento
    - Modificar la configuracion de rangos
```

### 11.2 Carga masiva de alumnos via CSV

**Actor:** Director, Subdirector o Tutor

**Precondiciones:**
- La seccion destino existe y pertenece al colegio del actor
- El actor tiene permiso (Director, Subdirector o Tutor)
- El archivo CSV esta en formato UTF-8

**Campos del CSV:**

| Campo | Obligatorio | Descripcion |
|-------|-------------|-------------|
| username | Si | Nombre de usuario unico para login |
| full_name | Si | Nombre completo del alumno |
| password | Si | Contrasena inicial (se hashea con bcrypt) |
| email | No | Si no se provee, se genera como `{username}@battlegraf.local` |

**Procesamiento interno paso a paso:**
```
1. El sistema recibe el archivo via multipart upload
2. Lee el contenido como UTF-8 con soporte BOM (utf-8-sig)
   -> Si falla la decodificacion: error 400 "El archivo CSV debe ser UTF-8"
3. Parsea los encabezados con csv.DictReader
   -> Si faltan encabezados requeridos (username, full_name, password):
      error 400 "CSV invalido. Encabezados requeridos: username,full_name,password"
4. Itera por cada fila (row) del CSV:
   a) Extrae y limpia (strip) los campos: username, full_name, password, email
   b) Valida que username, full_name y password no esten vacios
      -> Si estan vacios: agrega error {row: N, detail: "Campos vacios"}, salta a siguiente fila
   c) Verifica que el username no exista ya en la BD
      -> Si existe: agrega error {row: N, detail: "Usuario 'X' ya existe"}, salta a siguiente fila
   d) Si pasa todas las validaciones:
      - Hashea la contrasena con bcrypt
      - Crea entidad User con:
        role = STUDENT
        school_id = del path parameter
        section_id = del query parameter
        email = proporcionado o generado automaticamente
      - Persiste via user_repo.create()
      - Incrementa contador created_count
5. Commit atomico de todos los usuarios creados
6. Retorna respuesta JSON:
   {"created": 28, "errors": [{"row": 3, "detail": "..."}, ...], "section_id": "uuid"}
```

**Nota importante:** Los errores en filas individuales no impiden la creacion de los demas alumnos. El sistema procesa todas las filas y reporta exitos y errores por separado.

---

## 12. ARQUITECTURA TECNICA

### 12.1 Patron arquitectonico

Clean Architecture con MVC como patron de presentacion. Principios SOLID aplicados en todas las capas.

```
PRESENTACION (MVC)
  - Model (estado)
  - View (Flutter widgets)
  - Controller (logica de UI, FastAPI routes)
          |
APLICACION (Casos de Uso)
  - CreateSchool, StartBattle, GenerateQuestions
  - Orquestan logica de negocio pura
          |
DOMINIO (Entidades + Reglas de Negocio)
  - School, Section, User, Battle, Graph, Question
  - Value Objects, Enums
  - Interfaces abstractas (ports)
          |
INFRAESTRUCTURA (Adaptadores)
  - Database (PostgreSQL/SQLite via SQLAlchemy)
  - Cache (Redis)
  - IA Agent (LangChain + OpenAI)
  - File Storage (MinIO / Local)
  - Auth (JWT + bcrypt)
```

### 12.2 Stack tecnologico

**Backend:**

| Componente | Tecnologia | Version |
|-----------|-----------|---------|
| Lenguaje | Python | 3.11+ |
| Framework API | FastAPI | 0.110+ |
| ORM | SQLAlchemy 2.0 (async) | 2.0.25+ |
| Base de datos principal | PostgreSQL | 16 |
| Base de datos desarrollo | SQLite + aiosqlite | -- |
| Cache / Pub-Sub | Redis | 7 |
| Autenticacion | JWT (python-jose) + bcrypt | -- |
| Cola de tareas | Celery + Redis | 5.3.6+ |
| Agente IA | LangChain + OpenAI | 0.1+ |
| Almacenamiento archivos | MinIO (S3-compatible) / Local | -- |
| Testing | Pytest + pytest-asyncio | 8.0+ |
| Linting | Ruff + Black + MyPy | -- |
| CI/CD | GitHub Actions | -- |

**Frontend Mobile:**

| Componente | Tecnologia | Version |
|-----------|-----------|---------|
| Framework | Flutter | 3.x |
| State Management | Riverpod | 2.x |
| Routing | GoRouter | -- |
| Graficos | CustomPainter + Flame | -- |
| HTTP Client | Dio | -- |
| Almacenamiento local | Hive / Isar | -- |

### 12.3 Contenedores Docker

El `docker-compose.yml` define 4 servicios:

| Servicio | Imagen | Puerto | Proposito |
|----------|--------|--------|-----------|
| postgres | postgres:16-alpine | 5432 | Base de datos principal |
| redis | redis:7-alpine | 6379 | Cache, pub/sub, broker Celery |
| minio | minio/minio:latest | 9000/9001 | Almacenamiento de archivos S3-compatible |
| celery_worker | custom (Dockerfile) | -- | Worker para tareas async (IA) |

### 12.4 Casos de uso implementados

**School:**
- `CreateSchool`: Crear un colegio nuevo
- `ConfigureSections`: Configurar secciones de un colegio

**Battle:**
- `CreateBattle`: Crear batalla pendiente entre dos jugadores
- `StartBattle`: Iniciar una batalla pendiente
- `SubmitAnswer`: Procesar respuesta de un jugador
- `GetBattle`: Obtener estado de una batalla

**Question Bank:**
- `CreateQuestionBank`: Crear banco para materia/colegio
- `UploadMaterial`: Subir material de clase
- `GenerateQuestions`: Generar preguntas con IA
- `ListQuestions`: Listar preguntas de un banco
- `ApproveQuestion`: Aprobar pregunta generada

**Tasks:**
- `CreateTask`: Crear tarea (en desarrollo)
- `CompleteTask`: Completar tarea (en desarrollo)

### 12.5 Servicios de dominio

**GraphBuilder:**
- Genera grafos de batalla con caminos forzados
- Configurable: capas, nodos por capa, materias, seed
- Validacion de integridad del grafo

**BattleEngine:**
- Motor de reglas de batalla
- Maneja turnos, conquistas, robos, victoria
- Puro dominio, sin dependencias de infraestructura

---

## 13. API Y ENDPOINTS

### 13.1 Autenticacion

| Metodo | Ruta | Descripcion | Rol requerido |
|--------|------|-------------|---------------|
| POST | /api/v1/auth/login | Login con OAuth2 form data | Publico |
| POST | /api/v1/auth/register/director | Registro de director + colegio | Publico |
| GET | /api/v1/auth/me | Perfil del usuario actual | Autenticado |

### 13.2 Colegios y Secciones

| Metodo | Ruta | Descripcion | Rol requerido |
|--------|------|-------------|---------------|
| GET | /api/v1/schools | Listar colegios | Director, Subdirector |
| POST | /api/v1/schools | Crear colegio | Director |
| GET | /api/v1/schools/{id}/sections | Listar secciones | Director, Subdirector, Tutor, Profesor |
| POST | /api/v1/schools/{id}/sections | Crear secciones (batch) | Director, Subdirector, Tutor |
| POST | /api/v1/schools/{id}/students/bulk | Carga masiva de alumnos | Director, Subdirector, Tutor |

### 13.3 Usuarios

| Metodo | Ruta | Descripcion | Rol requerido |
|--------|------|-------------|---------------|
| GET | /api/v1/users/school/{id} | Listar usuarios por colegio | Todos los roles |
| GET | /api/v1/users/section/{id} | Listar usuarios por seccion | Profesores+ |
| POST | /api/v1/users | Crear usuario individual | Director |
| POST | /api/v1/users/staff | Crear profesor/tutor | Director |
| POST | /api/v1/users/{school_id}/students/csv | Importar alumnos CSV | Director, Subdirector, Tutor |

### 13.4 Banco de Preguntas

| Metodo | Ruta | Descripcion | Rol requerido |
|--------|------|-------------|---------------|
| GET | /api/v1/questions/banks | Listar bancos del colegio | Autenticado |
| POST | /api/v1/questions/banks | Crear banco | Profesor+ |
| POST | /api/v1/questions/banks/{id}/upload | Subir material | Profesor+ |
| POST | /api/v1/questions/banks/{id}/generate | Generar preguntas con IA | Autenticado |
| GET | /api/v1/questions/banks/{id}/questions | Listar preguntas del banco | Autenticado |
| POST | /api/v1/questions/{id}/approve | Aprobar pregunta | Profesor+ |

### 13.5 Batallas

| Metodo | Ruta | Descripcion | Rol requerido |
|--------|------|-------------|---------------|
| GET | /api/v1/battles/me | Mis batallas | Autenticado |
| POST | /api/v1/battles | Crear batalla | Alumno, Profesor+ |
| POST | /api/v1/battles/{id}/start | Iniciar batalla | Autenticado |
| POST | /api/v1/battles/{id}/select-node | Seleccionar nodo | Autenticado |
| POST | /api/v1/battles/{id}/answer | Enviar respuesta | Autenticado |
| GET | /api/v1/battles/{id} | Estado de batalla | Autenticado |

### 13.6 Health Check

| Metodo | Ruta | Descripcion |
|--------|------|-------------|
| GET | /api/v1/health | Estado del servidor |

---

## 14. PROTOCOLO WEBSOCKET

### 14.1 Conexion

Endpoint: `ws://servidor/ws/battles/{battle_id}`

Al conectarse, el servidor envia broadcast a todos los conectados:
```json
{
  "type": "player_joined",
  "battle_id": "uuid",
  "message": "Nuevo jugador conectado"
}
```

### 14.2 Mensajes cliente a servidor

**Ping:**
```json
{"type": "ping"}
```

**Solicitar estado:**
```json
{"type": "get_state"}
```

**Seleccionar nodo (futuro):**
```json
{
  "action": "select_node",
  "node_id": "uuid"
}
```

**Enviar respuesta (futuro):**
```json
{
  "action": "submit_answer",
  "node_id": "uuid",
  "answer": "B",
  "timestamp": 1690000000
}
```

### 14.3 Mensajes servidor a clientes

**Pong:**
```json
{"type": "pong"}
```

**Estado de batalla:**
```json
{
  "type": "battle_state",
  "battle_id": "uuid",
  "status": "in_progress",
  "current_turn": 0,
  "winner_id": null
}
```

**Nodo conquistado:**
```json
{
  "event": "node_conquered",
  "node_id": "uuid",
  "player": "player_1",
  "new_state": { ... }
}
```

**Cambio de turno:**
```json
{
  "event": "turn_change",
  "current_player": "player_2",
  "turn_timeout": 30
}
```

**Desafio de robo:**
```json
{
  "event": "steal_challenge",
  "node_id": "uuid",
  "attacker": "player_1",
  "question": { "text": "...", "options": [...] }
}
```

**Fin de batalla:**
```json
{
  "event": "battle_end",
  "winner": "player_1",
  "reason": "reached_base",
  "stats": { ... }
}
```

### 14.4 Desconexion

Cuando un jugador se desconecta:
```json
{
  "type": "player_left",
  "battle_id": "uuid",
  "message": "Un jugador se desconecto"
}
```

El sistema de manejo de conexiones usa un `BattleConnectionManager` que mantiene un diccionario de `battle_id -> [WebSocket connections]`.

---

## 15. INTERFAZ VISUAL Y ESTETICA

### 15.1 Estilo general

La interfaz sigue una estetica retro moderna inspirada en Balatro, con las siguientes caracteristicas:
- Paleta dominante entre rojo y morado
- Estilo retro pixel-art moderno
- Modo oscuro como default
- Sin emojis en ninguna parte
- Iconos vectoriales personalizados
- Animaciones fluidas con continuidad y desplazamiento

### 15.2 Paleta de colores

| Nombre | Hex | Uso |
|--------|-----|-----|
| Deep Purple | #1A0A2E | Fondo principal (scaffold) |
| Royal Purple | #2D1B4E | Superficies, AppBar |
| Crimson Red | #8B0000 | Color primario, botones |
| Bright Red | #C41E3A | Acentos, errores |
| Gold | #C9A84C | Secundario, bordes, texto destacado |
| Off White | #F5F0E8 | Texto principal |
| Dark Card | #241435 | Fondo de cards e inputs |
| Shadow Purple | #3A1F5E | Bordes sutiles |

### 15.3 Tipografia

| Uso | Fuente | Detalle |
|-----|--------|---------|
| Titulos y headers | Press Start 2P | Pixel font retro para titulos |
| Cuerpo y UI | Space Mono | Monoespaciada limpia para legibilidad |

### 15.4 Componentes de UI

**Cards:**
- Fondo: Dark Card (#241435)
- Elevacion: 8
- Bordes redondeados: 12px
- Borde dorado de 1px

**Botones:**
- Fondo: Crimson Red (#8B0000)
- Texto: Off White
- Borde dorado de 1px
- Border radius: 8px
- Padding: 24h x 14v

**Inputs:**
- Fondo: Dark Card
- Borde normal: Shadow Purple
- Borde focus: Gold (2px)
- Labels: Off White

### 15.5 Pantallas implementadas (mobile)

| Pantalla | Estado | Descripcion |
|----------|--------|-------------|
| Splash | Implementada | Pantalla de carga con branding |
| Login | Implementada | Autenticacion con username/password |
| Lobby | Implementada | Menu principal, seleccion de modos |
| Battle Lobby | Implementada | Configuracion pre-batalla |
| Battle | Implementada | Pantalla de batalla con grafo interactivo |

### 15.6 Animaciones requeridas

- Transiciones de pantalla con desplazamiento suave
- Animacion de conquista de nodo (pulso + cambio de color)
- Animacion de robo de nodo (efecto de "toma" con shake)
- Animacion de victoria (explosion de particulas retro)
- Micro-interacciones en botones (hover, press, release)
- Timer visual con cuenta regresiva animada
- Transicion de turno con efecto de slide

---

## 16. ANALISIS DE PUNTOS DEBILES

### 16.1 Seguridad

| # | Punto debil | Severidad | Estado |
|---|-------------|-----------|--------|
| S1 | Las respuestas correctas del banco NUNCA deben viajar al frontend antes de que el alumno responda | Critica | Identificado |
| S2 | Validar que un alumno no pueda iniciar batalla contra si mismo | Alta | Identificado |
| S3 | Prevenir inyeccion de respuestas por consola o manipulacion de requests | Alta | Identificado |
| S4 | Sanitizar material subido por profesores (archivos maliciosos) | Alta | Identificado |
| S5 | Rate limiting en generacion de preguntas con IA (costos) | Media | Identificado |
| S6 | JWT secret key debe cambiarse en produccion | Critica | Hardcoded en dev |
| S7 | CORS configurado como "*" en desarrollo, restringir en produccion | Alta | Configurado para dev |

### 16.2 Integridad del juego

| # | Punto debil | Severidad | Solucion propuesta |
|---|-------------|-----------|-------------------|
| J1 | Desconexion a media batalla | Alta | Timer de reconexion (60s), si expira se pausa la batalla |
| J2 | Ambos jugadores desconectados | Media | Batalla queda en PAUSED, se puede reanudar o cancelar tras 5 min |
| J3 | Empate: ambos llegan al nodo rival en el mismo turno | Baja | Improbable por turnos alternos, pero se resuelve: gana quien llego primero |
| J4 | Sin rutas disponibles (todos los nodos accesibles estan del rival) | Media | El jugador puede intentar robar nodos, no se bloquea nunca |
| J5 | Validacion de camino completo en el grafo | Alta | _ensure_forced_paths garantiza al menos un camino |
| J6 | Banco de preguntas agotado (menos de 5 preguntas para un nodo) | Media | Fallback: asignar menos preguntas (3 minimo) o reutilizar de otras materias |
| J7 | Sincronizacion de tiempos en robo de nodo (latencia) | Alta | Usar timestamp del servidor, no del cliente, para la comparacion |

### 16.3 Escalabilidad

| # | Punto debil | Riesgo |
|---|-------------|--------|
| E1 | Batallas simultaneas concurrentes | Cada batalla consume una conexion WebSocket. Redis pub/sub mitiga |
| E2 | Banco compartido vs por colegio | Actualmente por colegio, lo cual es correcto para aislamiento |
| E3 | Memorizacion de preguntas | Mitigado por 100 preguntas y rotacion. Futuro: mas preguntas |
| E4 | Carga de colegios grandes | SQLAlchemy async + PostgreSQL indexado deberia soportar |

### 16.4 UX / Interfaz

| # | Punto debil | Recomendacion |
|---|-------------|---------------|
| U1 | Seleccion de capas/nodos | Sliders con presets (rapido/normal/largo) |
| U2 | Grafo en pantallas pequenas | Zoom + pan con pinch gesture |
| U3 | Animaciones de conquista/robo | Deben ser claras, rapidas y sin bloquear interaccion |
| U4 | Legibilidad del estilo retro | Texto de cuerpo con Space Mono, no pixel font |
| U5 | Modo oscuro | Es el unico modo, consistente con el tema |

---

## 17. FLUJOS ALTERNOS CRITICOS

### 17.1 Profesor reutiliza preguntas de otro profesor

**Escenario:** Dos profesores dan la misma materia (ej: Matematica) en distintas secciones del mismo colegio. El profesor A sube material del tema "fracciones" y genera 100 preguntas. El profesor B necesita preguntas del mismo tema pero no quiere generar nuevas.

**Flujo actual:**
```
1. El banco de preguntas es por MATERIA y por COLEGIO (no por profesor)
2. Profesor A sube material -> genera preguntas -> aprueba las buenas
3. Profesor B accede al mismo banco de Matematica
4. Profesor B ve TODAS las preguntas del banco (las de A y las que el genere)
5. Profesor B puede:
   a) Usar las preguntas ya aprobadas por A (sin accion adicional)
   b) Subir su propio material adicional y generar mas preguntas
   c) Las nuevas preguntas se agregan al MISMO banco
   d) Aprobar sus propias preguntas
6. Las batallas de CUALQUIER seccion del colegio usan el pool completo
   de preguntas aprobadas del banco de la materia
```

**Consideracion de conflicto:** Si profesor B rechaza una pregunta que profesor A aprobo, actualmente no se revierte la aprobacion. El campo `creator_id` permite trazar quien genero cada pregunta.

**Mejora futura:** Agregar filtros en el panel de preguntas para que cada profesor vea primero las suyas (filtro por creator_id), y un sistema de "vetos" donde un profesor puede marcar preguntas de otro como cuestionables para revision del Tutor o Director.

### 17.2 Alumno cambia de seccion

**Escenario:** Un alumno de "5to Primaria - Seccion A" se transfiere a "5to Primaria - Seccion B" a mitad del periodo escolar. Tiene 450 XP, rango "Guerrero", pertenece al clan "Halcones" de Seccion A, y ha jugado 23 batallas.

**Flujo de transferencia:**
```
1. El Director o Tutor actualiza el section_id del alumno en la BD
   (PUT /api/v1/users/{user_id} con nuevo section_id)
2. Sistema ejecuta internamente:
   a) DATOS QUE SE CONSERVAN:
      - user.xp = 450 (no cambia)
      - user.rank_id = rango "Guerrero" (no cambia)
      - Historial completo de batallas (BattleMoves vinculados a user_id)
      - Historial de tareas completadas y entregas
      - Contrasena y credenciales de acceso
   b) DATOS QUE CAMBIAN:
      - user.section_id = nueva seccion B
      - user.clan_id = NULL (se desvincula del clan "Halcones")
        Razon: los clanes son internos a una seccion, no cruzan secciones
   c) LEADERBOARDS:
      - Desaparece del leaderboard de Seccion A
      - Aparece en el leaderboard de Seccion B con sus 450 XP intactos
      - Puede ser el primero del ranking de Seccion B si nadie tiene mas XP
   d) BATALLAS FUTURAS:
      - Puede retar a alumnos de Seccion B (competencia interna)
      - Puede seguir retando a alumnos de Seccion A (competencia inter-secciones)
   e) CLAN:
      - El Tutor de Seccion B puede asignarlo a un clan de esa seccion
      - Mientras no sea asignado, clan_id queda NULL
3. Resultado: El alumno opera normalmente en su nueva seccion sin perder progreso
```

### 17.3 Un profesor deja el colegio

**Escenario:** La profesora de Comunicacion renuncia al colegio. Ha generado 300 preguntas en el banco de Comunicacion, de las cuales 250 estan aprobadas. Tiene 5 tareas activas asignadas a 3 secciones.

**Flujo de baja:**
```
1. El Director desactiva la cuenta del profesor:
   user.is_active = False
   El profesor ya no puede hacer login
2. PREGUNTAS:
   - Las 250 preguntas aprobadas PERMANECEN en el banco
   - Las 50 preguntas no aprobadas PERMANECEN (pueden ser revisadas por otro)
   - El creator_id sigue apuntando al profesor (para trazabilidad)
   - Otro profesor de Comunicacion asignado al colegio puede:
     a) Ver todas las preguntas del banco
     b) Aprobar las pendientes
     c) Generar nuevas preguntas con su propio material
   - Las preguntas NUNCA se borran automaticamente al desactivar un usuario
3. TAREAS ACTIVAS:
   - Las tareas creadas por el profesor siguen visibles para los alumnos
   - Las entregas pendientes de calificacion quedan sin calificar
   - Un nuevo profesor o el Tutor puede asumir la calificacion (futuro)
   - Opcion: el Director puede reasignar las tareas a otro profesor
4. SECCIONES:
   - Las secciones donde daba clase necesitan un nuevo profesor asignado
   - El Director asigna otro profesor a esas secciones y materias
5. MATERIAL SUBIDO:
   - Los archivos de material quedan en storage (pertenecen al colegio)
   - El nuevo profesor puede usarlos para generar mas preguntas
```

### 17.4 Director quiere ver metricas globales

**Escenario:** El Director necesita presentar un informe al UGEL sobre el uso de la plataforma y el rendimiento de sus alumnos.

**Flujo del dashboard:**
```
1. Director accede al Dashboard del Director
   Endpoint: GET /api/v1/schools/{school_id}/dashboard
   Rol requerido: Director

2. El sistema consulta y agrega datos de multiples fuentes:

   METRICAS DE ACTIVIDAD:
   - Total de batallas jugadas (filtrable por dia, semana, mes, periodo)
   - Batallas activas en este momento
   - Promedio de batallas por alumno
   - Horas pico de uso (cuando juegan mas)

   METRICAS DE RENDIMIENTO:
   - Tasa de acierto global por materia
   - Materias con mas errores (preguntas con menor tasa de acierto)
   - Tiempo promedio de respuesta por materia
   - Evolucion del rendimiento en el tiempo (grafico de tendencia)

   METRICAS POR SECCION:
   - Leaderboard de secciones (puntaje acumulado)
   - Tasa de victoria por seccion en batallas inter-secciones
   - Seccion con mayor participacion
   - Seccion con mayor progresion de rangos

   METRICAS DE ALUMNOS:
   - Top 10 alumnos por XP
   - Alumnos con mayor cantidad de batallas ganadas
   - Alumnos sin actividad en los ultimos N dias (alerta)
   - Distribucion de rangos (cuantos en cada nivel)

   METRICAS DEL BANCO:
   - Preguntas generadas vs aprobadas por materia
   - Preguntas mas falladas (posibles puntos debiles del curriculo)
   - Tasa de uso del banco (preguntas usadas / totales)

3. El Director puede:
   - Filtrar por periodo, seccion, materia
   - Exportar reporte como PDF o CSV
   - Compartir datos con el Subdirector
```

### 17.5 Batalla entre secciones

**Escenario:** El Director organiza un enfrentamiento entre "6to Primaria - Seccion A" y "6to Primaria - Seccion B" como actividad de fin de unidad.

**Flujo completo:**
```
PASO 1: CONVOCATORIA
  Actor: Director o Tutor de cualquiera de las dos secciones
  Inicia la creacion de una batalla inter-secciones:
    - Selecciona Seccion A como equipo 1
    - Selecciona Seccion B como equipo 2
    - Define el formato:
      a) Representantes: 1 a 5 alumnos por seccion
      b) Los representantes pueden ser elegidos por el Tutor o por votacion
      c) El matchmaking empareja representantes por rango similar
         (ej: el mejor de A vs el mejor de B, el segundo vs el segundo, etc.)

PASO 2: SELECCION DE REPRESENTANTES
  Actor: Tutor de cada seccion
  Cada tutor selecciona a sus representantes:
    - Puede elegir manualmente o aceptar voluntarios
    - Se recomienda equilibrar por rango para partidas justas
    - Los representantes seleccionados ven la batalla en su lista de pendientes

PASO 3: RONDAS DE BATALLA
  Se ejecutan N batallas 1v1 (una por cada par de representantes):
    - Representante 1 de A vs Representante 1 de B -> Batalla normal 1v1
    - Representante 2 de A vs Representante 2 de B -> Batalla normal 1v1
    - ...etc
  Cada batalla sigue el flujo estandar de turnos, conquista y robo
  Todas las batallas se marcan con is_section_battle = True

PASO 4: CALCULO DE RESULTADOS
  Al finalizar todas las rondas:
    - Puntaje Seccion A = numero de batallas ganadas por representantes de A
    - Puntaje Seccion B = numero de batallas ganadas por representantes de B
    - La seccion con mas victorias gana el enfrentamiento
    - En caso de empate: se suma el total de nodos conquistados como desempate

PASO 5: ACTUALIZACION DE LEADERBOARD
  - Se actualiza el leaderboard inter-secciones
  - La seccion ganadora recibe bonus de XP para todos sus miembros (futuro)
  - Los resultados quedan visibles en el dashboard del Director
```

**Consideraciones:**
- El matchmaking puede ser por rango similar o aleatorio (configurable)
- Solo el Director o Tutor pueden iniciar batallas inter-secciones
- Los alumnos que no son representantes pueden observar (modo espectador futuro)
- Las batallas inter-secciones consumen preguntas del mismo banco compartido

### 17.6 Tareas como alternativa a batallas

**Escenario:** Un alumno introvertido no quiere competir directamente contra companeros, pero quiere subir de rango. El profesor de Matematica deja una tarea de practica de fracciones.

**Flujo completo:**
```
1. CREACION (Profesor):
   - Profesor crea tarea: "Practica de fracciones"
   - Tipo: multiple_choice
   - Seccion destino: 5to A
   - XP recompensa: 15
   - Fecha limite: viernes 18:00
   - El sistema notifica a los alumnos de 5to A (futuro: push notification)

2. VISUALIZACION (Alumno):
   - El alumno abre su lista de tareas pendientes
   - Ve la tarea con: titulo, tipo, XP, fecha limite, estado (pendiente/completada)
   - La fecha limite se muestra con urgencia visual si esta proxima

3. COMPLETADO (Alumno):
   - Para multiple_choice:
     a) El sistema presenta 10 preguntas del banco de Matematica
     b) El alumno responde cada una seleccionando A/B/C/D
     c) Al terminar, presiona "Entregar"
     d) El sistema evalua automaticamente:
        - 8 correctas de 10 -> score = 80
        - XP ganada = 15 * 0.80 = 12 XP
     e) El alumno ve inmediatamente su resultado y explicaciones

4. PROGRESION:
   - El alumno tenia 295 XP, ahora tiene 307 XP
   - El siguiente rango (Guerrero) requiere 300 XP
   - El alumno sube al rango Guerrero automaticamente
   - Se muestra notificacion: "Subiste al rango Guerrero!"
   - El puntaje de su clan se incrementa en 12

5. REPORTE (Profesor):
   - El profesor ve en su panel que 18 de 25 alumnos completaron la tarea
   - Ve el promedio de aciertos por pregunta
   - Identifica que la pregunta 7 tuvo solo 30% de acierto
   - Decide reforzar ese tema en la siguiente clase
```

**Importancia:** Las tareas son la via principal de progresion para alumnos que no tienen acceso constante a un oponente, que prefieren aprender de forma individual, o en colegios donde no todos los alumnos tienen dispositivos. El profesor puede dejar tareas para que los alumnos las completen a su ritmo.

### 17.7 Fallos en la generacion de preguntas por IA

**Escenario:** El profesor de Historia sube un PDF del tema "Independencia del Peru". La IA genera 100 preguntas pero varias tienen errores: preguntas ambiguas, respuestas incorrectas, enunciados confusos o preguntas fuera del tema.

**Flujo de manejo de fallos:**
```
1. DETECCION (automatica + manual):
   - El sistema genera las 100 preguntas y las persiste con is_approved = False
   - NINGUNA pregunta entra al banco activo automaticamente
   - El profesor recibe la lista completa para revision

2. REVISION (Profesor):
   El profesor abre el panel de revision y evalua cada pregunta:

   CASO A -- Pregunta de buena calidad:
     - Enunciado claro, opciones coherentes, respuesta correcta verificable
     - Profesor presiona "Aprobar" -> is_approved = True
     - La pregunta entra al banco y puede usarse en batallas

   CASO B -- Pregunta con error menor:
     - Enunciado bueno pero una opcion tiene typo, o la explicacion es confusa
     - (Futuro) Profesor presiona "Editar", corrige el error, luego aprueba
     - (Actual) Profesor no aprueba y solicita regeneracion

   CASO C -- Pregunta de mala calidad:
     - Pregunta ambigua, fuera del tema, sin sentido, o con respuesta incorrecta
     - Profesor NO aprueba (la pregunta queda con is_approved = False)
     - La pregunta nunca se usara en batallas
     - El profesor puede solicitar regeneracion

   CASO D -- Pregunta duplicada o muy similar a otra:
     - Profesor no aprueba la duplicada
     - Solo aprueba la mejor version

3. REGENERACION (si muchas preguntas son de mala calidad):
   - El profesor puede subir material adicional o diferente
   - Solicitar nueva generacion con el nuevo material
   - Las nuevas preguntas se agregan al banco (no reemplazan las anteriores)
   - Las preguntas rechazadas quedan en BD como referencia

4. GARANTIA DE SEGURIDAD:
   - El sistema NUNCA usa preguntas no aprobadas en batallas
   - La consulta de preguntas para nodos filtra por is_approved = True
   - Si no hay suficientes preguntas aprobadas, los nodos tienen menos retos
     pero las batallas siguen funcionando
```

**Metricas de calidad del agente IA:**
- Se puede trackear: preguntas_generadas / preguntas_aprobadas = tasa de aprobacion
- Si la tasa de aprobacion es baja (<50%), sugiere mejorar el prompt o el material de entrada
- Futuro: feedback loop donde las preguntas rechazadas se usan para mejorar el prompt

### 17.8 Colores de materias insuficientes

**Escenario:** Un colegio habilita las 12 materias base mas 4 talleres adicionales (Robotica, Teatro, Musica, Danza). Necesita 16 colores distinguibles en el grafo.

**Resolucion actual:** 12 materias con colores predefinidos en el enum Subject + 4 colores adicionales en el tema mobile (technology, philosophy, religion, computing). Total: 16 colores distintos.

**Flujo de asignacion de colores:**
```
1. Cada materia en el enum Subject tiene un default_color predefinido
2. Al crear nodos, GraphBuilder asigna: node.color = subject.default_color
3. Los colores se eligieron para ser distinguibles sobre fondo oscuro (#1A0A2E)
4. Si se agregan mas de 16 materias:
   a) Se generan variaciones de tono (mas claro/oscuro) de los colores existentes
   b) Se agrega un patron o textura al nodo ademas del color (futuro)
   c) Se muestra el nombre abreviado de la materia dentro del nodo como refuerzo
5. Los colores son configurables por colegio (futuro):
   - El Director podria cambiar el color de cualquier materia
   - Los cambios se reflejarian en todos los grafos futuros
```

---

## 18. CONSIDERACIONES DE SEGURIDAD

### 18.1 Autenticacion

- JWT con HS256 y refresh token
- Secret key configurable via environment variable
- Tokens con expiracion de 24 horas (1440 minutos)
- Contrasenas hasheadas con bcrypt
- OAuth2 password flow para login

### 18.2 Autorizacion

- RBAC basado en el rol embebido en el JWT
- Cada endpoint valida el rol minimo requerido
- Validacion de school_match para aislar colegios
- No hay acceso cross-school por defecto

### 18.3 Validacion de datos

- Pydantic v2 para validacion de requests
- SQLAlchemy para integridad referencial
- Sanitizacion de archivos subidos (pendiente)
- Validacion de UUID en todos los path parameters

### 18.4 Anti-trampa en batallas

- Las respuestas correctas NUNCA se envian al frontend con la pregunta
- Solo se envian: enunciado, opciones A-D
- La verificacion de respuesta es siempre server-side
- Los timestamps de robo se comparan en el servidor
- Rate limiting por jugador (prevenir spam de respuestas)

---

## 19. VISION A FUTURO

### 19.1 Corto plazo (siguiente iteracion)

- Completar batallas entre secciones con formato de campeonato
- Dashboard completo para directores con graficos de rendimiento
- Dashboard de profesor con analisis de errores frecuentes por materia
- Sistema de notificaciones (retos, tareas, resultados)
- Modalidad espectador: alumnos pueden ver batallas en curso
- Progreso guardado: reanudar batallas interrumpidas

### 19.2 Mediano plazo

- Matchmaking automatico por rango similar
- Modalidades 2v2 y 5v5 (equipos dentro de la misma seccion)
- Modo torneo: brackets eliminatorios entre secciones
- Offline mode: cache de preguntas para jugar sin internet
- Sincronizacion eventual cuando haya conectividad
- Soporte multi-idioma (espanol base, ingles futuro)
- Integracion con OCR para extraer texto de imagenes

### 19.3 Largo plazo

- Marketplace de bancos de preguntas entre colegios
- API publica para integracion con sistemas de gestion escolar (SIAGIE)
- App web responsive (ademas de la app mobile)
- Modo docente con un solo dispositivo (proyector + equipos)
- Generacion de preguntas con modelos locales (sin depender de API externa)
- Analytics avanzados con IA: prediccion de rendimiento, recomendacion de refuerzos
- Plan de suscripcion: gratuito para colegios publicos, premium con features avanzados
- Accesibilidad: contraste alto, tamano de fuente ajustable, screen readers
- Gamificacion avanzada: achievements, streaks, recompensas cosmeticas
- Reportes exportables para UGEL y DRE

### 19.4 Preguntas abiertas

1. Como balancear la calidad de preguntas generadas por IA para que sean pedagogicamente validas?
2. Que estrategia de monetizacion/sostenibilidad tendra la plataforma?
3. Como manejar la latencia en zonas con baja conectividad?
4. El sistema deberia soportar multiples tipos de preguntas mas alla de alternativas (ej: arrastrar, ordenar, emparejar)?
5. Como evitar que la competencia opaque el aprendizaje?
6. Que metricas de impacto se mediran en pilotos reales?

---

## 20. PLAN DE IMPLEMENTACION DETALLADO

### 20.1 Estado actual

El proyecto se encuentra en Fase 0 (Fundacion) con los siguientes avances:

**Completado:**
- Repositorio en GitHub (LuisRz1/battlegraf)
- Monorepo con estructura backend + mobile
- Docker Compose (PostgreSQL + Redis + MinIO + Celery)
- Entidades de dominio: School, Section, User, Subject, Question, Battle, Graph
- Enums: Role, Subject, BattleStatus, TaskType
- Servicios de dominio: GraphBuilder, BattleEngine
- Interfaces/puertos abstractos
- FastAPI con health check, CORS, rutas registradas
- SQLAlchemy async + modelos ORM completos
- Autenticacion JWT con registro de director + login
- RBAC con sistema de permisos por rol
- Endpoints CRUD: Schools, Sections, Users (individual + bulk + CSV)
- Banco de preguntas: CRUD, upload de material, generacion con IA, aprobacion
- Batallas: creacion, inicio, seleccion de nodo, envio de respuesta, historial
- WebSocket basico para batallas en tiempo real
- Agente IA con OpenAI + fallback mock
- App Flutter con arquitectura limpia, tema Balatro, login, lobby, batalla
- Tests unitarios para GraphBuilder y BattleEngine

### 20.2 Fases restantes

---

**FASE 1: Gestion de Colegios (Completar)**
- Completar CRUD de materias (habilitar/deshabilitar por colegio)
- Panel de administracion en Flutter para Director
- Asignacion de materias a profesores
- Pantalla de onboarding paso a paso
- Tests de integracion para flujo completo de onboarding

---

**FASE 2: Banco de Preguntas e IA (Completar)**
- Integracion con PPT (extraccion de texto de slides)
- OCR para imagenes (Pillow + pytesseract)
- Panel de revision de preguntas en Flutter
- Edicion de preguntas por el profesor
- Regeneracion selectiva de preguntas
- Rate limiting y control de costos de IA
- Indicador de uso de preguntas (usage_count)

---

**FASE 3: Motor de Grafos y Batallas (Completar)**
- Sincronizacion completa de batalla via WebSocket
- Temporizador server-side por turno
- Mecanica de reconexion (60s timeout, estado PAUSED)
- Condicion de empate
- Animaciones de conquista y robo en Flutter
- HUD con turno, temporizador, puntaje en tiempo real
- Pantalla de resultados post-batalla con estadisticas

---

**FASE 4: Frontend Mobile -- Completar Core**
- Renderizado interactivo del grafo con CustomPainter
- Zoom + pan con gestos tactiles
- Seleccion de nodo con tap
- Presentacion de pregunta (modal o pantalla)
- Animacion de respuesta (correcta/incorrecta)
- Flujo completo de batalla end-to-end

---

**FASE 5: Tareas y Progresion**
- CRUD completo de tareas en backend y frontend
- Pantalla de tareas para el alumno
- Entrega de tareas (texto, archivo, multiple choice)
- Calificacion manual por profesor
- Sistema de rangos completo con progresion automatica
- Leaderboard por seccion y por colegio
- Clanes: CRUD, membresia, puntaje acumulado
- Pantalla de perfil con rango, XP, clan, historial

---

**FASE 6: Batallas entre Secciones y Dashboard**
- Matchmaking entre secciones
- Formato de campeonato inter-secciones
- Dashboard del Director con metricas globales
- Dashboard del Profesor con analisis de errores
- Dashboard del Tutor con vista de seccion
- Graficos y visualizaciones
- Exportacion de reportes

---

**FASE 7: Pulido y Produccion**
- Auditoria de seguridad
- Load testing (batallas concurrentes)
- Offline mode (cache de preguntas + cola de acciones)
- Animaciones avanzadas (transiciones, micro-interacciones)
- Sonidos retro arcade
- Tutorial de onboarding para nuevos usuarios
- Deploy backend en cloud
- Build iOS y Android para publicacion
- Documentacion de API (OpenAPI/Swagger)
- Guia de usuario para colegios

---

### 20.3 Modelo de datos relacional completo

```
School 1-----N Section
School 1-----N User (all roles)
School 1-----N QuestionBank
School 1-----N Rank

Section 1-----N User (students)
Section 1-----1 User (tutor)
Section 1-----N Clan
Section 1-----N Task

Clan 1-----N User (members)

User (teacher) N---M Subject (teaches)
User (teacher) N---M Section (assigned)
User (student) N---1 Rank
User (student) N---1 Clan

QuestionBank 1-----N Question
QuestionBank 1-----1 Subject

Question N---1 User (creator)
Question N---1 School

Graph 1-----N GraphNode
GraphNode N---N GraphNode (connections via connected_to)
GraphNode N---N Question (5 assigned via question_ids)

Battle 1-----1 Graph
Battle 1-----2 User (players)
Battle 1-----N BattleNodeState
Battle 1-----N BattleMove

BattleMove N---1 GraphNode
BattleMove N---1 Question

Task N---1 User (creator/professor)
Task N---1 Section
TaskSubmission N---1 Task
TaskSubmission N---1 User (student)
```

---

> Fin del documento.
> BattleGraph v3.0 -- Julio 2026
