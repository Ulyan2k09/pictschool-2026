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

declare -a PYTHON_CMD=()
if command -v python3 >/dev/null 2>&1 && python3 -c "import sys" >/dev/null 2>&1; then
  PYTHON_CMD=(python3)
elif command -v python >/dev/null 2>&1 && python -c "import sys" >/dev/null 2>&1; then
  PYTHON_CMD=(python)
elif command -v py >/dev/null 2>&1 && py -3 -c "import sys" >/dev/null 2>&1; then
  PYTHON_CMD=(py -3)
else
  echo "[stack] python 3 not found (python3/python/py -3)." >&2
  exit 1
fi

if [[ -n "${JAVA_HOME:-}" ]] && [[ ! -d "$JAVA_HOME" ]]; then
  echo "[stack] ignoring invalid JAVA_HOME: $JAVA_HOME"
  unset JAVA_HOME
fi

if [[ -z "${JAVA_HOME:-}" ]]; then
  case "$(uname -s)" in
    Darwin)
      for candidate in \
        /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home \
        /usr/local/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
      do
        if [[ -d "$candidate" ]]; then
          export JAVA_HOME="$candidate"
          break
        fi
      done
      ;;
  esac
fi

if [[ -n "${JAVA_HOME:-}" ]] && [[ -d "$JAVA_HOME/bin" ]]; then
  export PATH="$JAVA_HOME/bin:$PATH"
fi

export HTTP_HOST="${HTTP_HOST:-127.0.0.1}"
export HTTP_PORT="${HTTP_PORT:-8080}"
export AGENT_BACKEND_URL="${AGENT_BACKEND_URL:-http://127.0.0.1:8080}"
export SIM_DRIVER="${SIM_DRIVER:-emulator}"

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

if [[ "$SIM_DRIVER" == "webots" ]]; then
  echo "[stack] starting Webots bridge on 127.0.0.1:5055 -> ${WEBOTS_HOST:-127.0.0.1}:${WEBOTS_ROBOT_PORT:-10000}/${WEBOTS_AGENT_PORT:-10001}"
  "${PYTHON_CMD[@]}" "$SIM_DIR/webots_bridge.py" \
    --host 127.0.0.1 \
    --port 5055 \
    --webots-host "${WEBOTS_HOST:-127.0.0.1}" \
    --robot-port "${WEBOTS_ROBOT_PORT:-10000}" \
    --agent-port "${WEBOTS_AGENT_PORT:-10001}" \
    --agent-mode manual \
    --backend-url "http://${HTTP_HOST}:${HTTP_PORT}" &
else
  echo "[stack] starting simulation emulator on 127.0.0.1:5055"
  "${PYTHON_CMD[@]}" "$SIM_DIR/tcp_emulator.py" --host 127.0.0.1 --port 5055 --agent-mode manual &
fi
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
    "${PYTHON_CMD[@]}" -m venv .venv
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
