from __future__ import annotations

import logging
import time

from .client import BackendApiError, BackendClient
from .config import AgentSettings
from .planner import LLMPlanner
from .schemas import RoundState


LOGGER = logging.getLogger("agent_service")


class AgentRunner:
    def __init__(self, settings: AgentSettings, client: BackendClient, planner: LLMPlanner):
        self.settings = settings
        self.client = client
        self.planner = planner

    def run_forever(self) -> None:
        while True:
            self.run_once()
            time.sleep(self.settings.poll_interval_sec)

    def run_once(self) -> None:
        try:
            round_response = self.client.get_round()
            round_state = round_response.round
            if not self._should_play(round_state):
                LOGGER.debug(
                    "Skip turn: status=%s activeActor=%s", round_state.status, round_state.activeActor
                )
                return

            plan = self.planner.plan(round_state)
            # LLM response can be slow; re-check turn ownership before submitting.
            latest_round_state = self.client.get_round().round
            if not self._should_play(latest_round_state):
                LOGGER.info(
                    "Skip stale plan: turn changed while planning (was turn=%s, now turn=%s, active=%s)",
                    round_state.turnNumber,
                    latest_round_state.turnNumber,
                    latest_round_state.activeActor,
                )
                return

            accepted = self.client.submit_turn(actor=self.settings.actor_id, commands=plan.commands)
            LOGGER.info(
                "Turn accepted: eventId=%s commands=%s source=%s rationale=%s",
                accepted.eventId,
                plan.commands,
                plan.source,
                plan.rationale,
            )
        except BackendApiError as error:
            LOGGER.warning("Backend error: %s", error)
        except Exception as error:
            LOGGER.exception("Unexpected runner error: %s", error)

    def _should_play(self, round_state: RoundState) -> bool:
        if round_state.status != "running":
            return False
        return round_state.activeActor == self.settings.actor_id


def main() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    )
    settings = AgentSettings.from_env()

    client = BackendClient(
        base_url=settings.backend_url,
        auth_token=settings.auth_token,
        timeout_sec=settings.request_timeout_sec,
    )
    planner = LLMPlanner(settings=settings)
    runner = AgentRunner(settings=settings, client=client, planner=planner)

    runner.run_forever()


if __name__ == "__main__":
    main()

