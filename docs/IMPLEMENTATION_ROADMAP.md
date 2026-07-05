# Roadmap реализации MVP

Документ обновлен под текущее состояние backend.

## Уже реализовано (факт по бэкенду)

- Round state с состояниями `idle`, `running`, `completed`, `failed`.
- Стартовый сценарий `10 x 10` с `robot`, `agent`, уточками и препятствиями.
- `POST /api/round/start`, `GET /api/round`, `POST /api/round/reset`.
- `POST /api/turn/submit` с валидацией:
  - активного участника;
  - длины команд (`1..5`);
  - допустимых кодов (`1, 2, 3, 4, 10, 11, 12, 13`).
- TCP-отправка команд в симуляцию (`SIM_TCP_HOST`, `SIM_TCP_COMMAND_PORT=5055`).
- Резерв телеметрии в конфиге (`SIM_TCP_TELEMETRY_PORT=5056`).
- Единый формат ошибок (`unknown_command`, `turn_limit_exceeded`, `wrong_actor_turn`, `round_not_running`, `simulation_error`).
- Журнал событий `GET /api/events` и live-поток `GET /api/live` (SSE).
- Подсчет уточек, обновление `ducksLeft`, завершение раунда событием `round.completed`.

## Текущий бэклог

### Приоритет P0 (для стабильного демо)

- Согласовать клиент с `GET /api/live` как SSE (без WebSocket-контракта).
- Подготовить повторяемый e2e-прогон: start -> turn -> events/live -> completed/reset.
- Добавить smoke-сценарий с недоступной симуляцией для проверки `simulation_error`.

### Приоритет P1 (после демо)

- Добавить обратный канал телеметрии на `SIM_TCP_TELEMETRY_PORT`.
- Перенести хранение состояния и событий из in-memory в персистентное хранилище.
- Расширить интеграционные тесты кейсами переподключения клиента к live-потоку.

## Чеклист закрытия roadmap

- Клиент корректно отрабатывает SSE-события и восстановление через `GET /api/round`.
- Все базовые сценарии из `docs/GAME_SCENARIOS.md` проходят без ручных правок.
- Ошибки валидации и TCP-сбои воспроизводимы и видны в API/журнале.
