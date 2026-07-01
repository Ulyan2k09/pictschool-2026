import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/api_exception.dart';
import '../core/app_config.dart';
import '../data/game_repository.dart';
import '../data/models.dart';

/// Управляет состоянием экрана игры.
///
/// Принципы:
///   • Источник правды — backend. Контроллер только хранит последнее
///     полученное состояние и очередь команд, но НЕ считает игру.
///   • Обновление состояния идёт из трёх источников: действия пользователя,
///     периодический опрос и live-поток (SSE) как «толчок» к обновлению.
class GameController extends ChangeNotifier {
  final GameRepository _repo;

  GameController(this._repo);

  // ---- состояние, которое читает UI ----
  Round? _round;
  List<GameEvent> _events = const [];
  final List<int> _queue = <int>[]; // коды 1..4, которые собрал игрок
  bool _busy = false; // идёт действие пользователя (submit/start/reset)
  bool _loading = true; // идёт самая первая загрузка
  bool _online = true; // есть ли связь с backend
  ApiException? _error; // последняя ошибка от backend

  Round? get round => _round;
  List<GameEvent> get events => _events;
  List<int> get queue => List.unmodifiable(_queue);
  bool get busy => _busy;
  bool get loading => _loading;
  bool get online => _online;
  ApiException? get error => _error;

  int get moveLimit => _round?.moveLimitPerTurn ?? 5;
  String? get activeActor => _round?.activeActor;
  bool get canAddCommand =>
      (_round?.isRunning ?? false) && _queue.length < moveLimit && !_busy;
  bool get canSubmit =>
      (_round?.isRunning ?? false) && _queue.isNotEmpty && !_busy;

  // ---- внутреннее ----
  Timer? _pollTimer;
  Timer? _refreshDebounce;
  StreamSubscription<GameEvent>? _liveSub;
  bool _disposed = false;
  bool _refreshing = false;

  /// Первичная загрузка + подписки. Вызывать один раз при старте экрана.
  ///
  /// [startBackground] управляет опросом и live-потоком. В тестах передаём
  /// `false`, чтобы не оставлять «висящих» таймеров.
  Future<void> init({bool startBackground = true}) async {
    await refresh();
    _loading = false;
    _notify();
    if (startBackground) {
      _startPolling();
      _connectLive();
    }
  }

  /// Забрать актуальное состояние и журнал у backend.
  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final round = await _repo.fetchRound();
      final events = await _repo.fetchEvents();
      _round = round;
      _events = events;
      _online = true;
    } on ApiException catch (e) {
      if (e.code == 'network_error') _online = false;
      _error = e;
    } finally {
      _refreshing = false;
      _notify();
    }
  }

  Future<void> startRound() => _runAction(() => _repo.startRound());

  Future<void> resetRound() => _runAction(() async {
        _queue.clear();
        await _repo.resetRound();
      });

  /// Добавить команду в очередь хода. Только код — никакой симуляции движения.
  void addCommand(int code) {
    if (!canAddCommand) return;
    _queue.add(code);
    _notify();
  }

  void removeLastCommand() {
    if (_queue.isEmpty || _busy) return;
    _queue.removeLast();
    _notify();
  }

  void clearQueue() {
    if (_queue.isEmpty || _busy) return;
    _queue.clear();
    _notify();
  }

  /// Отправить собранный ход активного участника на backend.
  Future<void> submitTurn() async {
    final round = _round;
    if (round == null || !round.isRunning || _queue.isEmpty || _busy) return;
    _busy = true;
    _error = null;
    _notify();
    try {
      await _repo.submitTurn(
        actor: round.activeActor,
        commands: List<int>.of(_queue),
      );
      _queue.clear();
      await refresh();
    } on ApiException catch (e) {
      if (e.code == 'network_error') _online = false;
      _error = e;
    } finally {
      _busy = false;
      _notify();
    }
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    _notify();
  }

  // ---- вспомогательное ----

  Future<void> _runAction(Future<void> Function() action) async {
    if (_busy) return;
    _busy = true;
    _error = null;
    _notify();
    try {
      await action();
      await refresh();
    } on ApiException catch (e) {
      if (e.code == 'network_error') _online = false;
      _error = e;
    } finally {
      _busy = false;
      _notify();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(AppConfig.pollInterval, (_) {
      if (!_busy) refresh();
    });
  }

  void _connectLive() {
    // TODO(school): обрабатывать каждое событие точечно и устойчиво к обрывам
    // связи (задачи 9 и 15) — но по-прежнему без пересчёта игры на клиенте.
    _liveSub?.cancel();
    _liveSub = _repo.liveEvents().listen(
      (_) => _scheduleRefresh(),
      onError: (_) => _scheduleReconnect(),
      onDone: _scheduleReconnect,
      cancelOnError: true,
    );
  }

  /// Live-событие означает «что-то изменилось» → обновляем состояние.
  /// Дебаунс, чтобы пачка событий за один тик дала одно обновление.
  void _scheduleRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!_busy) refresh();
    });
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (!_disposed) _connectLive();
    });
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    _refreshDebounce?.cancel();
    _liveSub?.cancel();
    _repo.dispose();
    super.dispose();
  }
}
