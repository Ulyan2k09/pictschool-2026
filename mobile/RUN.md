# Как запустить мобильное приложение (Flutter)

Пошаговая инструкция для участников: что поставить, как запустить и как собрать под устройство. Приложение написано на **Flutter/Dart** и работает в паре с нашим **backend** (Kotlin/Ktor, порт 8080).

> Важно: приложение **ничего не считает само** — оно берёт состояние игры у backend и отправляет туда команды. Поэтому для игры нужен **запущенный backend** (см. шаг 3).

---

## 0. Что чем компилируется (коротко)

«Компилятор» здесь — это **Flutter SDK** (внутри него Dart). Отдельно ничего ставить не надо: одна команда `flutter run` сама компилирует под выбранную платформу:

| Платформа | Во что компилируется | Что нужно дополнительно |
| --- | --- | --- |
| **Web** | JavaScript/WASM | только браузер Chrome |
| **Android** | нативный ARM (через Gradle) | Android Studio (Android SDK) |
| **iOS** | нативный ARM (через Xcode) | только macOS + Xcode |
| **Desktop** | нативное приложение | Windows: Visual Studio (C++); macOS: Xcode |

Самый простой способ проверить, что всё работает — запустить в **Chrome** (шаг 4). Для этого хватает только Flutter SDK и браузера.

---

## 1. Поставить один раз

1. **Flutter SDK** (Dart идёт внутри): https://docs.flutter.dev/get-started/install
   После установки проверьте, что `flutter` виден в терминале:
   ```bash
   flutter --version
   ```
2. **Редактор:** VS Code + расширения **Flutter** и **Dart** (или Android Studio).
3. **Под нужную платформу** (можно позже): Android Studio для Android, Xcode для iOS/macOS.
4. Проверка окружения:
   ```bash
   flutter doctor
   ```
   Нужна хотя бы одна зелёная цель: **Chrome**, desktop или эмулятор. Красные пункты `flutter doctor` подскажет, как чинить.

---

## 2. Получить проект и зависимости

```bash
git clone git@github.com:sunnysubmarines/pictschool-2026.git
cd pictschool-2026/mobile
flutter pub get
```

`flutter pub get` скачивает пакеты (`http`, `provider` и т.д.) — делается один раз и после каждого изменения `pubspec.yaml`.

---

## 3. Запустить backend и заглушку симуляции

Приложению нужен сервер. Откройте **два отдельных терминала**:

```bash
# Терминал A — заглушка симуляции (из папки mobile).
# Без неё каждый ход падает с ошибкой simulation_error.
cd pictschool-2026/mobile
dart run tool/sim_stub.dart
```

```bash
# Терминал B — backend (нужен JDK 17!).
cd pictschool-2026/backend
./gradlew run
```

- Когда прогресс Gradle встанет на `> ... 83% EXECUTING` и «зависнет» — это **нормально**, сервер работает.
- Проверка, что backend жив: откройте **http://localhost:8080/api/docs** (Swagger). Корень `/` вернёт 404 — это ок, это API, а не сайт.
- Если backend падает с ошибкой — почти всегда дело в версии Java. Нужен **JDK 17** (`java -version` → 17).

---

## 4. Запустить приложение

Список подключённых целей:

```bash
flutter devices
```

Запуск (из папки `mobile`). Самое простое — **Chrome**:

```bash
flutter run -d chrome
```

Другие цели:

| Куда | Команда |
| --- | --- |
| **Web (Chrome)** | `flutter run -d chrome` |
| **macOS** | `flutter run -d macos` |
| **Windows** | `flutter run -d windows` |
| **Android-эмулятор** | `flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8080` |
| **iOS-симулятор** | `flutter run -d <id-симулятора>` |

Во время работы `flutter run`: клавиша `r` — быстрый hot reload, `R` — hot restart, `q` — выход.

Эмуляторы: `flutter emulators`, запуск — `flutter emulators --launch <id>`.

---

## 5. Адрес backend (частая причина «нет связи»)

По умолчанию приложение стучится на `http://localhost:8080`. Это верно для **Web, desktop и iOS-симулятора**. В других случаях адрес нужно указать через `--dart-define`:

| Где запущено приложение | Адрес backend | Как передать |
| --- | --- | --- |
| Web / desktop / iOS-симулятор | `http://localhost:8080` | по умолчанию, ничего не нужно |
| **Android-эмулятор** | `http://10.0.2.2:8080` | `--dart-define=API_BASE_URL=http://10.0.2.2:8080` |
| **Реальный телефон** (та же Wi-Fi) | `http://<IP-компьютера>:8080` | `--dart-define=API_BASE_URL=http://192.168.х.х:8080` |

> У Android-эмулятора `localhost` — это он сам, поэтому до компьютера он достучится по спец-адресу `10.0.2.2`. IP компьютера смотрите: macOS/Linux — `ifconfig`, Windows — `ipconfig`.

---

## 6. Собрать (скомпилировать) под платформу

Когда нужен готовый файл, а не запуск через `flutter run`:

```bash
flutter build apk        # Android → build/app/outputs/flutter-apk/app-release.apk
flutter build appbundle  # Android (для Google Play)
flutter build ios        # iOS (дальше архив/подпись в Xcode)
flutter build macos      # macOS → build/macos/Build/Products/Release/
flutter build windows    # Windows → build/windows/x64/runner/Release/
flutter build web        # Web → build/web/ (статические файлы)
```

Не забудьте про адрес backend при релизе: `flutter build apk --dart-define=API_BASE_URL=http://<адрес-сервера>:8080`.

---

## 7. Запуск на реальном устройстве

**Android-телефон:**
1. Включите режим разработчика и **отладку по USB** (Настройки → «О телефоне» → 7 раз тапнуть по номеру сборки → Настройки для разработчиков → USB debugging).
2. Подключите кабелем, разрешите отладку на телефоне.
3. `flutter devices` — телефон должен появиться.
4. `flutter run --dart-define=API_BASE_URL=http://<IP-компьютера>:8080` (телефон и компьютер в одной Wi-Fi).

**iPhone (только на macOS):**
1. Откройте `mobile/ios/Runner.xcworkspace` в Xcode, в *Signing & Capabilities* выберите свою Apple ID (Team).
2. Подключите iPhone, на телефоне: Настройки → Основные → VPN и управление устройством → доверить сертификат разработчика.
3. `flutter run` (выбрать iPhone) или запустить из Xcode.

---

## 8. Частые ошибки

| Симптом | Причина и решение |
| --- | --- |
| В приложении «Нет связи с сервером» | backend не запущен **или** неверный `API_BASE_URL` (Android-эмулятору нужен `10.0.2.2`). |
| Ошибка `simulation_error` при ходе | не запущена заглушка симуляции — включите `dart run tool/sim_stub.dart` (терминал A). |
| `flutter: command not found` | Flutter SDK не добавлен в `PATH`. См. инструкцию установки Flutter. |
| backend: `Address already in use` | порт 8080 занят другим приложением. Запустите backend на другом порту: `HTTP_PORT=8081 ./gradlew run`, а приложение — с `--dart-define=API_BASE_URL=http://localhost:8081`. |
| Пустой список в `flutter devices` | нет запущенного эмулятора/браузера. Запустите Chrome-цель или эмулятор. |
| Android: приложение не видит сервер по http | уже настроено (`usesCleartextTraffic`), проверьте адрес и что backend доступен с эмулятора. |

---

## Кратко (шпаргалка)

```bash
# 1) зависимости
cd pictschool-2026/mobile && flutter pub get
# 2) сервер (2 терминала)
dart run tool/sim_stub.dart              # терминал A (из mobile)
cd ../backend && ./gradlew run           # терминал B (JDK 17)
# 3) приложение
cd ../mobile && flutter run -d chrome
```

Подробнее об архитектуре — [ARCHITECTURE.md](ARCHITECTURE.md), задачи на доработку — [STUDENT_TASKS.md](STUDENT_TASKS.md).
