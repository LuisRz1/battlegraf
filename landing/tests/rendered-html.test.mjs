import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import {
  battleReducer,
  createInitialBattleState,
  getAvailableNodes,
  getQuestionForState,
} from "../app/battle-engine.ts";

async function render() {
  const workerUrl = new URL("../dist/server/index.js", import.meta.url);
  workerUrl.searchParams.set("test", `${process.pid}-${Date.now()}`);
  const { default: worker } = await import(workerUrl.href);

  return worker.fetch(
    new Request("http://localhost/", {
      headers: { accept: "text/html" },
    }),
    {
      ASSETS: {
        fetch: async () => new Response("Not found", { status: 404 }),
      },
    },
    {
      waitUntil() {},
      passThroughOnException() {},
    },
  );
}

function answerCorrectly(state, responseTimeMs = 2400) {
  const question = getQuestionForState(state);
  assert.ok(question, "selected node should provide a question");
  return battleReducer(state, {
    type: "ANSWER",
    optionIndex: question.answer,
    responseTimeMs,
  });
}

test("server-renders the complete BattleGraf landing", async () => {
  const response = await render();
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);

  const html = await response.text();
  assert.match(html, /<title>BattleGraf \| Aprender es conquistar<\/title>/i);
  assert.match(html, /BATTLE/);
  assert.match(html, /GRAF/);
  assert.match(html, /APRENDER ES CONQUISTAR/);
  assert.match(html, /INICIAR BATALLA/);
  assert.match(html, /ENTIDAD COLEGIO/);
  assert.match(html, /IA BAJO CONTROL DOCENTE/);
  assert.match(html, /PROTOCOLO DE BATALLA/);
  assert.match(html, /PREGUNTAS FRECUENTES/);
  assert.match(html, /\/downloads\/battlegraf-prototipo\.apk/);
  assert.doesNotMatch(
    html,
    /battlegraf-keyart|battlefield-bg|codex-preview|react-loading-skeleton/i,
  );
});

test("uses CSS-built castles, hexagonal nodes and accessible game UI", async () => {
  const [page, engine, layout, css, packageJson] = await Promise.all([
    readFile(new URL("../app/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/battle-engine.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/layout.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/globals.css", import.meta.url), "utf8"),
    readFile(new URL("../package.json", import.meta.url), "utf8"),
  ]);

  assert.match(page, /function PixelCastle/);
  assert.match(page, /function AcademyTower/);
  assert.match(page, /function GraphConnections/);
  assert.match(page, /ResizeObserver/);
  assert.match(page, /aria-modal="true"/);
  assert.match(page, /aria-live="polite"/);
  assert.match(page, /role="timer"/);
  assert.match(page, /IntersectionObserver/);
  assert.match(page, /prefers-reduced-motion|prototypeOpen/);
  assert.doesNotMatch(page, /<img|battlegraf-keyart|battlefield-bg/i);
  assert.match(engine, /export function battleReducer/);
  assert.match(engine, /responseTimeMs <= previousRecord\.bestTimeMs/);
  assert.match(engine, /currentPlayer: otherPlayer/);
  assert.match(layout, /<html lang="es">/);
  assert.match(layout, /BattleGraf \| Aprender es conquistar/);
  assert.match(layout, /\/og\.png/);
  assert.match(css, /\.pixel-castle/);
  assert.match(css, /\.academy-tower/);
  assert.match(css, /\.map-node/);
  assert.match(css, /clip-path:\s*polygon\(24% 0,\s*76% 0/);
  assert.match(css, /\.connection-red/);
  assert.match(css, /\.connection-violet/);
  assert.match(css, /\.hud-turn/);
  assert.match(css, /prefers-reduced-motion:\s*reduce/);
  assert.doesNotMatch(css, /url\([\"']?\/(?:battlegraf-keyart|battlefield-bg)/i);
  assert.doesNotMatch(packageJson, /react-loading-skeleton/);
});

test("alternates a real red and violet turn across connected routes", () => {
  let state = createInitialBattleState();
  assert.equal(state.currentPlayer, "red");
  assert.equal(state.positions.red, "alpha");
  assert.equal(state.positions.violet, "omega");
  assert.deepEqual([...getAvailableNodes(state)].sort(), ["c1", "m1"]);

  state = battleReducer(state, { type: "SELECT_NODE", nodeId: "m1" });
  state = answerCorrectly(state, 4200);
  assert.equal(state.currentPlayer, "violet");
  assert.equal(state.positions.red, "m1");
  assert.equal(state.owners.m1, "red");
  assert.deepEqual([...getAvailableNodes(state)].sort(), ["c2", "s2"]);

  state = battleReducer(state, { type: "SELECT_NODE", nodeId: "s2" });
  state = answerCorrectly(state, 3800);
  assert.equal(state.currentPlayer, "red");
  assert.equal(state.positions.violet, "s2");
  assert.equal(state.owners.s2, "violet");
  assert.equal(state.turnNumber, 3);
});

test("blocks disconnected moves, switches on timeout and supports a timed steal", () => {
  let state = createInitialBattleState();
  state = battleReducer(state, { type: "SELECT_NODE", nodeId: "omega" });
  assert.equal(state.targetId, null);
  assert.match(state.message, /solo puedes seguir una conexión/i);

  state = battleReducer(state, { type: "SELECT_NODE", nodeId: "m1" });
  state = answerCorrectly(state, 5000);
  state = battleReducer(state, { type: "SELECT_NODE", nodeId: "s2" });
  state = answerCorrectly(state, 4500);
  state = battleReducer(state, { type: "SELECT_NODE", nodeId: "h1" });
  state = answerCorrectly(state, 3600);
  assert.equal(state.owners.h1, "red");
  assert.equal(state.currentPlayer, "violet");

  state = battleReducer(state, { type: "SELECT_NODE", nodeId: "h1" });
  state = answerCorrectly(state, 3300);
  assert.equal(state.owners.h1, "violet");
  assert.equal(state.lastMove?.result, "steal");
  assert.equal(state.currentPlayer, "red");

  const beforeTimeoutTurn = state.turnNumber;
  state = { ...state, remainingSeconds: 1 };
  state = battleReducer(state, { type: "TICK" });
  assert.equal(state.turnNumber, beforeTimeoutTurn + 1);
  assert.equal(state.currentPlayer, "violet");
  assert.equal(state.remainingSeconds, 30);
});
