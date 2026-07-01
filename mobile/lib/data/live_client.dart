import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api_exception.dart';
import 'models.dart';

/// Клиент live-канала бэкенда (Server-Sent Events, GET /api/live).
///
/// Backend шлёт события в формате SSE:
///   event: duck.collected
///   data: {"id":"event-7", ... }
///   <пустая строка = конец события>
///
/// Здесь только одна попытка соединения. Переподключение делает вызывающий
/// (см. GameController) — так проще объяснять и тестировать.
class LiveClient {
  final String baseUrl;
  http.Client? _client;

  LiveClient({required this.baseUrl});

  /// Открывает поток и отдаёт [GameEvent] по мере поступления.
  Stream<GameEvent> connect() async* {
    final client = http.Client();
    _client = client;

    final request = http.Request('GET', Uri.parse('$baseUrl/api/live'))
      ..headers['Accept'] = 'text/event-stream';

    final response = await client.send(request);
    if (response.statusCode != 200) {
      client.close();
      throw ApiException(
        'live_error',
        'Live-поток недоступен (${response.statusCode}).',
      );
    }

    final lines =
        response.stream.transform(utf8.decoder).transform(const LineSplitter());
    final dataBuffer = StringBuffer();

    await for (final line in lines) {
      // Пустая строка — конец одного SSE-события.
      if (line.isEmpty) {
        if (dataBuffer.isNotEmpty) {
          final raw = dataBuffer.toString();
          dataBuffer.clear();
          final event = _tryParse(raw);
          if (event != null) yield event;
        }
        continue;
      }
      if (line.startsWith(':')) continue; // комментарий / heartbeat
      if (line.startsWith('data:')) {
        final chunk = line.substring(5);
        dataBuffer.write(chunk.startsWith(' ') ? chunk.substring(1) : chunk);
      }
      // Строку "event:" игнорируем — тип события есть внутри JSON.
    }
  }

  GameEvent? _tryParse(String raw) {
    try {
      return GameEvent.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null; // битую строку просто пропускаем
    }
  }

  void close() {
    _client?.close();
    _client = null;
  }
}
