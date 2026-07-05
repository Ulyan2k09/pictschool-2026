import 'dart:convert';

import 'package:duck_round/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Проверяем, что разбор JSON совпадает с реальным ответом backend
/// (GET /api/round). Если backend поменяет формат — тест это поймает.
void main() {
  const rawRoundResponse = '''
  {
    "round": {
      "id": "round-1",
      "status": "running",
      "activeActor": "robot",
      "turnNumber": 3,
      "moveLimitPerTurn": 5,
      "ducksTotal": 10,
      "ducksLeft": 8,
      "score": { "robot": 1, "agent": 1 },
      "field": {
        "width": 10,
        "height": 10,
        "obstacles": [
          { "id": "wall-1", "position": { "x": 3, "y": 2 } }
        ],
        "ducks": [
          { "id": "duck-1", "position": { "x": 1, "y": 0 }, "collectedBy": "robot" },
          { "id": "duck-2", "position": { "x": 3, "y": 1 }, "collectedBy": null }
        ]
      },
      "actors": {
        "robot": { "id": "robot", "position": { "x": 2, "y": 0 }, "direction": "E", "collectedDucks": 1, "lastError": null },
        "agent": { "id": "agent", "position": { "x": 9, "y": 9 }, "direction": "W", "collectedDucks": 1, "lastError": null }
      }
    }
  }
  ''';

  test('Round.fromJson читает состояние из ответа backend', () {
    final json = jsonDecode(rawRoundResponse) as Map<String, dynamic>;
    final round = Round.fromJson(json['round'] as Map<String, dynamic>);

    expect(round.id, 'round-1');
    expect(round.isRunning, isTrue);
    expect(round.activeActor, 'robot');
    expect(round.turnNumber, 3);
    expect(round.moveLimitPerTurn, 5);
    expect(round.ducksLeft, 8);
    expect(round.score.robot, 1);
    expect(round.score.agent, 1);
  });

  test('поле, препятствия и уточки разобраны верно', () {
    final json = jsonDecode(rawRoundResponse) as Map<String, dynamic>;
    final round = Round.fromJson(json['round'] as Map<String, dynamic>);

    expect(round.field.width, 10);
    expect(round.field.height, 10);
    expect(round.field.obstacles.single.position, const Position(3, 2));
    expect(round.field.ducks.length, 2);

    final duck1 = round.field.ducks.firstWhere((d) => d.id == 'duck-1');
    expect(duck1.isCollected, isTrue);
    expect(duck1.collectedBy, 'robot');

    final duck2 = round.field.ducks.firstWhere((d) => d.id == 'duck-2');
    expect(duck2.isCollected, isFalse);
  });

  test('участники (robot/agent) доступны по id', () {
    final json = jsonDecode(rawRoundResponse) as Map<String, dynamic>;
    final round = Round.fromJson(json['round'] as Map<String, dynamic>);

    expect(round.robot, isNotNull);
    expect(round.robot!.position, const Position(2, 0));
    expect(round.robot!.direction, 'E');
    expect(round.agent!.position, const Position(9, 9));
  });

  test('GameEvent.fromJson читает событие журнала', () {
    const rawEvent = '''
    {
      "id": "event-7",
      "roundId": "round-1",
      "turnNumber": 2,
      "type": "duck.collected",
      "timestamp": "2026-06-22T19:52:10Z",
      "actor": "agent",
      "payload": { "duckId": "duck-4", "score": { "robot": 1, "agent": 2 } }
    }
    ''';
    final event = GameEvent.fromJson(jsonDecode(rawEvent) as Map<String, dynamic>);

    expect(event.type, 'duck.collected');
    expect(event.actor, 'agent');
    expect(event.turnNumber, 2);
    expect(event.payload['duckId'], 'duck-4');
  });
}
