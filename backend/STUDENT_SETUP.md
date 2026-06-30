# Памятка для школьников: backend-трек

Эта мини-инструкция помогает подготовить ноутбук к работе с backend MVP.

## Что поставить

Обязательное ПО:

| ПО | Зачем нужно |
| --- | --- |
| Git | скачать проект и отправлять изменения |
| JDK 17 | запуск Kotlin/Ktor backend |
| IntelliJ IDEA Community | удобно читать и менять Kotlin-код |
| Браузер | открыть Swagger UI и проверять API |
| curl или Postman | отправлять HTTP-запросы к backend |

Gradle отдельно ставить не нужно: в проекте есть `./gradlew`.

Полезное, но не обязательное ПО:

| ПО | Зачем может пригодиться |
| --- | --- |
| Netcat (`nc`) | быстро имитировать TCP-симуляцию |
| Docker Desktop | запускать вспомогательные сервисы, если кураторы их дадут |
| VS Code | смотреть markdown, JSON и YAML |

## Проверка окружения

В терминале должны выполняться команды:

```bash
git --version
java -version
```

Для Java нужна версия `17`.

Пример подходящего вывода:

```text
openjdk version "17..."
```

## Как получить проект

```bash
git clone https://github.com/sunnysubmarines/pictschool-2026.git
cd pictschool-2026/backend
```

Если проект уже скачан:

```bash
cd pictschool-2026
git pull
cd backend
```

## Первый запуск backend

```bash
./gradlew run
```

После запуска backend доступен на:

```text
http://localhost:8080
```

Документация API:

```text
http://localhost:8080/api/docs
```

## Быстрая проверка API

Запустить раунд:

```bash
curl -X POST http://localhost:8080/api/round/start \
  -H 'Content-Type: application/json' \
  -d '{"scenarioId":"default"}'
```

Посмотреть состояние:

```bash
curl http://localhost:8080/api/round
```

Посмотреть события:

```bash
curl http://localhost:8080/api/events
```

## Как проверить ход без настоящей симуляции

Backend отправляет команды в симуляцию по TCP на порт `5055`.

В отдельном терминале можно временно запустить TCP-приемник:

```bash
nc -lk 5055
```

После этого отправить ход:

```bash
curl -X POST http://localhost:8080/api/turn/submit \
  -H 'Content-Type: application/json' \
  -d '{"actor":"robot","commands":[1,1,3,1,4]}'
```

В окне с `nc` должна появиться строка:

```text
1 1 3 1 4
```

Если `nc` не запущен, backend вернет ошибку `simulation_error`. Это нормально: значит, backend не смог подключиться к симуляции.

## Что можно менять в учебных заданиях

Хорошие места для первых изменений:

| Файл | Что менять |
| --- | --- |
| `src/main/kotlin/school/pict/backend/Scenario.kt` | стартовые позиции, уток, препятствия |
| `src/main/kotlin/school/pict/backend/LocalMovement.kt` | правила движения по полю |
| `src/main/kotlin/school/pict/backend/RoundEngine.kt` | правила хода, события, ошибки |
| `src/main/resources/openapi.yaml` | описание API для Swagger |

Перед изменениями полезно запускать тесты:

```bash
./gradlew test
```

После изменений тоже нужно запускать тесты. Если тесты упали, это не страшно: сообщение ошибки обычно показывает, какой сценарий сломался.

## Частые проблемы

### Порт 8080 занят

Можно запустить backend на другом порту:

```bash
HTTP_PORT=8081 ./gradlew run
```

Swagger тогда будет на:

```text
http://localhost:8081/api/docs
```

### Java не той версии

Если `java -version` показывает не `17`, нужно выбрать JDK 17 в IntelliJ IDEA или установить JDK 17 отдельно.

### `./gradlew: Permission denied`

На Linux/macOS:

```bash
chmod +x gradlew
./gradlew run
```

### Команда хода возвращает `simulation_error`

Нужно запустить симуляцию или временный TCP-приемник:

```bash
nc -lk 5055
```

## Минимальный набор перед занятием

Перед занятием стоит проверить, что получается:

1. Открыть проект в IntelliJ IDEA.
2. Запустить `./gradlew test`.
3. Запустить `./gradlew run`.
4. Открыть `http://localhost:8080/api/docs`.
5. Выполнить `POST /api/round/start` через Swagger, curl или Postman.
