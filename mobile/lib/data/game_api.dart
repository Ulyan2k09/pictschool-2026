import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api_exception.dart';
import 'models.dart';

/// Ответ backend на принятый ход (POST /api/turn/submit → 202).
class TurnAccepted {
  final bool accepted;
  final String eventId;
  final String forwardedAs; // строка, которую backend отправил в симуляцию

  const TurnAccepted(this.accepted, this.eventId, this.forwardedAs);

  factory TurnAccepted.fromJson(Map<String, dynamic> json) => TurnAccepted(
        json['accepted'] as bool? ?? false,
        json['eventId'] as String? ?? '',
        json['forwardedAs'] as String? ?? '',
      );
}

/// Тонкий REST-клиент к backend. Никакой игровой логики — только запросы.
///
/// Endpoints (см. docs/API.md):
///   GET  /api/round          — состояние раунда
///   POST /api/round/start    — начать раунд
///   POST /api/turn/submit    — отправить ход
///   GET  /api/events         — журнал событий
///   POST /api/round/reset    — сброс
class GameApi {
  final String baseUrl;
  final http.Client _client;
  final Duration timeout;

  GameApi({
    required this.baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 5),
  }) : _client = client ?? http.Client();

  Map<String, String> get _headers => const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  /// GET /api/round → текущее состояние.
  Future<Round> fetchRound() async {
    final json = await _get('/api/round');
    return Round.fromJson(json['round'] as Map<String, dynamic>);
  }

  /// POST /api/round/start → запустить новый раунд.
  Future<void> startRound({String scenarioId = 'default'}) async {
    await _post('/api/round/start', {'scenarioId': scenarioId});
  }

  /// POST /api/round/reset → сбросить раунд.
  Future<void> resetRound() async {
    await _post('/api/round/reset', const {});
  }

  /// POST /api/turn/submit → отправить ход активного участника.
  /// [commands] — коды команд, не более 5 штук (проверяет backend).
  Future<TurnAccepted> submitTurn({
    required String actor,
    required List<int> commands,
  }) async {
    final json = await _post('/api/turn/submit', {
      'actor': actor,
      'commands': commands,
    });
    return TurnAccepted.fromJson(json);
  }

  /// GET /api/events → журнал событий текущего раунда.
  Future<List<GameEvent>> fetchEvents() async {
    final json = await _get('/api/events');
    final events = (json['events'] as List<dynamic>?) ?? const [];
    return events
        .map((e) => GameEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ---- низкоуровневые помощники ----

  Future<Map<String, dynamic>> _get(String path) async {
    final http.Response response;
    try {
      response = await _client.get(_uri(path), headers: _headers).timeout(timeout);
    } catch (e) {
      throw ApiException.network(e);
    }
    return _decode(response);
  }

  Future<Map<String, dynamic>> _post(String path, Object body) async {
    final http.Response response;
    try {
      response = await _client
          .post(_uri(path), headers: _headers, body: jsonEncode(body))
          .timeout(timeout);
    } catch (e) {
      throw ApiException.network(e);
    }
    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    final dynamic parsed =
        response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return parsed is Map<String, dynamic> ? parsed : <String, dynamic>{};
    }
    throw ApiException.fromResponse(response.statusCode, parsed);
  }

  void dispose() => _client.close();
}
