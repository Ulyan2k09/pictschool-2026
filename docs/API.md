# API MVP

Документ фиксирует минимальный контракт между `mobile`, `backend`, `ai` и `computer-systems`. Конкретный стек не задается: REST и realtime-канал можно реализовать на любом фреймворке.

## Общие правила

- Все REST-запросы и ответы используют JSON.
- Бэкенд является единственным источником правды.
- Любое важное изменение состояния публикуется как событие и попадает в журнал.
- `GET /api/live` может быть WebSocket или SSE, но формат событий должен быть одинаковым.

## Формат ошибки

```json
{
  "error": {
    "code": "path_blocked",
    "message": "Команда невозможна: путь перекрыт объектом box-1.",
    "details": {
      "objectId": "box-1",
      "position": { "x": 4, "y": 2 }
    }
  }
}
```

Минимальные коды ошибок:

- `path_blocked` — движение невозможно, путь закрыт объектом или препятствием.
- `invalid_object_move` — ИИ пытается переместить объект в недопустимую позицию.
- `mission_not_running` — команда пришла до старта или после завершения миссии.
- `platform_error` — платформа или симуляция вернула ошибку выполнения.
- `unknown_command` — команда игрока или платформы не поддерживается.

## REST endpoints

### `GET /api/mission`

Получить текущее состояние миссии.

Ответ `200`:

```json
{
  "mission": {
    "id": "mission-1",
    "status": "running",
    "score": 120,
    "timeLeftSec": 480,
    "currentTaskId": "task-2",
    "field": {
      "width": 8,
      "height": 6,
      "objects": [
        {
          "id": "box-1",
          "type": "movable_block",
          "position": { "x": 4, "y": 2 },
          "state": "blocking"
        }
      ]
    },
    "platform": {
      "id": "platform-1",
      "position": { "x": 1, "y": 0 },
      "status": "ready",
      "lastCommand": "move_forward",
      "error": null
    }
  }
}
```

Ошибки: `mission_not_running`, если MVP решит скрывать состояние до старта. Рекомендуемый вариант для кураторов: возвращать состояние и при `idle`, чтобы приложение можно было отлаживать до запуска.

### `POST /api/mission/start`

Запустить или перезапустить миссию.

Запрос:

```json
{
  "scenarioId": "default",
  "teamId": "team-1"
}
```

Ответ `201`:

```json
{
  "missionId": "mission-1",
  "status": "running"
}
```

Событие: `mission.started`.

Ошибки: `platform_error`, если платформа или симуляция не готова.

### `POST /api/player/command`

Отправить команду игрока платформе.

Запрос:

```json
{
  "command": "move_forward",
  "params": {
    "steps": 1
  }
}
```

Ответ `202`:

```json
{
  "accepted": true,
  "eventId": "event-17",
  "platformStatus": "moving"
}
```

События: `player.commanded`, затем `platform.updated`.

Ошибки: `mission_not_running`, `path_blocked`, `unknown_command`, `platform_error`.

### `POST /api/ai/action`

Принять действие ИИ-агента.

Запрос:

```json
{
  "type": "move_object",
  "targetObjectId": "box-1",
  "from": { "x": 2, "y": 2 },
  "to": { "x": 4, "y": 2 },
  "reason": "player_is_using_short_route"
}
```

Ответ `202`:

```json
{
  "accepted": true,
  "eventId": "event-42",
  "result": "object_moved"
}
```

События: `ai.object_moved`, `ai.path_blocked`, если действие закрыло маршрут.

Ошибки: `mission_not_running`, `invalid_object_move`.

### `GET /api/events`

Получить журнал событий текущей миссии.

Ответ `200`:

```json
{
  "events": [
    {
      "id": "event-42",
      "type": "ai.object_moved",
      "timestamp": "2026-07-05T10:15:30Z",
      "payload": {
        "objectId": "box-1",
        "from": { "x": 2, "y": 2 },
        "to": { "x": 4, "y": 2 }
      }
    }
  ]
}
```

Ошибки: для MVP не обязательны. Если журнала нет, возвращается пустой массив.

### `POST /api/mission/reset`

Сбросить миссию для нового прогона.

Запрос:

```json
{
  "scenarioId": "default"
}
```

Ответ `200`:

```json
{
  "missionId": "mission-1",
  "status": "idle",
  "readyForStart": true
}
```

Ошибки: `platform_error`, если платформа не смогла перейти в безопасное стартовое состояние.

## Realtime endpoint

### `GET /api/live`

Канал live-обновлений через WebSocket или SSE.

Формат события:

```json
{
  "type": "platform.updated",
  "timestamp": "2026-07-05T10:15:35Z",
  "payload": {
    "position": { "x": 2, "y": 0 },
    "status": "moving",
    "error": null
  }
}
```

Обязательные события MVP:

- `mission.started` — миссия запущена.
- `player.commanded` — игрок отправил команду.
- `platform.updated` — платформа изменила позицию, статус или ошибку.
- `ai.object_moved` — ИИ передвинул объект.
- `ai.path_blocked` — ИИ заблокировал путь или зону.
- `mission.scored` — изменились очки.
- `mission.failed` — миссия провалена.
- `mission.completed` — миссия завершена успешно.

## Минимальная проверка API

- Каждый endpoint возвращает JSON.
- Ошибки используют общий формат.
- Команда игрока создает событие `player.commanded`.
- Действие ИИ `move_object` создает `ai.object_moved`.
- Блокировка пути видна как ошибка `path_blocked` и событие `ai.path_blocked`.
