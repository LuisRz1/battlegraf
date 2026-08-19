"use client";

import {
  useEffect,
  useMemo,
  useReducer,
  useRef,
  useState,
} from "react";
import {
  battleEdges,
  battleNodes,
  battleReducer,
  createInitialBattleState,
  getAvailableNodes,
  getQuestionForState,
  subjectLabels,
  type BattleNode,
  type LastMove,
  type PlayerId,
} from "./battle-engine";

type ElementSize = {
  width: number;
  height: number;
};

type MapState = {
  currentPlayer: PlayerId;
  owners: Record<string, PlayerId | null>;
  positions: Record<PlayerId, string>;
  lastMove: LastMove | null;
  targetId?: string | null;
};

const playerNames: Record<PlayerId, string> = {
  red: "Jugador rojo",
  violet: "Jugador morado",
};

const subjectCodes = {
  math: "Σ",
  communication: "Aa",
  science: "H2O",
  history: "1492",
  art: "CMY",
  base: "BG",
} as const;

const heroMoves: LastMove[] = [
  { from: "alpha", to: "m1", player: "red", result: "capture" },
  { from: "omega", to: "s2", player: "violet", result: "capture" },
  { from: "m1", to: "h1", player: "red", result: "capture" },
  { from: "s2", to: "h1", player: "violet", result: "steal" },
  { from: "h1", to: "s1", player: "red", result: "capture" },
  { from: "h1", to: "c2", player: "violet", result: "capture" },
];

function useElementSize<T extends HTMLElement>() {
  const ref = useRef<T>(null);
  const [size, setSize] = useState<ElementSize>({ width: 0, height: 0 });

  useEffect(() => {
    const element = ref.current;
    if (!element) return;

    const update = () => {
      const bounds = element.getBoundingClientRect();
      setSize({ width: bounds.width, height: bounds.height });
    };
    update();

    const observer = new ResizeObserver(update);
    observer.observe(element);
    return () => observer.disconnect();
  }, []);

  return { ref, size };
}

function PixelCastle({ player }: { player: PlayerId }) {
  return (
    <span className={`pixel-castle castle-${player}`} aria-hidden="true">
      <i className="castle-aura" />
      <i className="castle-platform" />
      <i className="castle-keep" />
      <i className="castle-tower castle-tower-left" />
      <i className="castle-tower castle-tower-right" />
      <i className="castle-crown castle-crown-main" />
      <i className="castle-crown castle-crown-left" />
      <i className="castle-crown castle-crown-right" />
      <i className="castle-gate" />
      <i className="castle-window castle-window-one" />
      <i className="castle-window castle-window-two" />
      <i className="castle-window castle-window-three" />
      <i className="castle-flagpole" />
      <i className="castle-flag" />
    </span>
  );
}

function AcademyTower({ node }: { node: BattleNode }) {
  return (
    <span className={`academy-tower academy-${node.subject}`} aria-hidden="true">
      <i className="academy-shadow" />
      <i className="academy-body" />
      <i className="academy-wing academy-wing-left" />
      <i className="academy-wing academy-wing-right" />
      <i className="academy-roof" />
      <i className="academy-door" />
      <i className="academy-window academy-window-left" />
      <i className="academy-window academy-window-right" />
      <strong>{subjectCodes[node.subject]}</strong>
    </span>
  );
}

function PlayerUnit({ player, active }: { player: PlayerId; active: boolean }) {
  return (
    <span
      className={`player-unit unit-${player} ${active ? "is-active" : ""}`}
      aria-hidden="true"
    >
      <i />
      <i />
      <i />
    </span>
  );
}

function GraphConnections({
  size,
  owners,
  lastMove,
}: {
  size: ElementSize;
  owners: Record<string, PlayerId | null>;
  lastMove: LastMove | null;
}) {
  if (!size.width || !size.height) return null;

  return (
    <div className="graph-connections" aria-hidden="true">
      {battleEdges.map(([from, to], index) => {
        const start = battleNodes.find((node) => node.id === from)!;
        const end = battleNodes.find((node) => node.id === to)!;
        const startX = (start.x / 100) * size.width;
        const startY = (start.y / 100) * size.height;
        const endX = (end.x / 100) * size.width;
        const endY = (end.y / 100) * size.height;
        const dx = endX - startX;
        const dy = endY - startY;
        const width = Math.hypot(dx, dy);
        const angle = Math.atan2(dy, dx);
        const sharedOwner =
          owners[from] && owners[from] === owners[to] ? owners[from] : null;
        const isLastMove =
          lastMove &&
          ((lastMove.from === from && lastMove.to === to) ||
            (lastMove.from === to && lastMove.to === from));
        const linePlayer = isLastMove ? lastMove.player : sharedOwner;

        return (
          <span
            className={`graph-connection ${
              linePlayer ? `connection-${linePlayer}` : ""
            } ${isLastMove ? "is-traveling" : ""}`}
            key={`${from}-${to}`}
            style={
              {
                left: `${startX}px`,
                top: `${startY}px`,
                width: `${width}px`,
                transform: `rotate(${angle}rad)`,
                "--packet-delay": `${index * -0.17}s`,
              } as React.CSSProperties
            }
          >
            <i />
            <i />
            <i />
          </span>
        );
      })}
    </div>
  );
}

function BattleMap({
  state,
  available = new Set<string>(),
  onNodeClick,
  demo = false,
}: {
  state: MapState;
  available?: Set<string>;
  onNodeClick?: (node: BattleNode) => void;
  demo?: boolean;
}) {
  const { ref, size } = useElementSize<HTMLDivElement>();

  return (
    <div
      className={`battle-map ${demo ? "battle-map-demo" : "battle-map-hero"}`}
      ref={ref}
      role="group"
      aria-label="Mapa de batalla con torres escolares conectadas"
    >
      <div className="hex-field" aria-hidden="true" />
      <GraphConnections
        lastMove={state.lastMove}
        owners={state.owners}
        size={size}
      />
      {battleNodes.map((node) => {
        const owner = state.owners[node.id];
        const playersHere = (["red", "violet"] as PlayerId[]).filter(
          (player) => state.positions[player] === node.id,
        );
        const isAvailable = available.has(node.id);
        const isTarget = state.targetId === node.id;
        const isCurrentPosition =
          state.positions[state.currentPlayer] === node.id;
        const ownerLabel = owner ? playerNames[owner] : "neutral";
        const disabled = demo && !isAvailable;

        return (
          <button
            aria-label={`${node.label}, territorio ${ownerLabel}${
              isAvailable ? ", movimiento disponible" : ""
            }`}
            className={`map-node node-${node.subject} ${
              node.baseFor ? `is-base base-${node.baseFor}` : ""
            } ${owner ? `owner-${owner}` : "owner-neutral"} ${
              isAvailable ? `is-available available-${state.currentPlayer}` : ""
            } ${isTarget ? "is-target" : ""} ${
              isCurrentPosition ? `is-current current-${state.currentPlayer}` : ""
            }`}
            disabled={disabled}
            key={node.id}
            onClick={() => onNodeClick?.(node)}
            style={{ left: `${node.x}%`, top: `${node.y}%` }}
            type="button"
          >
            <span className="hex-shell" aria-hidden="true" />
            <span className="hex-core" aria-hidden="true" />
            {node.baseFor ? (
              <PixelCastle player={node.baseFor} />
            ) : (
              <AcademyTower node={node} />
            )}
            <span className="node-caption">{node.shortLabel}</span>
            {playersHere.map((player) => (
              <PlayerUnit
                active={state.currentPlayer === player}
                key={player}
                player={player}
              />
            ))}
          </button>
        );
      })}
      <div className="map-coordinate coordinate-a" aria-hidden="true">
        06°12&apos;S
      </div>
      <div className="map-coordinate coordinate-b" aria-hidden="true">
        RED ESCOLAR 01
      </div>
    </div>
  );
}

function buildHeroState(step: number): MapState {
  const owners = Object.fromEntries(
    battleNodes.map((node) => [
      node.id,
      node.baseFor === "red"
        ? "red"
        : node.baseFor === "violet"
          ? "violet"
          : null,
    ]),
  ) as Record<string, PlayerId | null>;
  const positions: Record<PlayerId, string> = {
    red: "alpha",
    violet: "omega",
  };

  for (const move of heroMoves.slice(0, step)) {
    owners[move.to] = move.player;
    positions[move.player] = move.to;
  }

  return {
    currentPlayer: step % 2 === 0 ? "red" : "violet",
    owners,
    positions,
    lastMove: step ? heroMoves[step - 1] : null,
  };
}

function HeroBattlefield({ onPlay }: { onPlay: () => void }) {
  const [step, setStep] = useState(0);
  const state = useMemo(() => buildHeroState(step), [step]);

  useEffect(() => {
    const timer = window.setInterval(
      () => setStep((current) => (current + 1) % (heroMoves.length + 1)),
      1400,
    );
    return () => window.clearInterval(timer);
  }, []);

  return (
    <div className="hero-battlefield">
      <div className="hero-hud">
        <div className="hero-player hero-player-red">
          <span>6.º PRIMARIA A</span>
          <strong>ROJO</strong>
        </div>
        <div className="hero-turn">
          <span>BATALLA 01 · RONDA {Math.floor(step / 2) + 1}</span>
          <strong className={`turn-color-${state.currentPlayer}`}>
            TURNO {state.currentPlayer === "red" ? "ROJO" : "MORADO"}
          </strong>
        </div>
        <div className="hero-player hero-player-violet">
          <span>6.º PRIMARIA B</span>
          <strong>MORADO</strong>
        </div>
      </div>
      <BattleMap onNodeClick={onPlay} state={state} />
      <button className="map-start-button" onClick={onPlay} type="button">
        <span>ENTRAR AL MAPA</span>
        <i aria-hidden="true">01</i>
      </button>
    </div>
  );
}

function PrototypeModal({ onClose }: { onClose: () => void }) {
  const [state, dispatch] = useReducer(
    battleReducer,
    undefined,
    createInitialBattleState,
  );
  const dialogRef = useRef<HTMLElement>(null);
  const closeRef = useRef<HTMLButtonElement>(null);
  const turnStartedAt = useRef(0);
  const availableNodes = useMemo(() => getAvailableNodes(state), [state]);
  const question = getQuestionForState(state);
  const target = state.targetId
    ? battleNodes.find((node) => node.id === state.targetId)
    : null;

  useEffect(() => {
    turnStartedAt.current = performance.now();
  }, [state.turnNumber]);

  useEffect(() => {
    if (state.winner) return;
    const timer = window.setInterval(() => dispatch({ type: "TICK" }), 1000);
    return () => window.clearInterval(timer);
  }, [state.turnNumber, state.winner]);

  useEffect(() => {
    const previousFocus = document.activeElement as HTMLElement | null;
    closeRef.current?.focus();

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        onClose();
        return;
      }
      if (event.key !== "Tab" || !dialogRef.current) return;
      const focusable = Array.from(
        dialogRef.current.querySelectorAll<HTMLElement>(
          "button:not([disabled]), a[href], [tabindex]:not([tabindex='-1'])",
        ),
      );
      if (!focusable.length) return;
      const first = focusable[0];
      const last = focusable[focusable.length - 1];
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    };

    window.addEventListener("keydown", handleKeyDown);
    return () => {
      window.removeEventListener("keydown", handleKeyDown);
      previousFocus?.focus();
    };
  }, [onClose]);

  const answer = (optionIndex: number, answeredAt: number) => {
    dispatch({
      type: "ANSWER",
      optionIndex,
      responseTimeMs: Math.max(
        100,
        Math.round(answeredAt - turnStartedAt.current),
      ),
    });
  };

  const countOwned = (player: PlayerId) =>
    battleNodes.filter(
      (node) => !node.baseFor && state.owners[node.id] === player,
    ).length;

  return (
    <div
      className="game-overlay"
      onMouseDown={(event) => {
        if (event.target === event.currentTarget) onClose();
      }}
      role="presentation"
    >
      <section
        aria-label="Demo jugable de BattleGraph"
        aria-modal="true"
        className={`game-screen active-${state.currentPlayer}`}
        ref={dialogRef}
        role="dialog"
      >
        <header className="game-topbar">
          <div className="game-brand">
            <span className="brand-sigil"><i /><i /><i /></span>
            <strong>BATTLE<span>GRAF</span></strong>
          </div>
          <div className="game-room">
            <span>PARTIDA LOCAL</span>
            <strong>6.º A VS 6.º B</strong>
          </div>
          <div className="game-actions">
            <button
              onClick={() => dispatch({ type: "RESET" })}
              type="button"
            >
              REINICIAR
            </button>
            <button onClick={onClose} ref={closeRef} type="button">
              CERRAR
            </button>
          </div>
        </header>

        <div className="battle-hud">
          <div className="hud-player hud-red">
            <span className="hud-flag" aria-hidden="true" />
            <div><small>JUGADOR 01</small><strong>ROJO · 6.º A</strong></div>
            <b>{countOwned("red").toString().padStart(2, "0")} TORRES</b>
          </div>
          <div className="hud-turn">
            <span>RONDA {Math.ceil(state.turnNumber / 2).toString().padStart(2, "0")}</span>
            <strong>
              TURNO {state.currentPlayer === "red" ? "ROJO" : "MORADO"}
            </strong>
            <time aria-label="Tiempo restante" role="timer">
              00:{state.remainingSeconds.toString().padStart(2, "0")}
            </time>
          </div>
          <div className="hud-player hud-violet">
            <b>{countOwned("violet").toString().padStart(2, "0")} TORRES</b>
            <div><small>JUGADOR 02</small><strong>MORADO · 6.º B</strong></div>
            <span className="hud-flag" aria-hidden="true" />
          </div>
        </div>

        <div className="game-layout">
          <div className="game-map-panel">
            <div className="map-objective">
              <span>OBJETIVO</span>
              <strong>CONQUISTA LA FORTALEZA RIVAL</strong>
            </div>
            <BattleMap
              available={availableNodes}
              demo
              onNodeClick={(node) =>
                dispatch({ type: "SELECT_NODE", nodeId: node.id })
              }
              state={state}
            />
            <p
              aria-live="polite"
              className={`game-message tone-${state.messageTone}`}
            >
              <span>{state.messageTone === "danger" ? "ALERTA" : "SISTEMA"}</span>
              {state.message}
            </p>
          </div>

          <aside className={`challenge-panel ${question ? "has-question" : ""}`}>
            <div className="challenge-header">
              <span>
                {target ? subjectLabels[target.subject].toUpperCase() : "CENTRO DE MANDO"}
              </span>
              <span>{question ? "RETO ACTIVO" : "ESPERANDO RUTA"}</span>
            </div>

            {state.winner ? (
              <div className={`victory-panel victory-${state.winner}`}>
                <span>BATALLA FINALIZADA</span>
                <strong>
                  VICTORIA {state.winner === "red" ? "ROJA" : "MORADA"}
                </strong>
                <p>La fortaleza rival fue conquistada siguiendo rutas válidas.</p>
                <button
                  onClick={() => dispatch({ type: "RESET" })}
                  type="button"
                >
                  NUEVA PARTIDA
                </button>
              </div>
            ) : question ? (
              <>
                <div className="question-meta">
                  <span>NODO {target?.shortLabel}</span>
                  <span>
                    {state.owners[target!.id] &&
                    state.owners[target!.id] !== state.currentPlayer
                      ? "INTENTO DE ROBO"
                      : "CONQUISTA"}
                  </span>
                </div>
                <h2>{question.text}</h2>
                <div className="answer-grid">
                  {question.options.map((option, index) => (
                    <button
                      key={option}
                      onClick={(event) => answer(index, event.timeStamp)}
                      type="button"
                    >
                      <span>{String.fromCharCode(65 + index)}</span>
                      <strong>{option}</strong>
                    </button>
                  ))}
                </div>
                <p className="question-note">
                  Una respuesta correcta conquista el nodo. Si ya pertenece al
                  rival, también debes igualar o mejorar su tiempo.
                </p>
              </>
            ) : (
              <div className="mission-rules">
                <span className="mission-kicker">PROTOCOLO DE TURNO</span>
                <h2>
                  {state.currentPlayer === "red"
                    ? "EL EJÉRCITO ROJO MUEVE"
                    : "EL EJÉRCITO MORADO MUEVE"}
                </h2>
                <ol>
                  <li><span>01</span><p>Elige uno de los hexágonos iluminados.</p></li>
                  <li><span>02</span><p>Resuelve el reto antes de que termine el tiempo.</p></li>
                  <li><span>03</span><p>Conquista, roba o pierde el turno.</p></li>
                </ol>
                <div className="mission-stats">
                  <span><small>INTENTOS ROJOS</small>{state.attempts.red}</span>
                  <span><small>INTENTOS MORADOS</small>{state.attempts.violet}</span>
                </div>
              </div>
            )}
          </aside>
        </div>
      </section>
    </div>
  );
}

const roles = [
  {
    code: "DIR",
    title: "Dirección",
    copy: "Configura la entidad colegio, secciones, usuarios, rangos y visión institucional.",
    scope: "Todo el colegio",
  },
  {
    code: "SUB",
    title: "Subdirección",
    copy: "Administra primaria o secundaria, sus equipos y las métricas del nivel.",
    scope: "Nivel asignado",
  },
  {
    code: "TUT",
    title: "Tutoría",
    copy: "Acompaña una sección, sus tareas, clanes, batallas y progreso individual.",
    scope: "Una sección",
  },
  {
    code: "DOC",
    title: "Docentes",
    copy: "Suben materiales, revisan preguntas y analizan resultados por materia.",
    scope: "Materias asignadas",
  },
  {
    code: "ALU",
    title: "Estudiantes",
    copy: "Compiten, cumplen tareas, ganan XP y hacen visible su aprendizaje.",
    scope: "Perfil y sección",
  },
];

const faqs = [
  {
    question: "¿BattleGraph reemplaza las clases o las evaluaciones?",
    answer:
      "No. Convierte material validado por el docente en práctica estratégica. El profesor conserva el control del contenido, las preguntas y la evaluación.",
  },
  {
    question: "¿Cómo se evita que la IA publique preguntas incorrectas?",
    answer:
      "Toda pregunta generada comienza pendiente. Solo entra a una batalla después de que el docente de la materia —o un rol superior— la revisa y aprueba.",
  },
  {
    question: "¿Pueden competir aulas diferentes?",
    answer:
      "Sí. El colegio puede activar batallas dentro de una sección, entre secciones del mismo grado o entre grados con dificultad apropiada.",
  },
  {
    question: "¿Qué ocurre si un jugador entra a un nodo rival?",
    answer:
      "Se activa un intento de robo. Debe responder correctamente y alcanzar un tiempo igual o mejor que el récord defensivo del nodo.",
  },
  {
    question: "¿El prototipo funciona en celulares?",
    answer:
      "La interfaz está diseñada para adaptarse a escritorio y móvil. El objetivo del producto es ofrecer una experiencia multiplataforma para Android y iPhone.",
  },
];

export default function Home() {
  const [prototypeOpen, setPrototypeOpen] = useState(false);
  const [scrolled, setScrolled] = useState(false);
  const mainRef = useRef<HTMLElement>(null);

  useEffect(() => {
    document.body.style.overflow = prototypeOpen ? "hidden" : "";
    return () => {
      document.body.style.overflow = "";
    };
  }, [prototypeOpen]);

  useEffect(() => {
    const targets = document.querySelectorAll(
      ".reveal, .section-heading, .role-card, .faq-list details",
    );
    const observer = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (entry.isIntersecting) {
            entry.target.classList.add("is-visible");
            observer.unobserve(entry.target);
          }
        }
      },
      { threshold: 0.12, rootMargin: "0px 0px -10% 0px" },
    );
    targets.forEach((target, index) => {
      (target as HTMLElement).style.setProperty(
        "--reveal-delay",
        `${(index % 4) * 70}ms`,
      );
      observer.observe(target);
    });

    const updateScroll = () => {
      const max = Math.max(
        document.documentElement.scrollHeight - window.innerHeight,
        1,
      );
      mainRef.current?.style.setProperty(
        "--scroll-progress",
        `${(window.scrollY / max) * 100}%`,
      );
      setScrolled(window.scrollY > 36);
    };
    updateScroll();
    window.addEventListener("scroll", updateScroll, { passive: true });
    return () => {
      observer.disconnect();
      window.removeEventListener("scroll", updateScroll);
    };
  }, []);

  return (
    <main ref={mainRef}>
      <div className="scroll-progress" aria-hidden="true" />
      <div className="crt-layer" aria-hidden="true" />

      <header className={`site-header ${scrolled ? "is-scrolled" : ""}`}>
        <a aria-label="BattleGraph, inicio" className="brand" href="#inicio">
          <span className="brand-sigil"><i /><i /><i /></span>
          <strong>BATTLE<span>GRAF</span></strong>
        </a>
        <nav aria-label="Navegación principal">
          <a href="#proyecto">PROYECTO</a>
          <a href="#ecosistema">COLEGIO</a>
          <a href="#batalla">BATALLA</a>
          <a href="#ia">IA DOCENTE</a>
          <a href="#faq">FAQ</a>
        </nav>
        <button
          className="header-demo"
          onClick={() => setPrototypeOpen(true)}
          type="button"
        >
          JUGAR DEMO
        </button>
      </header>

      <section className="hero" id="inicio">
        <div className="pixel-sparks" aria-hidden="true">
          {Array.from({ length: 20 }).map((_, index) => (
            <i
              key={index}
              style={
                {
                  "--spark-x": `${(index * 43 + 5) % 100}%`,
                  "--spark-y": `${(index * 29 + 11) % 100}%`,
                  "--spark-delay": `${index * -0.31}s`,
                  "--spark-duration": `${4.8 + (index % 5) * 0.8}s`,
                } as React.CSSProperties
              }
            />
          ))}
        </div>
        <div className="hero-copy">
          <span className="eyebrow">PLATAFORMA ESCOLAR MULTIJUGADOR</span>
          <h1>
            <span>BATTLE</span>
            <strong>GRAF</strong>
          </h1>
          <p className="hero-tagline">APRENDER ES CONQUISTAR</p>
          <p className="hero-description">
            El contenido de clase se convierte en un mapa estratégico. Dos
            estudiantes avanzan por turnos, responden retos y conquistan torres
            hasta alcanzar la fortaleza rival.
          </p>
          <div className="hero-actions">
            <button
              className="button-primary"
              onClick={() => setPrototypeOpen(true)}
              type="button"
            >
              INICIAR BATALLA
              <span aria-hidden="true">01</span>
            </button>
            <a
              className="button-download"
              download
              href="/downloads/battlegraf-prototipo.apk"
            >
              DESCARGAR ANDROID
            </a>
          </div>
          <div className="hero-protocol">
            <span>ROJO JUEGA PRIMERO</span>
            <i aria-hidden="true" />
            <span>MORADO RESPONDE</span>
          </div>
        </div>
        <HeroBattlefield onPlay={() => setPrototypeOpen(true)} />
        <a className="scroll-cue" href="#proyecto">
          <span>EXPLORAR SISTEMA</span>
          <i aria-hidden="true" />
        </a>
      </section>

      <section className="intel-strip" aria-label="Datos clave de BattleGraph">
        <div><strong>1 VS 1</strong><span>BATALLA POR TURNOS</span></div>
        <div><strong>04+</strong><span>CAPAS POR GRAFO</span></div>
        <div><strong>03–04</strong><span>NODOS POR CAPA</span></div>
        <div><strong>100</strong><span>PREGUNTAS POR MATERIA</span></div>
        <div><strong>30 S</strong><span>TIEMPO POR TURNO</span></div>
      </section>

      <section className="section section-project" id="proyecto">
        <div className="section-shell">
          <div className="section-heading">
            <span className="eyebrow">01 / MISIÓN</span>
            <h2>UN QUIZ ENTREGA UN PUNTAJE. BATTLEGRAF CAMBIA EL MAPA.</h2>
            <p>
              Cada respuesta es una decisión espacial: abre una ruta, defiende
              un récord o conquista territorio. La misma partida produce
              evidencia útil para el estudiante y para el docente.
            </p>
          </div>
          <div className="mission-grid">
            <article className="mission-card mission-card-main reveal">
              <span className="card-code">BG_CORE_01</span>
              <h3>EL GRAFO CUMPLE TRES MISIONES</h3>
              <div className="mission-functions">
                <p><b>01</b><span>Tablero estratégico de la batalla.</span></p>
                <p><b>02</b><span>Progreso visible del estudiante.</span></p>
                <p><b>03</b><span>Evidencia por materia, nodo y tiempo.</span></p>
              </div>
            </article>
            <article className="pixel-panel reveal">
              <span className="panel-index">A</span>
              <h3>COMPETENCIA CON PROPÓSITO</h3>
              <p>Los retos nacen del material real que valida cada docente.</p>
            </article>
            <article className="pixel-panel reveal">
              <span className="panel-index">B</span>
              <h3>ESTRATEGIA VISIBLE</h3>
              <p>No basta acertar: hay que elegir una ruta y administrar el turno.</p>
            </article>
            <article className="pixel-panel reveal">
              <span className="panel-index">C</span>
              <h3>DATOS ACCIONABLES</h3>
              <p>El colegio detecta fortalezas y contenidos que requieren refuerzo.</p>
            </article>
          </div>
        </div>
      </section>

      <section className="section section-ecosystem" id="ecosistema">
        <div className="section-shell">
          <div className="section-heading">
            <span className="eyebrow">02 / ENTIDAD COLEGIO</span>
            <h2>UN SISTEMA PARA TODAS LAS AULAS, NO UNA PARTIDA AISLADA.</h2>
            <p>
              La institución se registra como entidad raíz y desde allí organiza
              sus niveles, secciones, materias, credenciales, permisos, rangos y clanes.
            </p>
          </div>

          <div className="school-console reveal">
            <div className="school-console-head">
              <span>COLEGIO / CONFIGURACIÓN INICIAL</span>
              <strong>ESTADO: OPERATIVO</strong>
            </div>
            <div className="school-flow">
              {[
                ["01", "CREA EL COLEGIO", "Nombre, código, niveles y reglas institucionales."],
                ["02", "ABRE SECCIONES", "5.º A, 6.º A, 6.º B y todas las aulas necesarias."],
                ["03", "HABILITA MATERIAS", "Cada curso define color, banco y nodos del grafo."],
                ["04", "ASIGNA PERSONAS", "Usuarios, credenciales, permisos, tutorías y docentes."],
              ].map(([number, title, copy]) => (
                <article key={number}>
                  <span>{number}</span>
                  <div><h3>{title}</h3><p>{copy}</p></div>
                  <i aria-hidden="true" />
                </article>
              ))}
            </div>
            <div className="section-versus">
              <div><small>COMPETENCIA INTERNA</small><strong>6.º A VS 6.º A</strong></div>
              <span>O</span>
              <div><small>ENTRE SECCIONES</small><strong>6.º A VS 6.º B</strong></div>
            </div>
          </div>

          <div className="roles-heading reveal">
            <span>JERARQUÍA DE ACCESO</span>
            <p>Cada rol ve únicamente el territorio educativo que le corresponde.</p>
          </div>
          <div className="roles-grid">
            {roles.map((role) => (
              <article className="role-card" key={role.code}>
                <span className="role-code">{role.code}</span>
                <small>{role.scope}</small>
                <h3>{role.title}</h3>
                <p>{role.copy}</p>
              </article>
            ))}
          </div>
        </div>
      </section>

      <section className="section section-flow" id="ia">
        <div className="section-shell">
          <div className="section-heading">
            <span className="eyebrow">03 / IA BAJO CONTROL DOCENTE</span>
            <h2>DEL MATERIAL DE CLASE A UN BANCO REUTILIZABLE.</h2>
            <p>
              La IA acelera el trabajo mecánico; el docente conserva la decisión
              pedagógica. Ninguna pregunta entra al juego sin aprobación.
            </p>
          </div>
          <div className="pipeline reveal">
            {[
              ["01", "SUBIR", "PDF · PPT · DOCX · TXT · IMG", "El profesor carga material de su materia."],
              ["02", "EXTRAER", "TEXTO ESTRUCTURADO", "El sistema recupera el contenido legible."],
              ["03", "GENERAR", "AGENTE DE PREGUNTAS", "Se crean alternativas, respuesta y explicación."],
              ["04", "REVISAR", "CONTROL DOCENTE", "El profesor aprueba, corrige o descarta."],
              ["05", "ROTAR", "5 RETOS POR NODO", "El banco distribuye preguntas sin regenerarlas."],
            ].map(([number, title, meta, copy]) => (
              <article key={number}>
                <span className="pipeline-number">{number}</span>
                <div className="pipeline-node"><i /><i /></div>
                <small>{meta}</small>
                <h3>{title}</h3>
                <p>{copy}</p>
              </article>
            ))}
          </div>
          <div className="bank-console reveal">
            <div>
              <span>BANCO / MATEMÁTICA</span>
              <strong>100 PREGUNTAS</strong>
            </div>
            <div className="bank-meter">
              <span style={{ width: "84%" }} />
            </div>
            <ul>
              <li><i className="status-approved" />84 APROBADAS</li>
              <li><i className="status-review" />12 EN REVISIÓN</li>
              <li><i className="status-draft" />04 BORRADORES</li>
            </ul>
            <p>
              Generar por lote y reutilizar el banco reduce llamadas repetidas al
              agente. El contador de uso permite rotar el contenido.
            </p>
          </div>
        </div>
      </section>

      <section className="section section-battle" id="batalla">
        <div className="section-shell">
          <div className="section-heading">
            <span className="eyebrow">04 / PROTOCOLO DE BATALLA</span>
            <h2>ROJO AVANZA. MORADO RESPONDE. CADA TURNO CAMBIA EL FRENTE.</h2>
            <p>
              Los jugadores parten en extremos opuestos. Solo pueden elegir nodos
              conectados a su posición o territorio conquistado.
            </p>
          </div>
          <div className="turn-protocol reveal">
            <div className="turn-track">
              {[
                ["01", "RUTA", "Se iluminan únicamente los hexágonos accesibles."],
                ["02", "RETO", "El jugador responde dentro de 30 segundos."],
                ["03", "NODO", "Acierta y conquista; falla y pierde el turno."],
                ["04", "CAMBIO", "El rival toma el control desde el otro extremo."],
              ].map(([number, title, copy], index) => (
                <article key={number}>
                  <span className={index % 2 === 0 ? "red-step" : "violet-step"}>
                    {number}
                  </span>
                  <h3>{title}</h3>
                  <p>{copy}</p>
                </article>
              ))}
            </div>
            <div className="battle-rules">
              <article>
                <span>RUTA OBLIGATORIA</span>
                <h3>NO HAY SALTOS ENTRE TORRES.</h3>
                <p>Una conexión visible es una regla de movimiento, no decoración.</p>
              </article>
              <article>
                <span>ROBO POR VELOCIDAD</span>
                <h3>RESPONDER BIEN PUEDE NO SER SUFICIENTE.</h3>
                <p>Para robar un nodo rival hay que igualar o mejorar su mejor tiempo.</p>
              </article>
              <article>
                <span>CONDICIÓN DE VICTORIA</span>
                <h3>ALCANZA LA FORTALEZA RIVAL.</h3>
                <p>También puede definirse una victoria por mayoría territorial.</p>
              </article>
            </div>
          </div>
          <div className="battle-cta reveal">
            <div><span>DEMO LOCAL / DOS JUGADORES</span><strong>PRUEBA EL TURNO ROJO → MORADO</strong></div>
            <button onClick={() => setPrototypeOpen(true)} type="button">
              ABRIR DEMO JUGABLE
            </button>
          </div>
        </div>
      </section>

      <section className="section section-progress">
        <div className="section-shell">
          <div className="section-heading">
            <span className="eyebrow">05 / PROGRESIÓN</span>
            <h2>CADA BATALLA Y CADA TAREA DEJAN HUELLA.</h2>
            <p>
              El colegio configura sus propios rangos. La experiencia puede
              obtenerse compitiendo o completando actividades académicas.
            </p>
          </div>
          <div className="progress-grid">
            <article className="rank-console reveal">
              <div className="rank-emblem"><span>IV</span><i /><i /><i /></div>
              <div>
                <small>RANGO ACTUAL</small>
                <h3>ESTRATEGA IV</h3>
                <div className="xp-bar"><span style={{ width: "72%" }} /></div>
                <p>2 840 / 4 000 XP PARA EL SIGUIENTE RANGO</p>
              </div>
            </article>
            <article className="progress-card reveal">
              <span>XP</span>
              <h3>Fuentes de experiencia</h3>
              <ul>
                <li>Responder y conquistar nodos</li>
                <li>Ganar batallas y lograr robos</li>
                <li>Completar tareas del docente</li>
              </ul>
            </article>
            <article className="progress-card reveal">
              <span>CLAN</span>
              <h3>Equipos dentro del aula</h3>
              <ul>
                <li>Cada clan pertenece a una sección</li>
                <li>Las victorias suman al puntaje grupal</li>
                <li>Ranking visible para el aula</li>
              </ul>
            </article>
            <article className="progress-card reveal">
              <span>TAREA</span>
              <h3>Más allá de alternativas</h3>
              <ul>
                <li>Preguntas de opción múltiple</li>
                <li>Respuestas abiertas</li>
                <li>Entrega de documentos o archivos</li>
              </ul>
            </article>
          </div>
        </div>
      </section>

      <section className="section section-faq" id="faq">
        <div className="section-shell faq-shell">
          <div className="section-heading">
            <span className="eyebrow">06 / PREGUNTAS FRECUENTES</span>
            <h2>ANTES DE ENTRAR A LA BATALLA.</h2>
          </div>
          <div className="faq-list">
            {faqs.map((faq, index) => (
              <details key={faq.question}>
                <summary>
                  <span>{String(index + 1).padStart(2, "0")}</span>
                  {faq.question}
                  <i aria-hidden="true" />
                </summary>
                <p>{faq.answer}</p>
              </details>
            ))}
          </div>
        </div>
      </section>

      <section className="final-cta">
        <div className="final-castle final-castle-red" aria-hidden="true">
          <PixelCastle player="red" />
        </div>
        <div className="final-content reveal">
          <span className="eyebrow">EL MAPA ESTÁ LISTO</span>
          <h2>CONVIERTE TU AULA EN TERRITORIO DE APRENDIZAJE.</h2>
          <p>
            Explora el prototipo por turnos o descarga la versión disponible para Android.
          </p>
          <div>
            <button onClick={() => setPrototypeOpen(true)} type="button">
              JUGAR EN EL NAVEGADOR
            </button>
            <a download href="/downloads/battlegraf-prototipo.apk">
              DESCARGAR PARA ANDROID
            </a>
          </div>
        </div>
        <div className="final-castle final-castle-violet" aria-hidden="true">
          <PixelCastle player="violet" />
        </div>
      </section>

      <footer>
        <a aria-label="BattleGraph, volver al inicio" className="brand" href="#inicio">
          <span className="brand-sigil"><i /><i /><i /></span>
          <strong>BATTLE<span>GRAF</span></strong>
        </a>
        <p>Hackathon en Tecnologías Digitales del Minedu 2026 · Categoría A</p>
        <span>ODS 4 · EDUCACIÓN DE CALIDAD</span>
      </footer>

      {prototypeOpen && (
        <PrototypeModal onClose={() => setPrototypeOpen(false)} />
      )}
    </main>
  );
}
