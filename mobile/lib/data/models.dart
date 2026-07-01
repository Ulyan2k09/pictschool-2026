/// Модели данных, зеркалящие JSON бэкенда (Kotlin/Ktor).
///
/// Важно: это «глупые» модели. Здесь нет игровой логики — только разбор JSON,
/// который присылает backend. Все правила игры считает backend
/// (см. ARCHITECTURE.md — принцип «Backend — источник правды»).
library;

/// Клетка поля: {x, y}.
class Position {
  final int x;
  final int y;

  const Position(this.x, this.y);

  factory Position.fromJson(Map<String, dynamic> json) =>
      Position((json['x'] as num).toInt(), (json['y'] as num).toInt());

  @override
  bool operator ==(Object other) =>
      other is Position && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => '($x, $y)';
}

/// Постоянное препятствие на поле.
class Obstacle {
  final String id;
  final Position position;

  const Obstacle(this.id, this.position);

  factory Obstacle.fromJson(Map<String, dynamic> json) => Obstacle(
        json['id'] as String,
        Position.fromJson(json['position'] as Map<String, dynamic>),
      );
}

/// Уточка. Если [collectedBy] == null — ещё на поле.
class Duck {
  final String id;
  final Position position;
  final String? collectedBy; // "robot" | "agent" | null

  const Duck(this.id, this.position, this.collectedBy);

  bool get isCollected => collectedBy != null;

  factory Duck.fromJson(Map<String, dynamic> json) => Duck(
        json['id'] as String,
        Position.fromJson(json['position'] as Map<String, dynamic>),
        json['collectedBy'] as String?,
      );
}

/// Состояние одного участника (робота или агента).
class ActorState {
  final String id; // "robot" | "agent"
  final Position position;
  final String direction; // "N" | "E" | "S" | "W"
  final int collectedDucks;
  final String? lastError;

  const ActorState({
    required this.id,
    required this.position,
    required this.direction,
    required this.collectedDucks,
    required this.lastError,
  });

  factory ActorState.fromJson(Map<String, dynamic> json) => ActorState(
        id: json['id'] as String,
        position: Position.fromJson(json['position'] as Map<String, dynamic>),
        direction: json['direction'] as String,
        collectedDucks: (json['collectedDucks'] as num).toInt(),
        lastError: json['lastError'] as String?,
      );
}

/// Игровое поле: размер, препятствия, уточки.
class GameField {
  final int width;
  final int height;
  final List<Obstacle> obstacles;
  final List<Duck> ducks;

  const GameField({
    required this.width,
    required this.height,
    required this.obstacles,
    required this.ducks,
  });

  factory GameField.fromJson(Map<String, dynamic> json) => GameField(
        width: (json['width'] as num).toInt(),
        height: (json['height'] as num).toInt(),
        obstacles: (json['obstacles'] as List<dynamic>)
            .map((e) => Obstacle.fromJson(e as Map<String, dynamic>))
            .toList(),
        ducks: (json['ducks'] as List<dynamic>)
            .map((e) => Duck.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Счёт: сколько уточек собрал каждый.
class Score {
  final int robot;
  final int agent;

  const Score(this.robot, this.agent);

  factory Score.fromJson(Map<String, dynamic> json) => Score(
        (json['robot'] as num).toInt(),
        (json['agent'] as num).toInt(),
      );
}

/// Полное состояние раунда — то, что рисует приложение.
class Round {
  final String id;
  final String status; // "idle" | "running" | "completed" | "failed"
  final String activeActor; // "robot" | "agent"
  final int turnNumber;
  final int moveLimitPerTurn;
  final int ducksTotal;
  final int ducksLeft;
  final Score score;
  final GameField field;
  final Map<String, ActorState> actors;

  const Round({
    required this.id,
    required this.status,
    required this.activeActor,
    required this.turnNumber,
    required this.moveLimitPerTurn,
    required this.ducksTotal,
    required this.ducksLeft,
    required this.score,
    required this.field,
    required this.actors,
  });

  bool get isRunning => status == 'running';
  bool get isCompleted => status == 'completed';
  bool get isIdle => status == 'idle';

  ActorState? get robot => actors['robot'];
  ActorState? get agent => actors['agent'];

  factory Round.fromJson(Map<String, dynamic> json) {
    final actorsJson = (json['actors'] as Map<String, dynamic>);
    return Round(
      id: json['id'] as String,
      status: json['status'] as String,
      activeActor: json['activeActor'] as String,
      turnNumber: (json['turnNumber'] as num).toInt(),
      moveLimitPerTurn: (json['moveLimitPerTurn'] as num).toInt(),
      ducksTotal: (json['ducksTotal'] as num).toInt(),
      ducksLeft: (json['ducksLeft'] as num).toInt(),
      score: Score.fromJson(json['score'] as Map<String, dynamic>),
      field: GameField.fromJson(json['field'] as Map<String, dynamic>),
      actors: actorsJson.map(
        (key, value) =>
            MapEntry(key, ActorState.fromJson(value as Map<String, dynamic>)),
      ),
    );
  }
}

/// Событие из журнала игры (GET /api/events или поток /api/live).
class GameEvent {
  final String id;
  final String roundId;
  final int turnNumber;
  final String type; // напр. "duck.collected", "actor.moved"
  final String timestamp;
  final String? actor;
  final Map<String, dynamic> payload;

  const GameEvent({
    required this.id,
    required this.roundId,
    required this.turnNumber,
    required this.type,
    required this.timestamp,
    required this.actor,
    required this.payload,
  });

  factory GameEvent.fromJson(Map<String, dynamic> json) => GameEvent(
        id: json['id'] as String,
        roundId: json['roundId'] as String? ?? '',
        turnNumber: (json['turnNumber'] as num?)?.toInt() ?? 0,
        type: json['type'] as String,
        timestamp: json['timestamp'] as String? ?? '',
        actor: json['actor'] as String?,
        payload: (json['payload'] as Map<String, dynamic>?) ?? const {},
      );
}
