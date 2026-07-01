import 'dart:async';

import 'package:duck_round/core/api_exception.dart';
import 'package:duck_round/data/game_api.dart';
import 'package:duck_round/data/game_repository.dart';
import 'package:duck_round/data/models.dart';

/// Готовый образец раунда для тестов (упрощённая версия стартового поля).
Round sampleRound({String status = 'running', String activeActor = 'robot'}) {
  final ducks = <Duck>[
    const Duck('duck-1', Position(1, 0), null),
    const Duck('duck-2', Position(3, 1), null),
  ];
  return Round(
    id: 'round-1',
    status: status,
    activeActor: activeActor,
    turnNumber: 1,
    moveLimitPerTurn: 5,
    ducksTotal: ducks.length,
    ducksLeft: ducks.where((d) => !d.isCollected).length,
    score: const Score(0, 0),
    field: GameField(
      width: 8,
      height: 6,
      obstacles: const [Obstacle('wall-1', Position(3, 2))],
      ducks: ducks,
    ),
    actors: const {
      'robot': ActorState(
        id: 'robot',
        position: Position(0, 0),
        direction: 'E',
        collectedDucks: 0,
        lastError: null,
      ),
      'agent': ActorState(
        id: 'agent',
        position: Position(7, 5),
        direction: 'W',
        collectedDucks: 0,
        lastError: null,
      ),
    },
  );
}

/// Фейковый репозиторий: не ходит в сеть, всё в памяти. Удобно для тестов.
class FakeGameRepository implements GameRepository {
  Round current;
  List<GameEvent> eventLog;

  /// Если задано — [submitTurn] бросит эту ошибку (эмуляция ответа backend).
  ApiException? nextError;

  /// Записанные ходы — что отправили на «backend».
  final List<List<int>> submittedCommands = <List<int>>[];

  final StreamController<GameEvent> _live =
      StreamController<GameEvent>.broadcast();

  FakeGameRepository({Round? round, List<GameEvent>? events})
      : current = round ?? sampleRound(),
        eventLog = events ?? const [];

  @override
  Future<Round> fetchRound() async => current;

  @override
  Future<List<GameEvent>> fetchEvents() async => eventLog;

  @override
  Future<void> startRound() async {
    current = sampleRound(status: 'running');
  }

  @override
  Future<void> resetRound() async {
    current = sampleRound(status: 'idle');
  }

  @override
  Future<TurnAccepted> submitTurn({
    required String actor,
    required List<int> commands,
  }) async {
    final error = nextError;
    if (error != null) throw error;
    submittedCommands.add(List<int>.of(commands));
    return TurnAccepted(true, 'event-1', commands.join(' '));
  }

  @override
  Stream<GameEvent> liveEvents() => _live.stream;

  @override
  void dispose() {
    _live.close();
  }
}
