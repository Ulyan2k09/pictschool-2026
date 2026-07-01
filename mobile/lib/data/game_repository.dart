import 'game_api.dart';
import 'live_client.dart';
import 'models.dart';

/// Абстракция доступа к игре. Экран и контроллер зависят только от неё —
/// поэтому в тестах легко подставить фейковую реализацию.
abstract class GameRepository {
  Future<Round> fetchRound();
  Future<void> startRound();
  Future<void> resetRound();
  Future<TurnAccepted> submitTurn({
    required String actor,
    required List<int> commands,
  });
  Future<List<GameEvent>> fetchEvents();

  /// Поток live-событий (одна попытка соединения).
  Stream<GameEvent> liveEvents();

  void dispose();
}

/// Боевая реализация: REST через [GameApi] + SSE через [LiveClient].
class HttpGameRepository implements GameRepository {
  final GameApi _api;
  final LiveClient _live;

  HttpGameRepository({required String baseUrl})
      : _api = GameApi(baseUrl: baseUrl),
        _live = LiveClient(baseUrl: baseUrl);

  @override
  Future<Round> fetchRound() => _api.fetchRound();

  @override
  Future<void> startRound() => _api.startRound();

  @override
  Future<void> resetRound() => _api.resetRound();

  @override
  Future<TurnAccepted> submitTurn({
    required String actor,
    required List<int> commands,
  }) =>
      _api.submitTurn(actor: actor, commands: commands);

  @override
  Future<List<GameEvent>> fetchEvents() => _api.fetchEvents();

  @override
  Stream<GameEvent> liveEvents() => _live.connect();

  @override
  void dispose() {
    _live.close();
    _api.dispose();
  }
}
