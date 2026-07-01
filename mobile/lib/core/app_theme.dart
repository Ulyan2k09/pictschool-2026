import 'package:flutter/material.dart';

/// Тема оформления (Material 3) и игровая палитра.
///
/// Меняя [seed] и цвета ниже, легко перекрасить всё приложение — хорошая
/// первая задача для участников трека Mobile.
class AppTheme {
  const AppTheme._();

  /// Базовый цвет, из которого Material 3 строит всю палитру.
  // TODO(school): поменяйте seed и цвета ниже — перекрасится всё приложение (задача 1).
  static const Color seed = Color(0xFF4F46E5); // индиго

  // Игровые цвета объектов на поле.
  static const Color duck = Color(0xFFFFC107); // уточка — янтарный
  static const Color robot = Color(0xFF2563EB); // робот — синий
  static const Color agent = Color(0xFFEF4444); // агент — красный
  static const Color obstacle = Color(0xFF64748B); // препятствие — сланцевый

  /// Цвет участника по его id ("robot"/"agent").
  static Color actorColor(String actorId) =>
      actorId == 'robot' ? robot : agent;

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      cardTheme: CardThemeData(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
