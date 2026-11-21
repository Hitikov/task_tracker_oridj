import 'package:dio/dio.dart';

/// Доменное исключение ошибки API.
///
/// Все ошибки API укладываются в единый конверт OpenAPI
/// (`{"error": {"code", "message", "details"}}`); это исключение —
/// разобранный конверт или ошибка при отсутствии конверта
/// (например, ответ 5xx от прокси).
class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.details,
  });

  /// Машиночитаемый код ошибки (snake_case, согласно OpenAPI).
  final String code;

  /// Пригодное для показа пользователю сообщение.
  final String message;

  /// Структурированный контекст ошибки или null.
  final Object? details;

  /// true, если сессия потеряна (токен невалиден).
  bool get isUnauthorized => code == 'unauthorized';

  @override
  String toString() => 'ApiException($code): $message';
}

/// Преобразование [DioException] в [ApiException] по конверту OpenAPI.
extension DioExceptionAsApi on DioException {
  ApiException asApiException() {
    final statusCode = response?.statusCode;
    final data = response?.data;
    final envelope = data is Map ? data['error'] : null;

    final code = (envelope is Map ? envelope['code'] : null) as String? ??
        _defaultCode(statusCode) ??
        'internal_error';

    final message = (envelope is Map ? envelope['message'] : null) as String? ??
        (statusCode != null ? 'Ошибка сервера ($statusCode)' : 'Ошибка сети');

    final details = envelope is Map ? envelope['details'] : null;

    return ApiException(code: code, message: message, details: details);
  }
}

/// Код ошибки по HTTP-статусу, если конверт сервера отсутствует.
String? _defaultCode(int? statusCode) {
  if (statusCode == null) return null;
  return switch (statusCode) {
    400 => 'validation_error',
    401 => 'unauthorized',
    403 => 'forbidden',
    404 => 'not_found',
    409 => 'conflict',
    _ => 'internal_error',
  };
}
