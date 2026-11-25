import 'package:logging/logging.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';

import 'api_exception.dart';
import 'json_response.dart';
import 'request_id.dart';

final Logger _log = Logger('arij.http.error');

/// Converts exceptions into the standard JSON error envelope.
///
/// [ApiException] keeps its status code, code and message; anything else
/// becomes a generic `500 internal_error` without leaking details.
Middleware errorHandler() {
  return (Handler inner) {
    return (Request request) async {
      final requestId = requestIdOf(request) ?? '-';
      try {
        return await inner(request);
      } on HijackException {
        rethrow;
      } on ApiException catch (error) {
        _log.warning(
          'requestId=$requestId ${request.method} ${request.requestedUri.path} '
          'failed with ${error.statusCode} ${error.code}',
          error,
        );
        return errorResponse(
          error.statusCode,
          error.code,
          error.message,
          details: error.details,
        );
      } on ServerException catch (error, stackTrace) {
        // Invalid values that slipped past validation must not become 500:
        // map the SQLSTATE of a rejected literal/constraint to a client error.
        final code = error.code;
        if (code == '22P02' ||
            code == '22007' ||
            code == '23503' ||
            code == '23514') {
          _log.warning(
            'requestId=$requestId ${request.method} ${request.requestedUri.path} '
            'rejected by database constraint $code',
          );
          return errorResponse(
            400,
            'validation_error',
            'Некорректные данные запроса',
          );
        }
        _log.severe(
          'requestId=$requestId ${request.method} ${request.requestedUri.path} '
          'failed with a database error',
          error,
          stackTrace,
        );
        return errorResponse(
          500,
          'internal_error',
          'Внутренняя ошибка сервера',
        );
      } on Object catch (error, stackTrace) {
        _log.severe(
          'requestId=$requestId ${request.method} ${request.requestedUri.path} '
          'failed with an unexpected error',
          error,
          stackTrace,
        );
        return errorResponse(
          500,
          'internal_error',
          'Внутренняя ошибка сервера',
        );
      }
    };
  };
}
