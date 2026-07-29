export type PlayerId = "red" | "violet";

export type Subject =
  | "math"
  | "communication"
  | "science"
  | "history"
  | "art"
  | "base";

export type BattleNode = {
  id: string;
  label: string;
  shortLabel: string;
  subject: Subject;
  x: number;
  y: number;
  baseFor?: PlayerId;
};

export type Question = {
  text: string;
  options: string[];
  answer: number;
};

export type CaptureRecord = {
  owner: PlayerId;
  bestTimeMs: number;
};

export type LastMove = {
  from: string;
  to: string;
  player: PlayerId;
  result: "move" | "capture" | "steal" | "blocked";
};

export type BattleState = {
  currentPlayer: PlayerId;
  turnNumber: number;
  remainingSeconds: number;
  positions: Record<PlayerId, string>;
  owners: Record<string, PlayerId | null>;
  records: Record<string, CaptureRecord | undefined>;
  targetId: string | null;
  attempts: Record<PlayerId, number>;
  message: string;
  messageTone: "info" | "success" | "danger";
  lastMove: LastMove | null;
  winner: PlayerId | null;
};

export type BattleAction =
  | { type: "SELECT_NODE"; nodeId: string }
  | { type: "ANSWER"; optionIndex: number; responseTimeMs: number }
  | { type: "TICK" }
  | { type: "RESET" };

export const battleNodes: BattleNode[] = [
  {
    id: "alpha",
    label: "Fortaleza Roja",
    shortLabel: "BASE R",
    subject: "base",
    x: 7,
    y: 76,
    baseFor: "red",
  },
  {
    id: "m1",
    label: "Academia Matemática",
    shortLabel: "MAT",
    subject: "math",
    x: 24,
    y: 62,
  },
  {
    id: "c1",
    label: "Torre de Comunicación",
    shortLabel: "COM",
    subject: "communication",
    x: 31,
    y: 86,
  },
  {
    id: "s1",
    label: "Laboratorio de Ciencia",
    shortLabel: "CIE",
    subject: "science",
    x: 43,
    y: 43,
  },
  {
    id: "h1",
    label: "Archivo de Historia",
    shortLabel: "HIS",
    subject: "history",
    x: 47,
    y: 69,
  },
  {
    id: "a1",
    label: "Taller de Arte",
    shortLabel: "ART",
    subject: "art",
    x: 53,
    y: 91,
  },
  {
    id: "c2",
    label: "Torre de Comunicación",
    shortLabel: "COM",
    subject: "communication",
    x: 65,
    y: 38,
  },
  {
    id: "s2",
    label: "Laboratorio de Ciencia",
    shortLabel: "CIE",
    subject: "science",
    x: 69,
    y: 68,
  },
  {
    id: "omega",
    label: "Fortaleza Morada",
    shortLabel: "BASE M",
    subject: "base",
    x: 92,
    y: 20,
    baseFor: "violet",
  },
];

export const battleEdges: [string, string][] = [
  ["alpha", "m1"],
  ["alpha", "c1"],
  ["m1", "s1"],
  ["m1", "h1"],
  ["c1", "h1"],
  ["c1", "a1"],
  ["s1", "c2"],
  ["s1", "h1"],
  ["h1", "c2"],
  ["h1", "s2"],
  ["a1", "s2"],
  ["c2", "omega"],
  ["s2", "omega"],
];

export const subjectLabels: Record<Subject, string> = {
  math: "Matemática",
  communication: "Comunicación",
  science: "Ciencia",
  history: "Historia",
  art: "Arte",
  base: "Desafío final",
};

export const questions: Record<Subject, Question[]> = {
  math: [
    {
      text: "Si 3 cuadernos cuestan S/ 18, ¿cuánto cuestan 5 cuadernos?",
      options: ["S/ 24", "S/ 30", "S/ 32", "S/ 36"],
      answer: 1,
    },
    {
      text: "¿Cuál es el resultado de 48 ÷ 6 + 7?",
      options: ["13", "14", "15", "16"],
      answer: 2,
    },
  ],
  communication: [
    {
      text: "¿Cuál es el núcleo del sujeto en «Los alumnos resuelven el reto»?",
      options: ["Los", "alumnos", "resuelven", "reto"],
      answer: 1,
    },
    {
      text: "¿Qué conector expresa una consecuencia?",
      options: ["Aunque", "Porque", "Por lo tanto", "Mientras"],
      answer: 2,
    },
  ],
  science: [
    {
      text: "¿Qué proceso permite a las plantas transformar la luz en energía?",
      options: ["Evaporación", "Respiración", "Fotosíntesis", "Condensación"],
      answer: 2,
    },
    {
      text: "¿En qué estado de la materia las partículas conservan forma propia?",
      options: ["Sólido", "Líquido", "Gas", "Plasma"],
      answer: 0,
    },
  ],
  history: [
    {
      text: "¿En qué cordillera se desarrolló principalmente el Tahuantinsuyo?",
      options: ["Alpes", "Andes", "Himalaya", "Pirineos"],
      answer: 1,
    },
    {
      text: "¿Qué ciudad fue la capital del Tahuantinsuyo?",
      options: ["Lima", "Quito", "Cusco", "Arequipa"],
      answer: 2,
    },
  ],
  art: [
    {
      text: "¿Qué combinación forma un color secundario?",
      options: ["Rojo y azul", "Azul y blanco", "Rojo y blanco", "Negro y blanco"],
      answer: 0,
    },
    {
      text: "¿Qué recurso visual crea sensación de profundidad?",
      options: ["Ritmo", "Perspectiva", "Textura", "Simetría"],
      answer: 1,
    },
  ],
  base: [
    {
      text: "Desafío final: ¿qué acción protege mejor una fuente académica?",
      options: [
        "Copiar sin citar",
        "Cambiar el título",
        "Citar autor y procedencia",
        "Eliminar la fecha",
      ],
      answer: 2,
    },
    {
      text: "Desafío final: ¿qué evidencia permite validar un aprendizaje?",
      options: [
        "Solo el tiempo conectado",
        "Una respuesta explicada",
        "El color del perfil",
        "La cantidad de clics",
      ],
      answer: 1,
    },
  ],
};

export function otherPlayer(player: PlayerId): PlayerId {
  return player === "red" ? "violet" : "red";
}

export function getNode(nodeId: string): BattleNode | undefined {
  return battleNodes.find((node) => node.id === nodeId);
}

export function getNeighbors(nodeId: string): string[] {
  const result: string[] = [];
  for (const [from, to] of battleEdges) {
    if (from === nodeId) result.push(to);
    if (to === nodeId) result.push(from);
  }
  return result;
}

export function getAvailableNodes(state: BattleState): Set<string> {
  if (state.winner || state.targetId) return new Set();
  return new Set(getNeighbors(state.positions[state.currentPlayer]));
}

export function getQuestionForState(state: BattleState): Question | null {
  if (!state.targetId) return null;
  const node = getNode(state.targetId);
  if (!node) return null;
  const pool = questions[node.subject];
  const nodeIndex = battleNodes.findIndex((candidate) => candidate.id === node.id);
  return pool[(state.turnNumber + nodeIndex) % pool.length];
}

export function createInitialBattleState(): BattleState {
  return {
    currentPlayer: "red",
    turnNumber: 1,
    remainingSeconds: 30,
    positions: { red: "alpha", violet: "omega" },
    owners: Object.fromEntries(
      battleNodes.map((node) => [
        node.id,
        node.baseFor === "red"
          ? "red"
          : node.baseFor === "violet"
            ? "violet"
            : null,
      ]),
    ),
    records: {},
    targetId: null,
    attempts: { red: 0, violet: 0 },
    message: "Turno rojo: elige una torre conectada para abrir el primer reto.",
    messageTone: "info",
    lastMove: null,
    winner: null,
  };
}

function passTurn(
  state: BattleState,
  patch: Partial<BattleState>,
  message: string,
  messageTone: BattleState["messageTone"],
): BattleState {
  return {
    ...state,
    ...patch,
    currentPlayer: otherPlayer(state.currentPlayer),
    turnNumber: state.turnNumber + 1,
    remainingSeconds: 30,
    targetId: null,
    message,
    messageTone,
  };
}

export function battleReducer(
  state: BattleState,
  action: BattleAction,
): BattleState {
  if (action.type === "RESET") return createInitialBattleState();
  if (state.winner) return state;

  if (action.type === "TICK") {
    if (state.remainingSeconds > 1) {
      return { ...state, remainingSeconds: state.remainingSeconds - 1 };
    }
    const next = otherPlayer(state.currentPlayer);
    return passTurn(
      state,
      {},
      `Tiempo agotado. Ahora avanza el jugador ${next === "red" ? "rojo" : "morado"}.`,
      "danger",
    );
  }

  if (action.type === "SELECT_NODE") {
    if (state.targetId) return state;
    const node = getNode(action.nodeId);
    if (!node) return state;
    const currentPosition = state.positions[state.currentPlayer];
    const available = getNeighbors(currentPosition);
    if (!available.includes(node.id)) {
      return {
        ...state,
        message: "Movimiento bloqueado: solo puedes seguir una conexión iluminada.",
        messageTone: "danger",
      };
    }

    if (state.owners[node.id] === state.currentPlayer) {
      const next = otherPlayer(state.currentPlayer);
      return passTurn(
        state,
        {
          positions: { ...state.positions, [state.currentPlayer]: node.id },
          lastMove: {
            from: currentPosition,
            to: node.id,
            player: state.currentPlayer,
            result: "move",
          },
        },
        `Reagrupación completada. Turno del jugador ${next === "red" ? "rojo" : "morado"}.`,
        "info",
      );
    }

    const owner = state.owners[node.id];
    return {
      ...state,
      targetId: node.id,
      message:
        owner && owner !== state.currentPlayer
          ? "Intento de robo: responde correctamente y supera el mejor tiempo."
          : `Reto de ${subjectLabels[node.subject]}: conquista esta torre.`,
      messageTone: "info",
    };
  }

  if (action.type === "ANSWER") {
    if (!state.targetId) return state;
    const target = getNode(state.targetId);
    const question = getQuestionForState(state);
    if (!target || !question) return state;

    const player = state.currentPlayer;
    const opponent = otherPlayer(player);
    const currentPosition = state.positions[player];
    const attempts = {
      ...state.attempts,
      [player]: state.attempts[player] + 1,
    };
    const isCorrect = action.optionIndex === question.answer;

    if (!isCorrect) {
      return passTurn(
        state,
        { attempts },
        `Respuesta incorrecta. El turno pasa al jugador ${opponent === "red" ? "rojo" : "morado"}.`,
        "danger",
      );
    }

    const previousRecord = state.records[target.id];
    const isSteal =
      state.owners[target.id] !== null &&
      state.owners[target.id] !== player &&
      !target.baseFor;
    const stealSucceeded =
      !isSteal ||
      !previousRecord ||
      action.responseTimeMs <= previousRecord.bestTimeMs;

    if (!stealSucceeded) {
      return passTurn(
        state,
        {
          attempts,
          lastMove: {
            from: currentPosition,
            to: target.id,
            player,
            result: "blocked",
          },
        },
        `Respuesta correcta, pero ${(
          action.responseTimeMs / 1000
        ).toFixed(1)} s no supera el récord de ${(
          previousRecord!.bestTimeMs / 1000
        ).toFixed(1)} s. La torre resiste.`,
        "danger",
      );
    }

    const owners = { ...state.owners, [target.id]: player };
    const records = {
      ...state.records,
      [target.id]: { owner: player, bestTimeMs: action.responseTimeMs },
    };
    const positions = { ...state.positions, [player]: target.id };
    const reachedEnemyBase =
      (player === "red" && target.baseFor === "violet") ||
      (player === "violet" && target.baseFor === "red");

    if (reachedEnemyBase) {
      return {
        ...state,
        owners,
        records,
        positions,
        attempts,
        targetId: null,
        lastMove: {
          from: currentPosition,
          to: target.id,
          player,
          result: "capture",
        },
        winner: player,
        message: `La fortaleza rival cayó. Victoria del jugador ${player === "red" ? "rojo" : "morado"}.`,
        messageTone: "success",
      };
    }

    const result: LastMove["result"] = isSteal ? "steal" : "capture";
    return passTurn(
      state,
      {
        owners,
        records,
        positions,
        attempts,
        lastMove: { from: currentPosition, to: target.id, player, result },
      },
      isSteal
        ? `Torre robada en ${(action.responseTimeMs / 1000).toFixed(1)} s. Turno del jugador ${opponent === "red" ? "rojo" : "morado"}.`
        : `Torre conquistada en ${(action.responseTimeMs / 1000).toFixed(1)} s. Turno del jugador ${opponent === "red" ? "rojo" : "morado"}.`,
      "success",
    );
  }

  return state;
}
