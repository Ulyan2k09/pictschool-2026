#!/usr/bin/env sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
HOST="${UI_HOST:-0.0.0.0}"
PORT="${UI_PORT:-5173}"

cd "$ROOT_DIR"
exec python3 -m http.server "$PORT" --bind "$HOST" --directory self-play-ui
