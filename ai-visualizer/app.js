const state = {
  backendUrl: `${window.location.protocol}//${window.location.hostname}:8080`,
  round: null,
  events: [],
  queue: [],
  source: null,
  pollTimer: null,
};

const els = {
  backendUrl: document.getElementById("backendUrl"),
  connectButton: document.getElementById("connectButton"),
  startRoundButton: document.getElementById("startRoundButton"),
  status: document.getElementById("status"),
  turnNumber: document.getElementById("turnNumber"),
  activeActor: document.getElementById("activeActor"),
  robotScore: document.getElementById("robotScore"),
  agentScore: document.getElementById("agentScore"),
  ducksLeft: document.getElementById("ducksLeft"),
  board: document.getElementById("board"),
  queue: document.getElementById("queue"),
  undoButton: document.getElementById("undoButton"),
  clearButton: document.getElementById("clearButton"),
  submitButton: document.getElementById("submitButton"),
  eventLog: document.getElementById("eventLog"),
  moveLog: document.getElementById("moveLog"),
};

els.backendUrl.value = state.backendUrl;

function api(path, options = {}) {
  return fetch(`${state.backendUrl}${path}`, {
    headers: { "Content-Type": "application/json", ...(options.headers || {}) },
    ...options,
  }).then(async (response) => {
    const text = await response.text();
    const payload = text ? JSON.parse(text) : {};
    if (!response.ok) {
      throw payload;
    }
    return payload;
  });
}

function renderSummary() {
  if (!state.round) {
    els.turnNumber.textContent = "-";
    els.activeActor.textContent = "-";
    els.robotScore.textContent = "0";
    els.agentScore.textContent = "0";
    els.ducksLeft.textContent = "-";
    return;
  }
  els.turnNumber.textContent = String(state.round.turnNumber);
  els.activeActor.textContent = state.round.activeActor;
  els.robotScore.textContent = String(state.round.score.robot);
  els.agentScore.textContent = String(state.round.score.agent);
  els.ducksLeft.textContent = `${state.round.ducksLeft}/${state.round.ducksTotal}`;
}

function samePosition(a, b) {
  return a.x === b.x && a.y === b.y;
}

function renderBoard() {
  els.board.innerHTML = "";
  if (!state.round) return;
  const { width, height, ducks, obstacles } = state.round.field;
  els.board.style.gridTemplateColumns = `repeat(${width}, minmax(34px, 1fr))`;
  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) {
      const cell = document.createElement("div");
      cell.className = "cell";
      let mark = "";
      const pos = { x, y };
      const robot = state.round.actors.robot;
      const agent = state.round.actors.agent;
      if (samePosition(robot.position, pos)) {
        mark = `R${robot.direction}`;
      } else if (samePosition(agent.position, pos)) {
        mark = `A${agent.direction}`;
      } else if (obstacles.some((o) => samePosition(o.position, pos))) {
        mark = "#";
      } else if (ducks.some((d) => !d.collectedBy && samePosition(d.position, pos))) {
        mark = "D";
      }
      cell.textContent = mark;
      els.board.append(cell);
    }
  }
}

const commandLabels = {
  1: "F",
  2: "B",
  3: "L",
  4: "R",
  10: "F2",
  11: "U",
  12: "SR",
  13: "SL",
};

function renderQueue() {
  els.queue.innerHTML = "";
  state.queue.forEach((command) => {
    const chip = document.createElement("span");
    chip.className = "chip";
    chip.textContent = commandLabels[command] || command;
    els.queue.append(chip);
  });
  const robotTurn = state.round?.status === "running" && state.round.activeActor === "robot";
  els.submitButton.disabled = !robotTurn || state.queue.length === 0;
}

function renderEvents() {
  els.eventLog.innerHTML = "";
  state.events
    .slice(-40)
    .reverse()
    .forEach((event) => {
      const li = document.createElement("li");
      li.textContent = `${event.type} (turn ${event.turnNumber}${event.actor ? `, ${event.actor}` : ""})`;
      els.eventLog.append(li);
    });
}

function renderMoves() {
  els.moveLog.innerHTML = "";

  const commandsByTurnAndActor = new Map();
  state.events.forEach((event) => {
    if (event.type === "turn.submitted" && event.actor) {
      commandsByTurnAndActor.set(`${event.turnNumber}:${event.actor}`, event.payload?.commands || "-");
    }
  });

  state.events
    .filter((event) => event.type === "actor.moved" && event.actor)
    .slice(-40)
    .reverse()
    .forEach((event) => {
      const li = document.createElement("li");
      const payload = event.payload || {};
      const pos = payload.finalPosition || {};
      const direction = payload.finalDirection || "?";
      const commands = commandsByTurnAndActor.get(`${event.turnNumber}:${event.actor}`) || "-";
      li.textContent =
        `turn ${event.turnNumber}, ${event.actor}: ` +
        `to (${pos.x ?? "?"}, ${pos.y ?? "?"}), dir=${direction}, commands=${commands}`;
      els.moveLog.append(li);
    });
}

function renderAll() {
  renderSummary();
  renderBoard();
  renderQueue();
  renderEvents();
  renderMoves();
}

async function refreshState() {
  const [roundPayload, eventsPayload] = await Promise.all([api("/api/round"), api("/api/events")]);
  state.round = roundPayload.round;
  state.events = eventsPayload.events || [];
  renderAll();
}

function connectSse() {
  if (state.source) state.source.close();
  state.source = new EventSource(`${state.backendUrl}/api/live`);
  state.source.onopen = () => {
    els.status.textContent = "SSE connected";
  };
  state.source.onerror = () => {
    els.status.textContent = "SSE disconnected";
  };
  state.source.onmessage = () => {
    refreshState().catch((error) => {
      els.status.textContent = error?.error?.message || "Refresh error";
    });
  };
}

function startPolling() {
  if (state.pollTimer) {
    clearInterval(state.pollTimer);
  }
  state.pollTimer = setInterval(() => {
    refreshState().catch(() => {});
  }, 1500);
}

async function connect() {
  state.backendUrl = els.backendUrl.value.replace(/\/$/, "");
  await refreshState();
  connectSse();
  startPolling();
  els.status.textContent = "Connected";
}

async function startRound() {
  await api("/api/round/start", {
    method: "POST",
    body: JSON.stringify({ scenarioId: "default" }),
  });
  state.queue = [];
  await refreshState();
}

async function submitRobotTurn() {
  if (state.queue.length === 0) return;
  await api("/api/turn/submit", {
    method: "POST",
    body: JSON.stringify({ actor: "robot", commands: state.queue }),
  });
  state.queue = [];
  await refreshState();
}

document.querySelectorAll("[data-command]").forEach((button) => {
  button.addEventListener("click", () => {
    if (state.queue.length >= 5) return;
    state.queue.push(Number(button.dataset.command));
    renderQueue();
  });
});

els.undoButton.addEventListener("click", () => {
  state.queue.pop();
  renderQueue();
});
els.clearButton.addEventListener("click", () => {
  state.queue = [];
  renderQueue();
});
els.submitButton.addEventListener("click", () => {
  submitRobotTurn().catch((error) => {
    els.status.textContent = error?.error?.message || "Submit error";
  });
});
els.connectButton.addEventListener("click", () => {
  connect().catch((error) => {
    els.status.textContent = error?.error?.message || "Connect error";
  });
});
els.startRoundButton.addEventListener("click", () => {
  startRound().catch((error) => {
    els.status.textContent = error?.error?.message || "Start round error";
  });
});

connect().catch(() => {
  els.status.textContent = "Start backend stack first";
});
