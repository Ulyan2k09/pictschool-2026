/// Конфигурация приложения.
///
/// Базовый адрес бэкенда можно переопределить при запуске:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
///
/// Подсказки по платформам:
///   • macOS / Windows / Linux desktop, Chrome (web), iOS-симулятор → http://localhost:8080
///   • Android-эмулятор                                            → http://10.0.2.2:8080
///   • Реальный телефон в той же Wi-Fi сети                        → http://IP-компьютера:8080
class AppConfig {
  const AppConfig._();

  /// Адрес бэкенда (Kotlin/Ktor). По умолчанию — локальный сервер.
  // TODO(school): сделать экран настроек, где адрес можно ввести и сохранить (задача 6).
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  /// Как часто опрашивать состояние раунда как «страховку» к live-потоку.
  static const Duration pollInterval = Duration(seconds: 3);
}
