# Задание: C-прослойка управления платформой

## Зачем это нужно

В проекте есть две версии платформы:

- симуляция в Webots;
- будущая реальная платформа на ESP32 с шасси и моторами.

Нам нужно, чтобы логика сложного движения писалась один раз на C и могла работать в обеих средах. Поэтому управление разделено на два слоя:

```text
backend / AI visualizer
        |
        v
simulation-emulator/webots_bridge.py
        |
        v
controllers/supervisor/movement_layer.c
        |
        v
Webots supervisor + e-puck controllers
```

`webots_bridge.py` больше не переводит команды сам. Он прокидывает коды команд в Webots. C-прослойка `movement_layer.c` решает, как школьная команда разворачивается в низкоуровневые команды платформы.

## Базовые команды

Базовые команды приходят из backend:

| Код | Значение |
| --- | --- |
| `1` | вперед на одну клетку |
| `2` | назад на одну клетку |
| `3` | повернуть влево |
| `4` | повернуть вправо |

Внутри Webots-платформы используются низкоуровневые команды:

| Константа | Значение |
| --- | --- |
| `PLATFORM_CMD_FORWARD` | вперед |
| `PLATFORM_CMD_BACKWARD` | назад |
| `PLATFORM_CMD_TURN_LEFT` | повернуть влево |
| `PLATFORM_CMD_TURN_RIGHT` | повернуть вправо |

Они объявлены в:

```text
controllers/supervisor/movement_layer.h
```

## Уже реализованные комплексные команды

Сейчас в `movement_layer.c` есть примеры:

| Код | Команда | Во что разворачивается |
| --- | --- | --- |
| `10` | вперед на две клетки | `forward`, `forward` |
| `11` | разворот | `left`, `left` |
| `12` | шаг вправо | `right`, `forward`, `left` |
| `13` | шаг влево | `left`, `forward`, `right` |

Например, команда `12` позволяет сместиться вправо относительно текущего направления и снова смотреть туда же, куда робот смотрел до маневра.

## Где писать код

Главный файл задания:

```text
computer-systems/sim/summer_school/controllers/supervisor/movement_layer.c
```

Заголовочный файл:

```text
computer-systems/sim/summer_school/controllers/supervisor/movement_layer.h
```

Вам нужно добавлять новые команды в два места:

1. В `movement_layer.h` добавить код команды:

```c
#define SCHOOL_CMD_SQUARE 20
```

2. В `movement_layer.c` описать, во что она разворачивается:

```c
case SCHOOL_CMD_SQUARE: {
    const int commands[] = {
        PLATFORM_CMD_FORWARD,
        PLATFORM_CMD_TURN_RIGHT,
        PLATFORM_CMD_FORWARD,
        PLATFORM_CMD_TURN_RIGHT,
        PLATFORM_CMD_FORWARD,
        PLATFORM_CMD_TURN_RIGHT,
        PLATFORM_CMD_FORWARD,
        PLATFORM_CMD_TURN_RIGHT
    };
    return write_commands(platform_commands, max_commands, commands, 8);
}
```

Также добавьте новую команду в `movement_is_supported_command()`.

## Что можно реализовать

Идеи для расширения:

- `20` — проехать квадрат и вернуться в исходное направление;
- `21` — объехать препятствие справа;
- `22` — объехать препятствие слева;
- `23` — сделать разведочный зигзаг;
- `24` — подъехать к соседней клетке и вернуться назад;
- `25` — развернуться и отъехать на одну клетку.

Важно: одна школьная команда может разворачиваться в несколько низкоуровневых команд.

## Как проверить

1. Пересоберите supervisor (ВЫПОЛНЯЕТСЯ КНОПКОЙ BUILD-BUILD в webots) либо:

```bash
make -C computer-systems/sim/summer_school/controllers/supervisor
```

2. Перезапустите Webots world.

3. Запустите backend + bridge:

```bash
SIM_DRIVER=webots ./infrastructure/manual/start-backend-ai-stack.sh
```

4. Откройте AI Visualizer:

```text
http://127.0.0.1:5174/
```

5. Нажмите `Connect`, затем `New round`.

6. Отправьте команды роботу. В интерфейсе уже есть кнопки для `10`, `11`, `12`, `13`.

Можно также проверить через curl:

```bash
curl -X POST http://127.0.0.1:8080/api/turn/submit \
  -H 'Content-Type: application/json' \
  -d '{"actor":"robot","commands":[10,11,12]}'
```

## Важное ограничение

Backend должен пропускать новую команду. Для этого добавьте ее код в allow-list:

```text
backend/src/main/kotlin/school/pict/backend/RoundEngine.kt
```

Backend также должен понимать, какой итог у команды. Сейчас Python-эмулятор в:

```text
simulation-emulator/tcp_emulator.py
```

тоже знает про команды `10..13`. Если вы добавляете новую команду, нужно добавить ее и туда, иначе backend и Webots начнут расходиться по состоянию.

<!-- В будущем, когда будет ESP32-платформа, правильнее будет возвращать фактический результат движения с платформы обратно в backend. Тогда backend не придется заранее знать всю внутреннюю механику сложной команды. -->

## Критерии готовности

- Новая команда объявлена в `movement_layer.h`.
- Новая команда реализована в `movement_layer.c`.
- Supervisor компилируется без ошибок.
- Backend allow-list содержит новую команду.
- Python-эмулятор знает, как эта команда влияет на позицию и направление.
- Команда видна в Webots: робот выполняет ожидаемый маневр.
- Backend не возвращает `unknown_command`.
- В AI Visualizer положение робота после хода совпадает с ожидаемым.
