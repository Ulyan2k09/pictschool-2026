#!/usr/bin/env sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
HOST="${SIM_TCP_HOST:-127.0.0.1}"
PORT="${SIM_TCP_COMMAND_PORT:-5055}"
AGENT_MODE="${AGENT_MODE:-auto}"
DRIVER="${SIM_DRIVER:-emulator}"
WEBOTS_HOST="${WEBOTS_HOST:-127.0.0.1}"
WEBOTS_ROBOT_PORT="${WEBOTS_ROBOT_PORT:-10000}"
WEBOTS_AGENT_PORT="${WEBOTS_AGENT_PORT:-10001}"
WEBOTS_BACKEND_URL="${WEBOTS_BACKEND_URL:-}"

cd "$ROOT_DIR"
if [ "$DRIVER" = "webots" ]; then
  if [ -n "$WEBOTS_BACKEND_URL" ]; then
    exec python3 simulation-emulator/webots_bridge.py \
      --host "$HOST" \
      --port "$PORT" \
      --webots-host "$WEBOTS_HOST" \
      --robot-port "$WEBOTS_ROBOT_PORT" \
      --agent-port "$WEBOTS_AGENT_PORT" \
      --agent-mode "$AGENT_MODE" \
      --backend-url "$WEBOTS_BACKEND_URL"
  fi
  exec python3 simulation-emulator/webots_bridge.py \
    --host "$HOST" \
    --port "$PORT" \
    --webots-host "$WEBOTS_HOST" \
    --robot-port "$WEBOTS_ROBOT_PORT" \
    --agent-port "$WEBOTS_AGENT_PORT" \
    --agent-mode "$AGENT_MODE"
fi

exec python3 simulation-emulator/tcp_emulator.py --host "$HOST" --port "$PORT" --agent-mode "$AGENT_MODE"
