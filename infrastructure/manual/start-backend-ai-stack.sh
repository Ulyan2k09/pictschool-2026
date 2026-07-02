#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AI_DIR="$ROOT_DIR/ai"
BACKEND_DIR="$ROOT_DIR/backend"
SIM_DIR="$ROOT_DIR/simulation-emulator"

if [[ -f "$AI_DIR/.env" ]]; then
  # shellcheck disable=SC1090
  set -a
  source "$AI_DIR/.env"
  set +a
fi

export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home}"
export PATH="/opt/homebrew/opt/openjdk@17/bin:$PATH"
export HTTP_HOST="${HTTP_HOST:-127.0.0.1}"
export HTTP_PORT="${HTTP_PORT:-8080}"
export AGENT_BACKEND_URL="${AGENT_BACKEND_URL:-http://127.0.0.1:8080}"

cleanup() {
  local exit_code=$?
  trap - INT TERM EXIT
  if [[ -n "${AGENT_PID:-}" ]]; then kill "$AGENT_PID" 2>/dev/null || true; fi
  if [[ -n "${BACKEND_PID:-}" ]]; then kill "$BACKEND_PID" 2>/dev/null || true; fi
  if [[ -n "${SIM_PID:-}" ]]; then kill "$SIM_PID" 2>/dev/null || true; fi
  wait 2>/dev/null || true
  exit "$exit_code"
}
trap cleanup INT TERM EXIT

echo "[stack] starting simulation emulator on 127.0.0.1:5055"
python3 "$SIM_DIR/tcp_emulator.py" --host 127.0.0.1 --port 5055 --agent-mode manual &
SIM_PID=$!

echo "[stack] starting backend on http://${HTTP_HOST}:${HTTP_PORT}"
(
  cd "$BACKEND_DIR"
  ./gradlew run
) &
BACKEND_PID=$!

echo "[stack] waiting for backend health"
for _ in {1..60}; do
  if curl -sf "http://${HTTP_HOST}:${HTTP_PORT}/api/round" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

if ! curl -sf "http://${HTTP_HOST}:${HTTP_PORT}/api/round" >/dev/null 2>&1; then
  echo "[stack] backend did not become ready in time"
  exit 1
fi

echo "[stack] starting AI agent"
(
  cd "$AI_DIR"
  if [[ ! -d ".venv" ]]; then
    python3 -m venv .venv
  fi
  # shellcheck disable=SC1091
  source .venv/bin/activate
  pip install -r requirements.txt >/dev/null
  python -m agent_service
) &
AGENT_PID=$!

echo "[stack] backend + simulation + agent are running"
echo "[stack] stop with Ctrl+C"
wait
