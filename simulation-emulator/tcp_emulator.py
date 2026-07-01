#!/usr/bin/env python3
import argparse
import json
import socketserver
from datetime import datetime, timezone
from typing import Any


ALLOWED_COMMANDS = {1, 2, 3, 4}
AGENT_HARDCODED_COMMANDS = [1, 1, 4, 1]
DIRECTIONS = ["N", "E", "S", "W"]


def turn_left(direction: str) -> str:
    return DIRECTIONS[(DIRECTIONS.index(direction) - 1) % len(DIRECTIONS)]


def turn_right(direction: str) -> str:
    return DIRECTIONS[(DIRECTIONS.index(direction) + 1) % len(DIRECTIONS)]


def move(position: dict[str, int], direction: str, step: int, field: dict[str, Any]) -> dict[str, int]:
    candidate = dict(position)
    if direction == "N":
        candidate["y"] -= step
    elif direction == "E":
        candidate["x"] += step
    elif direction == "S":
        candidate["y"] += step
    elif direction == "W":
        candidate["x"] -= step

    inside = 0 <= candidate["x"] < field["width"] and 0 <= candidate["y"] < field["height"]
    blocked = any(obstacle["position"] == candidate for obstacle in field["obstacles"])
    return candidate if inside and not blocked else position


def simulate(request: dict[str, Any], agent_mode: str) -> dict[str, Any]:
    actor = request["actor"]
    round_state = request["round"]
    actor_state = round_state["actors"][actor]
    field = round_state["field"]

    requested_commands = request["commands"]
    commands = AGENT_HARDCODED_COMMANDS if actor == "agent" and agent_mode == "hardcoded" else requested_commands
    invalid = [command for command in commands if command not in ALLOWED_COMMANDS]
    if invalid:
        return {
            "ok": False,
            "actor": actor,
            "ducksCollected": [],
            "error": f"Invalid commands: {invalid}",
        }

    position = dict(actor_state["position"])
    direction = actor_state["direction"]

    for command in commands:
        if command == 1:
            position = move(position, direction, 1, field)
        elif command == 2:
            position = move(position, direction, -1, field)
        elif command == 3:
            direction = turn_left(direction)
        elif command == 4:
            direction = turn_right(direction)

    ducks_collected = [
        duck["id"]
        for duck in field["ducks"]
        if duck.get("collectedBy") is None and duck["position"] == position
    ]

    return {
        "ok": True,
        "actor": actor,
        "finalPosition": position,
        "finalDirection": direction,
        "ducksCollected": ducks_collected,
        "error": None,
        "executedCommands": commands,
        "mode": "hardcoded-agent" if actor == "agent" and agent_mode == "hardcoded" else "command-replay",
    }


class CommandHandler(socketserver.BaseRequestHandler):
    def handle(self) -> None:
        timestamp = datetime.now(timezone.utc).isoformat()
        chunks: list[bytes] = []
        while True:
            chunk = self.request.recv(4096)
            if not chunk:
                break
            chunks.append(chunk)
        raw_payload = b"".join(chunks).decode("utf-8", errors="replace").strip()

        try:
            request = json.loads(raw_payload)
            response = simulate(request, self.server.agent_mode)
        except Exception as exc:
            response = {
                "ok": False,
                "actor": "unknown",
                "ducksCollected": [],
                "error": str(exc),
            }

        self.request.sendall((json.dumps(response, ensure_ascii=False) + "\n").encode("utf-8"))

        print(
            f"[{timestamp}] {self.client_address[0]}:{self.client_address[1]} "
            f"request={raw_payload} response={json.dumps(response, ensure_ascii=False)}",
            flush=True,
        )


class ReusableThreadingTCPServer(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True
    agent_mode: str = "hardcoded"


def main() -> None:
    parser = argparse.ArgumentParser(description="TCP simulation emulator for backend round commands.")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=5055)
    parser.add_argument(
        "--agent-mode",
        choices=["hardcoded", "manual"],
        default="hardcoded",
        help="hardcoded ignores submitted agent commands; manual executes them",
    )
    args = parser.parse_args()

    with ReusableThreadingTCPServer((args.host, args.port), CommandHandler) as server:
        server.agent_mode = args.agent_mode
        print(f"simulation emulator listening on {args.host}:{args.port}; agent_mode={args.agent_mode}", flush=True)
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            print("\nsimulation emulator stopped", flush=True)


if __name__ == "__main__":
    main()
