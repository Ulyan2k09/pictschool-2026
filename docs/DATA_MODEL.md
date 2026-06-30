# Модель данных MVP

Документ задает единый контракт состояния для режима "agent + robot собирают уточек".

## Общие правила

- Координата задается как `{ "x": number, "y": number }`.
- Backend является единственным источником правды.
- В раунде два актера: `robot` и `agent`.
- За ход разрешено максимум `5` команд движения.
- Раунд завершается, когда собраны все уточки.

## Round

```json
{
  "id": "round-1",
  "status": "running",
  "turnNumber": 3,
  "activeActor": "agent",
  "moveLimitPerTurn": 5,
  "ducksTotal": 8,
  "ducksLeft": 3,
  "score": {
    "robot": 3,
    "agent": 2
  },
  "field": {
    "width": 8,
    "height": 6,
    "obstacles": [],
    "ducks": []
  },
  "actors": {
    "robot": {
      "id": "robot",
      "position": { "x": 0, "y": 0 },
      "direction": "E",
      "collectedDucks": 3,
      "lastError": null
    },
    "agent": {
      "id": "agent",
      "position": { "x": 7, "y": 5 },
      "direction": "W",
      "collectedDucks": 2,
      "lastError": null
    }
  }
}
```

Обязательные поля:

- `id` — идентификатор раунда.
- `status` — `idle`, `running`, `completed`, `failed`.
- `turnNumber` — номер текущего хода.
- `activeActor` — кто ходит сейчас.
- `moveLimitPerTurn` — лимит команд за ход.
- `ducksTotal`, `ducksLeft` — прогресс раунда.
- `score` — сколько уточек собрал каждый участник.
- `field` — текущее состояние поля, препятствий и уточек.
- `actors` — текущее состояние участников (`robot`, `agent`).

## Field

```json
{
  "width": 8,
  "height": 6,
  "obstacles": [
    { "id": "wall-1", "position": { "x": 3, "y": 2 } }
  ],
  "ducks": [
    { "id": "duck-1", "position": { "x": 1, "y": 4 }, "collectedBy": null }
  ]
}
```

Обязательные поля:

- `width`, `height` — размер сетки.
- `obstacles` — постоянные препятствия.
- `ducks` — уточки на поле.

## ActorState

```json
{
  "id": "robot",
  "position": { "x": 0, "y": 0 },
  "direction": "N",
  "collectedDucks": 3,
  "lastError": null
}
```

Обязательные поля:

- `id` — `robot` или `agent`.
- `position` — текущая позиция.
- `direction` — `N`, `E`, `S`, `W`.
- `collectedDucks` — текущий счет участника.
- `lastError` — последняя ошибка или `null`.

## TurnCommandRequest

```json
{
  "actor": "robot",
  "commands": [1, 1, 3, 1, 4]
}
```

Поля:

- `actor` — активный участник, отправляющий ход.
- `commands` — массив целых кодов.

Допустимые коды:

- `1` — клетка вперед;
- `2` — клетка назад;
- `3` — поворот влево на 90 градусов;
- `4` — поворот вправо на 90 градусов.

Ограничения:

- длина `commands`: `1..5`;
- другие коды запрещены.

## TcpCommandPayload

Строка, которую backend отправляет в симуляцию:

```text
1 1 3 1 4
```

Параметры передачи задаются конфигом:

- `SIM_TCP_HOST` (для MVP `127.0.0.1`)
- `SIM_TCP_COMMAND_PORT` (для MVP `5055`)
- `SIM_TCP_TELEMETRY_PORT` (резерв, для MVP `5056`)

## SimulationResult

```json
{
  "ok": true,
  "actor": "robot",
  "finalPosition": { "x": 3, "y": 1 },
  "finalDirection": "E",
  "ducksCollected": ["duck-2"],
  "error": null
}
```

Обязательные поля:

- `ok` — признак успешного исполнения.
- `actor` — кто выполнял ход.
- `finalPosition`, `finalDirection` — итог после команд.
- `ducksCollected` — список собранных уточек за ход.
- `error` — описание ошибки или `null`.

## GameEvent

```json
{
  "id": "event-42",
  "roundId": "round-1",
  "turnNumber": 7,
  "actor": "agent",
  "type": "duck.collected",
  "timestamp": "2026-06-22T19:52:10Z",
  "payload": {
    "actor": "agent",
    "duckId": "duck-4",
    "score": { "robot": 3, "agent": 3 }
  }
}
```

Обязательные поля:

- `id` — уникальный идентификатор события;
- `roundId` — идентификатор раунда;
- `turnNumber` — номер хода, в котором произошло событие;
- `actor` — участник события (`robot`, `agent`) или `null`;
- `type` — тип события;
- `timestamp` — ISO-время;
- `payload` — данные события.
