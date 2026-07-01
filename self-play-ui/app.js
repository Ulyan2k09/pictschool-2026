const state = {
  backendUrl: "http://localhost:8080",
  round: null,
  events: [],
  queue: [],
  source: null,
};

const els = {
  backendUrl: document.getElementById("backendUrl"),
  connectButton: document.getElementById("connectButton"),
  startButton: document.getElementById("startButton"),
  refreshButton: document.getElementById("refreshButton"),
  connectionStatus: document.getElementById("connectionStatus"),
  turnNumber: document.getElementById("turnNumber"),
  activeActor: document.getElementById("activeActor"),
  robotScore: document.getElementById("robotScore"),
  agentScore: document.getElementById("agentScore"),
  ducksLeft: document.getElementById("ducksLeft"),
  robotState: document.getElementById("robotState"),
  agentState: document.getElementById("agentState"),
  board: document.getElementById("board"),
  commandCount: document.getElementById("commandCount"),
  commandList: document.getElementById("commandList"),
  undoButton: document.getElementById("undoButton"),
  clearButton: document.getElementById("clearButton"),
  submitButton: document.getElementById("submitButton"),
  messageBox: document.getElementById("messageBox"),
  eventLog: document.getElementById("eventLog"),
};

const commandLabels = {
  1: "F",
  2: "B",
  3: "L",
  4: "R",
};

function api(path, options = {}) {
  return fetch(`${state.backendUrl}${path}`, {
    ...options,
    headers: {
      "Content-Type": "application/json",
      ...(options.headers || {}),
    },
  }).then(async (response) => {
    const text = await response.text();
    const payload = text ? JSON.parse(text) : {};
    if (!response.ok) {
      throw payload;
    }
    return payload;
  });
}

function setMessage(text, kind = "") {
  els.messageBox.textContent = text;
  els.messageBox.className = `message-box ${kind}`.trim();
}

function actorLine(actor) {
  if (!state.round) return "-";
  const current = state.round.actors[actor];
  return `(${current.position.x},${current.position.y}) ${current.direction}`;
}

function samePosition(left, right) {
  return left.x === right.x && left.y === right.y;
}

function cellContent(x, y) {
  const position = { x, y };
  const actors = state.round.actors;
  if (samePosition(actors.robot.position, position)) {
    return { type: "robot", label: `R${actors.robot.direction}` };
  }
  if (samePosition(actors.agent.position, position)) {
    return { type: "agent", label: `A${actors.agent.direction}` };
  }
  const obstacle = state.round.field.obstacles.find((item) => samePosition(item.position, position));
  if (obstacle) {
    return { type: "wall", label: "#" };
  }
  const duck = state.round.field.ducks.find((item) => !item.collectedBy && samePosition(item.position, position));
  if (duck) {
    return { type: "duck", label: "D" };
  }
  return null;
}

function renderBoard() {
  els.board.innerHTML = "";
  if (!state.round) return;

  const { width, height } = state.round.field;
  els.board.style.gridTemplateColumns = `repeat(${width}, minmax(36px, 1fr))`;
  els.board.style.gridTemplateRows = `repeat(${height}, minmax(36px, 1fr))`;
  els.board.style.aspectRatio = `${width} / ${height}`;

  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) {
      const cell = document.createElement("div");
      const content = cellContent(x, y);
      cell.className = `cell ${content?.type === "wall" ? "wall" : ""}`.trim();

      const coord = document.createElement("span");
      coord.className = "cell-coord";
      coord.textContent = `${x},${y}`;
      cell.append(coord);

      if (content) {
        const piece = document.createElement("span");
        piece.className = `piece ${content.type === "wall" ? "wall-mark" : content.type}`;
        piece.textContent = content.label;
        cell.append(piece);
      }
      els.board.append(cell);
    }
  }
}

function renderQueue() {
  els.commandCount.textContent = `${state.queue.length} / 5`;
  els.commandList.innerHTML = "";
  state.queue.forEach((command) => {
    const chip = document.createElement("span");
    chip.className = "command-chip";
    chip.textContent = commandLabels[command];
    els.commandList.append(chip);
  });
  els.submitButton.disabled = state.queue.length === 0 || !state.round || state.round.status !== "running";
  els.undoButton.disabled = state.queue.length === 0;
  els.clearButton.disabled = state.queue.length === 0;
}

function renderEvents() {
  els.eventLog.innerHTML = "";
  state.events.slice(-40).reverse().forEach((event) => {
    const item = document.createElement("li");
    const type = document.createElement("span");
    type.className = "event-type";
    type.textContent = event.type;
    const meta = document.createElement("span");
    meta.className = "event-meta";
    meta.textContent = `turn ${event.turnNumber}${event.actor ? `, ${event.actor}` : ""}`;
    item.append(type, meta);
    els.eventLog.append(item);
  });
}

function render() {
  if (!state.round) {
    els.turnNumber.textContent = "-";
    els.activeActor.textContent = "-";
    els.ducksLeft.textContent = "-";
    els.board.innerHTML = "";
    renderQueue();
    renderEvents();
    return;
  }

  els.turnNumber.textContent = state.round.turnNumber;
  els.activeActor.textContent = state.round.activeActor;
  els.robotScore.textContent = state.round.score.robot;
  els.agentScore.textContent = state.round.score.agent;
  els.ducksLeft.textContent = `${state.round.ducksLeft}/${state.round.ducksTotal}`;
  els.robotState.textContent = actorLine("robot");
  els.agentState.textContent = actorLine("agent");

  document.querySelector(".actor.robot").classList.toggle("active", state.round.activeActor === "robot");
  document.querySelector(".actor.agent").classList.toggle("active", state.round.activeActor === "agent");

  renderBoard();
  renderQueue();
  renderEvents();
}

async function refreshRound() {
  const payload = await api("/api/round");
  state.round = payload.round;
  render();
}

async function refreshEvents() {
  const payload = await api("/api/events");
  state.events = payload.events;
  renderEvents();
}

function connectSse() {
  if (state.source) {
    state.source.close();
  }
  els.connectionStatus.textContent = "SSE connecting...";
  state.source = new EventSource(`${state.backendUrl}/api/live`);
  state.source.onopen = () => {
    els.connectionStatus.textContent = "SSE connected";
  };
  state.source.onerror = () => {
    els.connectionStatus.textContent = "SSE disconnected";
  };
  state.source.onmessage = (event) => {
    const parsed = JSON.parse(event.data);
    state.events.push(parsed);
    refreshRound().catch((error) => setMessage(error.error?.message || String(error), "bad"));
    renderEvents();
  };
  [
    "round.started",
    "turn.submitted",
    "simulation.command_sent",
    "actor.moved",
    "duck.collected",
    "turn.completed",
    "turn.failed",
    "round.completed",
    "round.reset",
  ].forEach((eventName) => {
    state.source.addEventListener(eventName, (event) => {
      const parsed = JSON.parse(event.data);
      state.events.push(parsed);
      refreshRound().catch((error) => setMessage(error.error?.message || String(error), "bad"));
      renderEvents();
    });
  });
}

async function connect() {
  state.backendUrl = els.backendUrl.value.replace(/\/$/, "");
  connectSse();
  await Promise.all([refreshRound(), refreshEvents()]);
  setMessage("Connected", "ok");
}

async function startRound() {
  await api("/api/round/start", {
    method: "POST",
    body: JSON.stringify({ scenarioId: "default" }),
  });
  state.queue = [];
  await Promise.all([refreshRound(), refreshEvents()]);
  setMessage("New round started", "ok");
}

async function submitTurn() {
  if (!state.round || state.queue.length === 0) return;
  const actor = state.round.activeActor;
  try {
    const response = await api("/api/turn/submit", {
      method: "POST",
      body: JSON.stringify({ actor, commands: state.queue }),
    });
    state.queue = [];
    await Promise.all([refreshRound(), refreshEvents()]);
    setMessage(`Submitted ${response.forwardedAs}`, "ok");
  } catch (error) {
    setMessage(error.error?.message || String(error), "bad");
  }
  render();
}

document.querySelectorAll("[data-command]").forEach((button) => {
  button.addEventListener("click", () => {
    if (state.queue.length >= 5) {
      setMessage("Move limit is 5 commands", "bad");
      return;
    }
    state.queue.push(Number(button.dataset.command));
    setMessage("");
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

els.submitButton.addEventListener("click", submitTurn);
els.connectButton.addEventListener("click", () => connect().catch((error) => setMessage(error.error?.message || String(error), "bad")));
els.startButton.addEventListener("click", () => startRound().catch((error) => setMessage(error.error?.message || String(error), "bad")));
els.refreshButton.addEventListener("click", () => Promise.all([refreshRound(), refreshEvents()]));

connect().catch((error) => {
  els.connectionStatus.textContent = "Backend unavailable";
  setMessage(error.error?.message || "Start backend and simulation emulator first", "bad");
  render();
});
