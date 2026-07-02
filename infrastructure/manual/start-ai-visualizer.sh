#!/usr/bin/env sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
HOST="${AI_UI_HOST:-0.0.0.0}"
PORT="${AI_UI_PORT:-5174}"

cd "$ROOT_DIR"
exec python3 -m http.server "$PORT" --bind "$HOST" --directory ai-visualizer

