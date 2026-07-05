#!/usr/bin/env python3
import argparse
import json
import socket
import socketserver
import threading
import time
import urllib.request
from datetime import datetime, timezone

from tcp_emulator import simulate


def actor_position(round_state: dict, actor: str) -> tuple[int, int, str]:
    state = round_state["actors"][actor]
    position = state["position"]
    return int(position["x"]), int(position["y"]), state["direction"]


def build_setup_payload(round_state: dict) -> str:
    field = round_state["field"]
    robot_x, robot_y, robot_direction = actor_position(round_state, "robot")
    agent_x, agent_y, agent_direction = actor_position(round_state, "agent")
    ducks = [duck for duck in field["ducks"] if duck.get("collectedBy") is None]
    obstacles = field.get("obstacles", [])

    parts = [
        "SETUP",
        str(round_state["id"]),
        str(field["width"]),
        str(field["height"]),
        "R",
        str(robot_x),
        str(robot_y),
        robot_direction,
        "A",
        str(agent_x),
        str(agent_y),
        agent_direction,
        "D",
        str(len(ducks)),
    ]
    for duck in ducks:
        parts.extend([str(duck["position"]["x"]), str(duck["position"]["y"])])
    parts.extend(["O", str(len(obstacles))])
    for obstacle in obstacles:
        parts.extend([str(obstacle["position"]["x"]), str(obstacle["position"]["y"])])
    return " ".join(parts)


def read_payload(request: socket.socket) -> str:
    chunks: list[bytes] = []
    while True:
        chunk = request.recv(4096)
        if not chunk:
            break
        chunks.append(chunk)
    return b"".join(chunks).decode("utf-8", errors="replace").strip()


def send_line_to_webots(host: str, port: int, payload: str, timeout: float) -> str:
    with socket.create_connection((host, port), timeout=timeout) as webots_socket:
        webots_socket.settimeout(timeout)
        webots_socket.sendall((payload.strip() + "\n").encode("utf-8"))
    return payload.strip()


def send_commands_to_webots(host: str, port: int, commands: list[int], timeout: float) -> str:
    payload = " ".join(str(command) for command in commands)
    return send_line_to_webots(host, port, payload, timeout)


def sync_setup(server: "ReusableThreadingTCPServer", round_state: dict, force: bool = False) -> str:
    setup_key = f"{round_state['id']}:{round_state['turnNumber']}:{round_state['ducksLeft']}"
    with server.setup_lock:
        if not force and server.setup_key == setup_key:
            return ""
        setup_payload = build_setup_payload(round_state)
        sent = send_line_to_webots(server.webots_host, server.robot_port, setup_payload, server.webots_timeout)
        server.setup_key = setup_key
        return sent


def read_backend_json(url: str, timeout: float) -> dict:
    with urllib.request.urlopen(url, timeout=timeout) as response:
        return json.loads(response.read().decode("utf-8"))


def latest_round_started_key(events_payload: dict) -> str | None:
    events = events_payload.get("events") or []
    for event in reversed(events):
        if event.get("type") == "round.started":
            return f"{event.get('id')}:{event.get('timestamp')}"
    return None


def poll_backend_round(server: "ReusableThreadingTCPServer") -> None:
    if not server.backend_url:
        return

    backend_url = server.backend_url.rstrip("/")
    round_url = f"{backend_url}/api/round"
    events_url = f"{backend_url}/api/events"
    while not server.shutdown_requested:
        try:
            round_payload = read_backend_json(round_url, server.backend_timeout)
            events_payload = read_backend_json(events_url, server.backend_timeout)
            round_state = round_payload.get("round")
            if round_state and round_state.get("status") == "running":
                started_key = latest_round_started_key(events_payload)
                force = started_key is not None and started_key != server.round_started_key
                setup_payload = sync_setup(server, round_state, force=force)
                if force:
                    server.round_started_key = started_key
                if setup_payload:
                    print(f"[backend-sync] webots={setup_payload}", flush=True)
        except Exception:
            pass
        time.sleep(server.backend_poll_interval)


class BridgeHandler(socketserver.BaseRequestHandler):
    def handle(self) -> None:
        timestamp = datetime.now(timezone.utc).isoformat()
        raw_payload = read_payload(self.request)
        webots_payload = ""

        try:
            command_request = json.loads(raw_payload)
            actor = command_request["actor"]
            setup_payload = sync_setup(self.server, command_request["round"])
            response = simulate(command_request, self.server.agent_mode)

            if response.get("ok"):
                commands = response.get("executedCommands", command_request["commands"])
                port = self.server.robot_port if actor == "robot" else self.server.agent_port
                webots_payload = send_commands_to_webots(
                    self.server.webots_host,
                    port,
                    commands,
                    self.server.webots_timeout,
                )
                if setup_payload:
                    webots_payload = f"{setup_payload} | {webots_payload}"
        except Exception as exc:
            response = {
                "ok": False,
                "actor": "unknown",
                "ducksCollected": [],
                "error": str(exc),
            }

        encoded_response = json.dumps(response, ensure_ascii=False) + "\n"
        self.request.sendall(encoded_response.encode("utf-8"))

        print(
            f"[{timestamp}] {self.client_address[0]}:{self.client_address[1]} "
            f"request={raw_payload} webots={webots_payload or '-'} "
            f"response={json.dumps(response, ensure_ascii=False)}",
            flush=True,
        )


class ReusableThreadingTCPServer(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True
    agent_mode: str = "manual"
    webots_host: str = "127.0.0.1"
    robot_port: int = 10000
    agent_port: int = 10001
    webots_timeout: float = 1.0
    backend_url: str | None = None
    backend_timeout: float = 1.0
    backend_poll_interval: float = 0.5
    shutdown_requested: bool = False

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.setup_key: str | None = None
        self.round_started_key: str | None = None
        self.setup_lock = threading.Lock()


def main() -> None:
    parser = argparse.ArgumentParser(description="Bridge backend JSON TCP commands to Webots controller sockets.")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=5055)
    parser.add_argument("--webots-host", default="127.0.0.1")
    parser.add_argument("--robot-port", type=int, default=10000)
    parser.add_argument("--agent-port", type=int, default=10001)
    parser.add_argument("--webots-timeout", type=float, default=1.0)
    parser.add_argument("--backend-url", default=None, help="Optional backend URL used to sync Webots immediately after /api/round/start.")
    parser.add_argument("--backend-timeout", type=float, default=1.0)
    parser.add_argument("--backend-poll-interval", type=float, default=0.5)
    parser.add_argument(
        "--agent-mode",
        choices=["auto", "hardcoded", "manual"],
        default="manual",
        help="manual replays backend commands; auto/hardcoded may replace agent commands before sending them to Webots",
    )
    args = parser.parse_args()

    with ReusableThreadingTCPServer((args.host, args.port), BridgeHandler) as server:
        server.agent_mode = args.agent_mode
        server.webots_host = args.webots_host
        server.robot_port = args.robot_port
        server.agent_port = args.agent_port
        server.webots_timeout = args.webots_timeout
        server.backend_url = args.backend_url or None
        server.backend_timeout = args.backend_timeout
        server.backend_poll_interval = args.backend_poll_interval
        poll_thread = threading.Thread(target=poll_backend_round, args=(server,), daemon=True)
        poll_thread.start()
        print(
            f"webots bridge listening on {args.host}:{args.port}; "
            f"webots={args.webots_host}, robot={args.robot_port}, agent={args.agent_port}, "
            f"agent_mode={args.agent_mode}, backend_url={server.backend_url or '-'}",
            flush=True,
        )
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            print("\nwebots bridge stopped", flush=True)
        finally:
            server.shutdown_requested = True


if __name__ == "__main__":
    main()
