# agent_service

Python LLM-агент для текущего MVP backend API:

- читает состояние через `GET /api/round`;
- выбирает ход через LLM structured output;
- отправляет команды через `POST /api/turn/submit`.

Контракты берутся в первую очередь из backend-источников:

- `backend/src/main/kotlin/school/pict/backend/Dto.kt`
- `backend/src/main/kotlin/school/pict/backend/Domain.kt`
- `backend/src/main/resources/openapi.yaml`

## Установка

```bash
cd ai
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Быстрый старт с env:

```bash
cd ai
cp .env.example .env
# заполните OPENAI_API_KEY в .env
```

## Переменные окружения

- `AGENT_BACKEND_URL` (default: `http://localhost:8080`)
- `AGENT_AUTH_TOKEN` (optional bearer token)
- `AGENT_ACTOR_ID` (default: `agent`)
- `AGENT_POLL_INTERVAL_SEC` (default: `0.8`)
- `AGENT_REQUEST_TIMEOUT_SEC` (default: `8.0`)
- `AGENT_LLM_ENABLED` (default: `true`)
- `AGENT_LLM_PROVIDER` (default: `openai`)
- `AGENT_LLM_MODEL` (default: `gpt-4o-mini`)
- `AGENT_LLM_TEMPERATURE` (default: `0.1`)
- `AGENT_LLM_MAX_TOKENS` (default: `120`)
- `OPENAI_API_KEY` (required for OpenAI calls)
- `OPENAI_BASE_URL` (optional custom OpenAI-compatible endpoint)
- `EMBED_MODEL` (optional, reserved for retrieval/embeddings features)

Если `OPENAI_API_KEY` не задан, агент автоматически переходит в детерминированный fallback.

## Запуск

Один цикл:

```bash
python -m agent_service --once
```

Запустить новый раунд и работать в цикле:

```bash
python -m agent_service --start-round
```

Ограничить число итераций:

```bash
python -m agent_service --max-iterations 20
```

## Поднять backend + simulation + AI вместе

```bash
./infrastructure/manual/start-backend-ai-stack.sh
```

Отдельная дополнительная визуализация (не меняет текущий backend и `self-play-ui`):

```bash
./infrastructure/manual/start-ai-visualizer.sh
```

После запуска откройте `http://127.0.0.1:5174`.

