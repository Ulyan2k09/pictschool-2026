# API MVP

Документ фиксирует обновленный минимальный контракт между `mobile`, `backend` и `simulation`.

## Общие правила

- Все REST-запросы и ответы используют JSON.
- Backend является единственным источником правды.
- Любое важное изменение состояния публикуется как событие и попадает в журнал.
- Команды движения передаются в симуляцию **не через REST**, а через TCP-строку байт на `localhost`.

## TCP-контракт backend -> simulation

Параметры фиксируются в конфиге backend:

- `SIM_TCP_HOST=127.0.0.1`
- `SIM_TCP_COMMAND_PORT=5055`
- `SIM_TCP_TELEMETRY_PORT=5056` (зарезервирован на будущее)

Формат сообщения:

```text
1 2 3 4
```

Коды:

- `1` — клетка вперед;
- `2` — клетка назад;
- `3` — поворот на 90 градусов влево;
- `4` — поворот на 90 градусов вправо.

Для MVP backend отправляет одну строку на ход (до `5` команд, разделитель пробел).

## Формат ошибки

```json
{
  "error": {
    "code": "unknown_command",
    "message": "Команда 7 не поддерживается.",
    "details": {
      "allowed": [1, 2, 3, 4, 10, 11, 12, 13]
    }
  }
}
```

Минимальные коды ошибок:

- `unknown_command` — команда не поддерживается;
- `turn_limit_exceeded` — в ходе больше 5 команд;
- `wrong_actor_turn` — команда пришла не от активного участника;
- `round_not_running` — команда пришла вне активного раунда;
- `simulation_error` — не удалось отправить TCP-команду в симуляцию.

## REST endpoints

### `GET /api/round`

Получить текущее состояние раунда.

Ответ `200`:

```json
{
  "round": {
    "id": "round-1",
    "status": "running",
    "activeActor": "robot",
    "turnNumber": 4,
    "moveLimitPerTurn": 5,
    "score": {
      "robot": 3,
      "agent": 2
    },
    "ducksLeft": 5
  }
}
```

### `POST /api/round/start`

Запустить новый раунд.

Запрос:

```json
{
  "scenarioId": "default"
}
```

Ответ `201`:

```json
{
  "roundId": "round-1",
  "status": "running",
  "activeActor": "robot"
}
```

### `POST /api/turn/submit`

Отправить пакет команд текущего участника (до 5 команд).

Запрос:

```json
{
  "actor": "robot",
  "commands": [1, 1, 3, 1, 4]
}
```

Ответ `202`:

```json
{
  "accepted": true,
  "eventId": "event-17",
  "forwardedAs": "1 1 3 1 4"
}
```

События: `turn.submitted`, `simulation.command_sent`, `actor.moved`, `turn.completed`.

### `GET /api/events`

Получить журнал событий текущего раунда.

Ответ `200`:

```json
{
  "events": [
    {
      "id": "event-17",
      "type": "simulation.command_sent",
      "timestamp": "2026-06-22T19:50:30Z",
      "payload": {
        "actor": "robot",
        "tcpPayload": "1 1 3 1 4",
        "port": 5055
      }
    }
  ]
}
```

### `POST /api/round/reset`

Сбросить раунд к стартовым условиям.

Ответ `200`:

```json
{
  "roundId": "round-1",
  "status": "idle",
  "readyForStart": true
}
```

## Realtime endpoint

### `GET /api/live`

Канал live-обновлений через **SSE** (`text/event-stream`).

Формат сообщения:

```text
event: duck.collected
data: {"id":"event-42","roundId":"round-1","turnNumber":7,"type":"duck.collected","timestamp":"2026-06-22T19:52:10Z","actor":"agent","payload":{"actor":"agent","duckId":"duck-4","score":{"robot":3,"agent":3}}}
```

Обязательные события MVP:

- `round.started`
- `turn.submitted`
- `simulation.command_sent`
- `actor.moved`
- `duck.collected`
- `turn.completed`
- `turn.failed`
- `round.completed`
- `round.reset`

## Минимальная проверка API

- REST endpoint'ы возвращают JSON.
- Команда хода ограничена 5 действиями.
- Backend отправляет в симуляцию строку команд по TCP на `SIM_TCP_COMMAND_PORT`.
- Ошибки используют единый формат.
- При сборе последней уточки публикуется `round.completed`.
