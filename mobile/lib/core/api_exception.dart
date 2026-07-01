/// Ошибка, которую вернул backend в едином формате:
/// { "error": { "code": "...", "message": "...", "details": {...} } }
///
/// Коды из docs/API.md:
///   unknown_command, turn_limit_exceeded, wrong_actor_turn,
///   round_not_running, simulation_error
class ApiException implements Exception {
  final String code;
  final String message;
  final Map<String, dynamic> details;

  const ApiException(this.code, this.message, [this.details = const {}]);

  /// Разбирает тело ошибки backend. Если формат неожиданный — отдаёт общий код.
  factory ApiException.fromResponse(int statusCode, dynamic body) {
    if (body is Map<String, dynamic> && body['error'] is Map<String, dynamic>) {
      final error = body['error'] as Map<String, dynamic>;
      return ApiException(
        error['code'] as String? ?? 'http_$statusCode',
        error['message'] as String? ?? 'Ошибка запроса ($statusCode).',
        (error['details'] as Map<String, dynamic>?) ?? const {},
      );
    }
    return ApiException('http_$statusCode', 'Ошибка запроса ($statusCode).');
  }

  /// Проблема сети/связи (не дошли до backend).
  factory ApiException.network(Object cause) =>
      ApiException('network_error', 'Нет связи с сервером: $cause');

  @override
  String toString() => 'ApiException($code): $message';
}
