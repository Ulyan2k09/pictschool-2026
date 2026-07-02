from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field, field_validator

Direction = Literal["N", "E", "S", "W"]
ActorId = Literal["robot", "agent"]
RoundStatus = Literal["idle", "running", "completed", "failed"]

ALLOWED_COMMANDS = (1, 2, 3, 4)
MAX_COMMANDS_PER_TURN = 5


class Position(BaseModel):
    x: int
    y: int


class Obstacle(BaseModel):
    id: str
    position: Position


class Duck(BaseModel):
    id: str
    position: Position
    collectedBy: ActorId | None = None


class FieldState(BaseModel):
    width: int
    height: int
    obstacles: list[Obstacle] = Field(default_factory=list)
    ducks: list[Duck] = Field(default_factory=list)


class ActorState(BaseModel):
    id: ActorId
    position: Position
    direction: Direction
    collectedDucks: int
    lastError: str | None = None


class Score(BaseModel):
    robot: int
    agent: int


class RoundState(BaseModel):
    id: str
    status: RoundStatus
    turnNumber: int
    activeActor: ActorId
    moveLimitPerTurn: int = MAX_COMMANDS_PER_TURN
    ducksTotal: int
    ducksLeft: int
    score: Score
    field: FieldState
    actors: dict[str, ActorState]

    def actor(self, actor_id: ActorId) -> ActorState:
        actor_state = self.actors.get(actor_id)
        if actor_state is None:
            raise ValueError(f"Missing actor in round payload: {actor_id}")
        return actor_state


class RoundResponse(BaseModel):
    round: RoundState


class TurnCommandRequest(BaseModel):
    actor: ActorId
    commands: list[int] = Field(min_length=1, max_length=MAX_COMMANDS_PER_TURN)

    @field_validator("commands")
    @classmethod
    def validate_commands(cls, value: list[int]) -> list[int]:
        invalid = [command for command in value if command not in ALLOWED_COMMANDS]
        if invalid:
            raise ValueError(f"Unsupported command(s): {invalid}. Allowed: {ALLOWED_COMMANDS}")
        return value


class TurnAcceptedResponse(BaseModel):
    accepted: bool
    eventId: str
    forwardedAs: str


class ApiErrorBody(BaseModel):
    code: str
    message: str
    details: dict | None = None


class ApiErrorEnvelope(BaseModel):
    error: ApiErrorBody


class LLMPlan(BaseModel):
    commands: list[int] = Field(
        min_length=1,
        max_length=MAX_COMMANDS_PER_TURN,
        description="Коды движения от 1 до 4, длина 1..5",
    )
    rationale: str = Field(
        min_length=1,
        max_length=400,
        description="Краткая причина выбора команд",
    )

    @field_validator("commands")
    @classmethod
    def validate_commands(cls, value: list[int]) -> list[int]:
        invalid = [command for command in value if command not in ALLOWED_COMMANDS]
        if invalid:
            raise ValueError(f"Unsupported command(s): {invalid}. Allowed: {ALLOWED_COMMANDS}")
        return value

