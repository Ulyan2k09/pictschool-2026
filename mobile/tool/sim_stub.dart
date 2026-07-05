// Заглушка симуляции для локального запуска приложения.
//
// Backend на каждый ход отправляет в симуляцию TCP-запрос с JSON:
//   { "actor": "robot", "commands": [1,1,3,4], "round": { ...текущее состояние... } }
// и ждёт в ответ JSON:
//   { "ok": true, "actor": "robot", "finalPosition": {...}, "finalDirection": "E",
//     "ducksCollected": [...], "error": null }
// Без ответа по этому протоколу ход падает с `simulation_error`.
//
// Эта заглушка отвечает по протоколу: просто проигрывает присланные команды
// (вперёд/назад/поворот) с учётом границ поля и препятствий — так же, как
// раньше считал сам backend. Это годится для локальной проверки приложения
// на обоих актёрах (robot и agent), но не содержит никакой стратегии.
//
// Запуск (из папки mobile/):
//   dart run tool/sim_stub.dart
//
// Настоящую симуляцию, с движением платформы и вменяемым ИИ за `agent`,
// делают треки computer-systems и AI — см. simulation-emulator/ в корне
// репозитория (--agent-mode auto считает ходы agent сам).

import 'dart:convert';
import 'dart:io';

const _directions = ['N', 'E', 'S', 'W'];

String _turnLeft(String direction) =>
    _directions[(_directions.indexOf(direction) - 1 + 4) % 4];

String _turnRight(String direction) =>
    _directions[(_directions.indexOf(direction) + 1) % 4];

Map<String, int> _move(
  Map<String, int> position,
  String direction,
  int step,
  Map<String, dynamic> field,
) {
  final candidate = Map<String, int>.of(position);
  switch (direction) {
    case 'N':
      candidate['y'] = candidate['y']! - step;
    case 'E':
      candidate['x'] = candidate['x']! + step;
    case 'S':
      candidate['y'] = candidate['y']! + step;
    case 'W':
      candidate['x'] = candidate['x']! - step;
  }

  final width = field['width'] as int;
  final height = field['height'] as int;
  final inside = candidate['x']! >= 0 &&
      candidate['x']! < width &&
      candidate['y']! >= 0 &&
      candidate['y']! < height;

  final obstacles = (field['obstacles'] as List).cast<Map<String, dynamic>>();
  final blocked = obstacles.any((obstacle) {
    final p = obstacle['position'] as Map<String, dynamic>;
    return p['x'] == candidate['x'] && p['y'] == candidate['y'];
  });

  return inside && !blocked ? candidate : position;
}

/// Проигрывает базовые команды 1..4 и возвращает ответ в формате SimulationCommandResult.
Map<String, dynamic> _handle(Map<String, dynamic> request) {
  final actor = request['actor'] as String;
  final commands =
      (request['commands'] as List).map((c) => (c as num).toInt()).toList();
  final round = request['round'] as Map<String, dynamic>;
  final field = round['field'] as Map<String, dynamic>;
  final actors = round['actors'] as Map<String, dynamic>;
  final actorState = actors[actor] as Map<String, dynamic>;

  var position = (actorState['position'] as Map<String, dynamic>)
      .map((key, value) => MapEntry(key, value as int));
  var direction = actorState['direction'] as String;

  for (final command in commands) {
    switch (command) {
      case 1:
        position = _move(position, direction, 1, field);
      case 2:
        position = _move(position, direction, -1, field);
      case 3:
        direction = _turnLeft(direction);
      case 4:
        direction = _turnRight(direction);
    }
  }

  final ducks = (field['ducks'] as List).cast<Map<String, dynamic>>();
  final collected = <String>[
    for (final duck in ducks)
      if (duck['collectedBy'] == null &&
          (duck['position'] as Map<String, dynamic>)['x'] == position['x'] &&
          (duck['position'] as Map<String, dynamic>)['y'] == position['y'])
        duck['id'] as String,
  ];

  return {
    'ok': true,
    'actor': actor,
    'finalPosition': position,
    'finalDirection': direction,
    'ducksCollected': collected,
    'error': null,
  };
}

Future<void> main() async {
  const host = '127.0.0.1';
  const port = 5055;

  final server = await ServerSocket.bind(host, port);
  stdout.writeln('[sim] заглушка слушает $host:$port (порт команд).');
  stdout.writeln('[sim] отвечает по JSON-протоколу backend. Ctrl+C — стоп.');

  await for (final socket in server) {
    final chunks = <int>[];
    socket.listen(
      (data) => chunks.addAll(data),
      onDone: () {
        try {
          final text = utf8.decode(chunks).trim();
          final request = jsonDecode(text) as Map<String, dynamic>;
          final response = _handle(request);
          stdout.writeln(
            '[sim] ${response['actor']}: команды ${request['commands']} '
            '-> ${response['finalPosition']}, ${response['finalDirection']}'
            '${(response['ducksCollected'] as List).isEmpty ? '' : ', уточки: ${response['ducksCollected']}'}',
          );
          socket.add(utf8.encode('${jsonEncode(response)}\n'));
        } catch (e) {
          stdout.writeln('[sim] ошибка обработки запроса: $e');
          socket.add(utf8.encode('${jsonEncode({
                'ok': false,
                'actor': 'unknown',
                'ducksCollected': <String>[],
                'error': '$e',
              })}\n'));
        } finally {
          socket.close();
        }
      },
      onError: (_) {},
      cancelOnError: false,
    );
  }
}
