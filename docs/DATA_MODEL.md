# Модель данных MVP

Документ описывает минимальные сущности, которые должны одинаково понимать все треки. Это не схема конкретной базы данных, а контракт состояния и сообщений.

## Общие правила

- Координата всегда задается как `{ "x": number, "y": number }`.
- Бэкенд является единственным источником правды.
- ИИ отправляет действие, но не меняет состояние напрямую.
- Mobile App получает состояние от бэкенда и не хранит собственную версию правил.
- Platform / Simulation возвращает результат движения, но не начисляет очки и не завершает миссию.

## Mission

```json
{
  "id": "mission-1",
  "status": "planning",
  "score": 120,
  "timeLeftSec": 480,
  "currentTaskId": "task-2",
  "field": {},
  "platform": {},
  "eventsCount": 42
}
```

Обязательные поля:

- `id` — идентификатор прогона.
- `status` — состояние миссии.
- `score` — текущие очки.
- `timeLeftSec` — оставшееся время в секундах.
- `currentTaskId` — текущее задание или `null`.
- `field` — состояние поля.
- `platform` — состояние платформы.

Статусы: `idle`, `planning`, `executing`, `paused`, `failed`, `completed`.

## Field

```json
{
  "width": 8,
  "height": 6,
  "zones": [
    { "id": "start", "type": "safe", "cells": [{ "x": 0, "y": 0 }] },
    { "id": "goal", "type": "target", "cells": [{ "x": 7, "y": 5 }] }
  ],
  "obstacles": [
    { "id": "wall-1", "position": { "x": 3, "y": 2 } }
  ],
  "objects": []
}
```

Обязательные поля:

- `width`, `height` — размер поля.
- `zones` — специальные зоны: старт, цель, опасная зона, закрытая зона.
- `obstacles` — постоянные препятствия.
- `objects` — перемещаемые или интерактивные объекты.

Для MVP поле считается сеткой. Если физическая платформа использует реальные координаты, адаптер платформы переводит их в сетку для бэкенда.

## Object

```json
{
  "id": "box-1",
  "type": "movable_block",
  "position": { "x": 4, "y": 2 },
  "state": "blocking"
}
```

Обязательные поля:

- `id` — уникальный идентификатор объекта.
- `type` — тип объекта.
- `position` — текущая координата.
- `state` — состояние объекта.

Типы для MVP: `movable_block`, `task_item`, `obstacle`, `bonus`.

Состояния: `free`, `occupied`, `moving_by_ai`, `blocking`, `unavailable`.

## Platform

```json
{
  "id": "platform-1",
  "position": { "x": 1, "y": 0 },
  "status": "ready",
  "commandQueue": ["up", "right"],
  "currentCommandIndex": 0,
  "error": null
}
```

Обязательные поля:

- `id` — идентификатор платформы или симуляции.
- `position` — текущая координата.
- `status` — состояние выполнения.
- `commandQueue` — массив оставшихся команд плана.
- `currentCommandIndex` — индекс текущей выполняемой команды.
- `error` — последняя ошибка или `null`.

Статусы: `ready`, `executing`, `blocked`, `error`, `recovering`.

## AIAction

```json
{
  "type": "move_object",
  "targetObjectId": "box-1",
  "from": { "x": 2, "y": 2 },
  "to": { "x": 4, "y": 2 },
  "reason": "player_is_using_short_route"
}
```

Обязательные поля:

- `type` — тип действия ИИ.
- `targetObjectId` — объект, если действие связано с объектом.
- `from` — исходная позиция, если применимо.
- `to` — новая позиция, если применимо.
- `reason` — короткое машинное объяснение решения.

Типы действий: `move_object`, `block_path`, `change_route`, `delay_command`, `disable_zone`.

## GameEvent

```json
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
```

Обязательные поля:

- `id` — уникальный идентификатор события.
- `type` — тип события.
- `timestamp` — время события в ISO-формате.
- `payload` — данные события.

Журнал событий должен объяснять ход миссии: кто отправил команду, что сделал ИИ, почему движение стало невозможным, как изменилась платформа и чем закончился прогон.
