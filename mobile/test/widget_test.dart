import 'package:duck_round/state/game_controller.dart';
import 'package:duck_round/ui/game_screen.dart';
import 'package:duck_round/ui/widgets/board_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'fakes.dart';

/// Widget-тест главного экрана: рендер и базовое взаимодействие.
/// Работает на фейковом репозитории — без реального backend.
void main() {
  Future<GameController> pumpGame(WidgetTester tester,
      {FakeGameRepository? repo}) async {
    // Крупная поверхность, чтобы весь экран поместился и был кликабелен.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repository = repo ?? FakeGameRepository();
    final controller = GameController(repository);
    await controller.init(startBackground: false);
    await tester.pumpWidget(
      ChangeNotifierProvider<GameController>.value(
        value: controller,
        child: const MaterialApp(home: GameScreen()),
      ),
    );
    await tester.pump();
    return controller;
  }

  testWidgets('экран показывает поле, счёт и панель управления',
      (tester) async {
    await pumpGame(tester);

    expect(find.text('Duck Round'), findsOneWidget);
    expect(find.byType(BoardView), findsOneWidget);
    expect(find.text('Робот'), findsWidgets);
    expect(find.text('Агент'), findsWidgets);
    expect(find.text('Вперёд'), findsOneWidget);
    expect(find.text('Старт раунда'), findsOneWidget);
  });

  testWidgets('нажатие команды добавляет её в очередь хода', (tester) async {
    final controller = await pumpGame(tester);

    expect(controller.queue, isEmpty);

    await tester.tap(find.text('Вперёд'));
    await tester.pump();
    await tester.tap(find.text('Влево'));
    await tester.pump();

    expect(controller.queue, [1, 3]);
    // Счётчик очереди на экране показывает 2/5.
    expect(find.text('2/5'), findsOneWidget);
  });

  testWidgets('кнопки хода заблокированы, если раунд не запущен',
      (tester) async {
    final controller = await pumpGame(
      tester,
      repo: FakeGameRepository(round: sampleRound(status: 'idle')),
    );

    await tester.tap(find.text('Вперёд'));
    await tester.pump();

    expect(controller.queue, isEmpty);
    expect(find.text('Нажмите «Старт», чтобы начать раунд.'), findsOneWidget);
  });
}
