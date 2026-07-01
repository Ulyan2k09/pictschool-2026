#!/usr/bin/env sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
HOST="${SIM_TCP_HOST:-127.0.0.1}"
PORT="${SIM_TCP_COMMAND_PORT:-5055}"
AGENT_MODE="${AGENT_MODE:-auto}"

cd "$ROOT_DIR"
exec python3 simulation-emulator/tcp_emulator.py --host "$HOST" --port "$PORT" --agent-mode "$AGENT_MODE"
