# Backend MVP: функциональное описание

Этот документ описывает реализованный backend для режима, где `robot` и `agent` по очереди собирают уточек на поле.

## Назначение

Backend является единственным источником правды для раунда:

- хранит состояние поля, участников, счета и уточек;
- проверяет очередность ходов;
- проверяет лимит и валидность команд;
- отправляет команды движения в симуляцию TCP-строкой;
- пишет журнал событий;
- отдает REST API и live-канал для клиента.

## Запуск

```bash
cd backend
./gradlew run
```

По умолчанию сервер доступен на `http://localhost:8080`.

Swagger UI:

```text
http://localhost:8080/api/docs
```

OpenAPI YAML:

```text
http://localhost:8080/api/docs/openapi.yaml
```

## Конфигурация

Значения читаются из environment variables или JVM system properties.

| Параметр | Значение по умолчанию | Описание |
| --- | --- | --- |
| `HTTP_HOST` | `0.0.0.0` | Host HTTP-сервера |
| `HTTP_PORT` | `8080` | Port HTTP-сервера |
| `SIM_TCP_HOST` | `127.0.0.1` | Host симуляции |
| `SIM_TCP_COMMAND_PORT` | `5055` | TCP-порт команд движения |
| `SIM_TCP_TELEMETRY_PORT` | `5056` | Зарезервированный порт телеметрии |
| `SIM_TCP_TIMEOUT_MILLIS` | `1000` | Timeout TCP-подключения |

## Игровая модель

Стартовый сценарий:

- поле `8 x 6`;
- `robot` стартует в `{ "x": 0, "y": 0 }`, направление `E`;
- `agent` стартует в `{ "x": 7, "y": 5 }`, направление `W`;
- на поле 8 уточек;
- на поле 2 постоянных препятствия;
- первым ходит `robot`;
- за ход разрешено от 1 до 5 команд.

Раунд завершается, когда все уточки собраны.

## Команды движения

Backend принимает массив чисел и отправляет в симуляцию строку с пробелами.

Пример входа:

```json
{
  "actor": "robot",
  "commands": [1, 1, 3, 1, 4]
}
```

TCP payload:

```text
1 1 3 1 4
```

Коды:

| Код | Действие |
| --- | --- |
| `1` | клетка вперед |
| `2` | клетка назад |
| `3` | поворот на 90 градусов влево |
| `4` | поворот на 90 градусов вправо |

Если симуляция не слушает `SIM_TCP_COMMAND_PORT`, backend возвращает `simulation_error` и пишет событие `turn.failed`.

## REST API

### `GET /api/round`

Возвращает текущее состояние раунда: статус, активного участника, номер хода, счет, поле, уточек и участников.

### `POST /api/round/start`

Запускает новый раунд и сбрасывает журнал событий.

Тело запроса:

```json
{
  "scenarioId": "default"
}
```

Ответ:

```json
{
  "roundId": "round-1",
  "status": "running",
  "activeActor": "robot"
}
```

### `POST /api/turn/submit`

Отправляет ход активного участника.

Условия успешного запроса:

- раунд в статусе `running`;
- `actor` совпадает с `activeActor`;
- `commands` не пустой;
- длина `commands` не больше 5;
- все команды входят в диапазон `1..4`;
- TCP-отправка в симуляцию завершилась успешно.

Успешный ответ:

```json
{
  "accepted": true,
  "eventId": "event-2",
  "forwardedAs": "1 1 3 1 4"
}
```

### `GET /api/events`

Возвращает журнал событий текущего раунда.

### `GET /api/live`

Открывает SSE-поток live-событий.

Формат:

```text
event: round.started
data: {"id":"event-1", ...}
```

### `POST /api/round/reset`

Сбрасывает раунд в `idle`, очищает журнал и пишет событие `round.reset`.

## События

Backend пишет события в in-memory журнал:

- `round.started`;
- `turn.submitted`;
- `simulation.command_sent`;
- `actor.moved`;
- `duck.collected`;
- `turn.completed`;
- `turn.failed`;
- `round.completed`;
- `round.reset`.

## Ошибки

Все ошибки возвращаются в едином формате:

```json
{
  "error": {
    "code": "unknown_command",
    "message": "Команда 7 не поддерживается.",
    "details": {
      "allowed": [1, 2, 3, 4]
    }
  }
}
```

Коды:

| Код | HTTP | Когда возникает |
| --- | --- | --- |
| `unknown_command` | `400` | Есть команда вне диапазона `1..4` |
| `turn_limit_exceeded` | `400` | Команд 0 или больше 5 |
| `wrong_actor_turn` | `400` | Ход отправил неактивный участник |
| `round_not_running` | `400` | Раунд не запущен или уже завершен |
| `simulation_error` | `502` | Не удалось отправить TCP-команду в симуляцию |

## Проверка

Тесты:

```bash
cd backend
./gradlew test
```

Быстрая ручная проверка:

```bash
curl -X POST http://localhost:8080/api/round/start \
  -H 'Content-Type: application/json' \
  -d '{"scenarioId":"default"}'

curl http://localhost:8080/api/round

curl http://localhost:8080/api/docs/openapi.yaml
```

Для успешного `POST /api/turn/submit` должна быть запущена симуляция, слушающая TCP-порт `5055`.
