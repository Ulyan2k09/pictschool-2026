import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/app_config.dart';
import 'core/app_theme.dart';
import 'data/game_repository.dart';
import 'state/game_controller.dart';
import 'ui/game_screen.dart';

void main() {
  runApp(const DuckRoundApp());
}

/// Корень приложения.
///
/// Здесь мы «собираем» зависимости: боевой репозиторий (REST + SSE) →
/// контроллер состояния → экран. Для тестов эту же сборку можно повторить
/// с фейковым репозиторием (см. test/).
class DuckRoundApp extends StatelessWidget {
  const DuckRoundApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<GameController>(
      create: (_) => GameController(
        HttpGameRepository(baseUrl: AppConfig.apiBaseUrl),
      )..init(),
      child: MaterialApp(
        title: 'Duck Round',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        home: const GameScreen(),
      ),
    );
  }
}
