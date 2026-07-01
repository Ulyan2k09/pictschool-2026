#!/usr/bin/env python3
import argparse
import json
import urllib.error
import urllib.request
from typing import Any


COMMAND_ALIASES = {
    "f": 1,
    "forward": 1,
    "b": 2,
    "back": 2,
    "l": 3,
    "left": 3,
    "r": 4,
    "right": 4,
}


def api(base_url: str, method: str, path: str, body: dict[str, Any] | None = None) -> dict[str, Any]:
    data = None if body is None else json.dumps(body).encode("utf-8")
    request = urllib.request.Request(
        f"{base_url}{path}",
        data=data,
        method=method,
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(request, timeout=3) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        payload = error.read().decode("utf-8")
        try:
            return json.loads(payload)
        except json.JSONDecodeError:
            return {"error": {"code": str(error.code), "message": payload}}


def parse_commands(raw: str) -> list[int]:
    parts = raw.replace(",", " ").split()
    commands: list[int] = []
    for part in parts:
        normalized = part.lower()
        if normalized in COMMAND_ALIASES:
            commands.append(COMMAND_ALIASES[normalized])
        else:
            commands.append(int(normalized))
    return commands


def cell_symbol(round_state: dict[str, Any], x: int, y: int) -> str:
    position = {"x": x, "y": y}
    actors = round_state["actors"]
    if actors["robot"]["position"] == position:
        return "R"
    if actors["agent"]["position"] == position:
        return "A"
    if any(obstacle["position"] == position for obstacle in round_state["field"]["obstacles"]):
        return "#"
    for duck in round_state["field"]["ducks"]:
        if duck["position"] == position and duck.get("collectedBy") is None:
            return "*"
    return "."


def print_round(round_state: dict[str, Any]) -> None:
    field = round_state["field"]
    print()
    print(
        f"turn={round_state['turnNumber']} active={round_state['activeActor']} "
        f"ducks={round_state['ducksLeft']}/{round_state['ducksTotal']} "
        f"score R:{round_state['score']['robot']} A:{round_state['score']['agent']}"
    )
    for actor, state in round_state["actors"].items():
        pos = state["position"]
        print(f"{actor}: ({pos['x']},{pos['y']}) {state['direction']}")
    print()
    print(f"{' ' * (field['width'] + 1)}N")
    for y in range(field["height"]):
        side = "W" if y == field["height"] // 2 else " "
        other_side = "E" if y == field["height"] // 2 else " "
        print(f"{side} " + " ".join(cell_symbol(round_state, x, y) for x in range(field["width"])) + f" {other_side}")
    print(f"{' ' * (field['width'] + 1)}S")
    print()
    print("commands: 1/f=forward, 2/b=back, 3/l=left, 4/r=right; max 5")


def main() -> None:
    parser = argparse.ArgumentParser(description="Play robot vs agent through the backend API.")
    parser.add_argument("--base-url", default="http://localhost:8080")
    parser.add_argument("--no-start", action="store_true", help="do not start a new round on launch")
    args = parser.parse_args()

    if not args.no_start:
        start = api(args.base_url, "POST", "/api/round/start", {"scenarioId": "default"})
        if "error" in start:
            print(start)
            return

    while True:
        round_response = api(args.base_url, "GET", "/api/round")
        if "error" in round_response:
            print(round_response)
            return

        round_state = round_response["round"]
        print_round(round_state)
        if round_state["status"] != "running":
            print(f"round status: {round_state['status']}")
            return

        actor = round_state["activeActor"]
        raw = input(f"{actor}> ").strip()
        if raw.lower() in {"q", "quit", "exit"}:
            return
        if raw.lower() in {"reset", "restart"}:
            api(args.base_url, "POST", "/api/round/start", {"scenarioId": "default"})
            continue
        if not raw:
            continue

        try:
            commands = parse_commands(raw)
        except ValueError:
            print("bad command list")
            continue

        result = api(args.base_url, "POST", "/api/turn/submit", {"actor": actor, "commands": commands})
        if "error" in result:
            print(result["error"])


if __name__ == "__main__":
    main()
