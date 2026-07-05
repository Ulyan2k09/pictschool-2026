#!/usr/bin/env sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
HOST="${AI_UI_HOST:-0.0.0.0}"
PORT="${AI_UI_PORT:-5174}"

cd "$ROOT_DIR"

is_working_python() {
  # Check that interpreter actually runs Python code.
  "$1" -c "import sys; print(sys.version_info[0])" >/dev/null 2>&1
}

if [ -n "${PYTHON_CMD:-}" ] && is_working_python "$PYTHON_CMD"; then
  exec "$PYTHON_CMD" -m http.server "$PORT" --bind "$HOST" --directory ai-visualizer
fi

for candidate in python3 python; do
  if command -v "$candidate" >/dev/null 2>&1 && is_working_python "$candidate"; then
    exec "$candidate" -m http.server "$PORT" --bind "$HOST" --directory ai-visualizer
  fi
done

if command -v py >/dev/null 2>&1; then
  exec py -3 -m http.server "$PORT" --bind "$HOST" --directory ai-visualizer
fi

echo "[ai-visualizer] Python not found. Install Python 3 and ensure python/python3/py is in PATH." >&2
exit 1

