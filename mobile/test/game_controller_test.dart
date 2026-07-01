import 'package:duck_round/core/api_exception.dart';
import 'package:duck_round/state/game_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

/// Тесты логики очереди команд и отправки хода.
/// Игровые правила здесь не проверяются — их считает backend.
void main() {
  test('добавление команд уважает лимит хода', () async {
    final repo = FakeGameRepository();
    final controller = GameController(repo);
    await controller.init(startBackground: false); // без таймеров

    controller.addCommand(1);
    controller.addCommand(3);
    expect(controller.queue, [1, 3]);

    // Пытаемся добавить больше лимита (5) — лишнее не добавляется.
    for (var i = 0; i < 10; i++) {
      controller.addCommand(1);
    }
    expect(controller.queue.length, controller.moveLimit);
    expect(controller.canAddCommand, isFalse);

    controller.removeLastCommand();
    expect(controller.queue.length, controller.moveLimit - 1);

    controller.clearQueue();
    expect(controller.queue, isEmpty);

    controller.dispose();
  });

  test('submitTurn отправляет очередь на backend и очищает её', () async {
    final repo = FakeGameRepository();
    final controller = GameController(repo);
    await controller.init(startBackground: false);

    controller.addCommand(1);
    controller.addCommand(1);
    controller.addCommand(4);
    await controller.submitTurn();

    expect(repo.submittedCommands.single, [1, 1, 4]);
    expect(controller.queue, isEmpty);
    expect(controller.error, isNull);

    controller.dispose();
  });

  test('ошибка backend показывается и очередь не теряется', () async {
    final repo = FakeGameRepository()
      ..nextError = const ApiException(
        'turn_limit_exceeded',
        'В ходе должно быть от 1 до 5 команд.',
      );
    final controller = GameController(repo);
    await controller.init(startBackground: false);

    controller.addCommand(1);
    await controller.submitTurn();

    expect(controller.error, isNotNull);
    expect(controller.error!.code, 'turn_limit_exceeded');
    // При ошибке очередь остаётся — игрок может исправить и повторить.
    expect(controller.queue, [1]);

    controller.clearError();
    expect(controller.error, isNull);

    controller.dispose();
  });

  test('нельзя ходить, когда раунд не идёт', () async {
    final repo = FakeGameRepository(round: sampleRound(status: 'idle'));
    final controller = GameController(repo);
    await controller.init(startBackground: false);

    controller.addCommand(1);
    expect(controller.queue, isEmpty); // команды не принимаются
    expect(controller.canAddCommand, isFalse);
    expect(controller.canSubmit, isFalse);

    controller.dispose();
  });
}
