from __future__ import annotations

import os
from dataclasses import dataclass


def _read_bool(name: str, default: bool) -> bool:
    value = os.getenv(name)
    if value is None:
        return default
    normalized = value.strip().lower()
    return normalized in {"1", "true", "yes", "y", "on"}


def _read_float(name: str, default: float) -> float:
    value = os.getenv(name)
    if value is None:
        return default
    try:
        return float(value)
    except ValueError:
        return default


def _read_int(name: str, default: int) -> int:
    value = os.getenv(name)
    if value is None:
        return default
    try:
        return int(value)
    except ValueError:
        return default


@dataclass(frozen=True)
class AgentSettings:
    backend_url: str
    auth_token: str | None
    actor_id: str
    poll_interval_sec: float
    request_timeout_sec: float
    llm_enabled: bool
    llm_provider: str
    llm_model: str
    openai_api_key: str | None
    openai_base_url: str | None
    embed_model: str | None
    llm_temperature: float
    llm_max_tokens: int

    @classmethod
    def from_env(cls) -> "AgentSettings":
        return cls(
            backend_url=os.getenv("AGENT_BACKEND_URL", "http://localhost:8080").rstrip("/"),
            auth_token=os.getenv("AGENT_AUTH_TOKEN"),
            actor_id=os.getenv("AGENT_ACTOR_ID", "agent"),
            poll_interval_sec=_read_float("AGENT_POLL_INTERVAL_SEC", 0.8),
            request_timeout_sec=_read_float("AGENT_REQUEST_TIMEOUT_SEC", 8.0),
            llm_enabled=_read_bool("AGENT_LLM_ENABLED", True),
            llm_provider=os.getenv("AGENT_LLM_PROVIDER", "openai"),
            llm_model=os.getenv("AGENT_LLM_MODEL", "gpt-4o-mini"),
            openai_api_key=os.getenv("OPENAI_API_KEY"),
            openai_base_url=os.getenv("OPENAI_BASE_URL"),
            embed_model=os.getenv("EMBED_MODEL"),
            llm_temperature=_read_float("AGENT_LLM_TEMPERATURE", 0.1),
            llm_max_tokens=_read_int("AGENT_LLM_MAX_TOKENS", 120),
        )

