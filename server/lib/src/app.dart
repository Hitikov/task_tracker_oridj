import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'http/cors_middleware.dart';
import 'http/error_handler.dart';
import 'http/json_response.dart';
import 'http/request_id.dart';
import 'http/request_logging.dart';
import 'routes/health_routes.dart';

/// Builds the HTTP handler for the Arij API.
///
/// The pipeline order is significant:
/// 1. request id — available to logging and error handling;
/// 2. request logging — records the final status and duration;
/// 3. CORS — adds headers to success and error responses;
/// 4. error handling — converts exceptions into the JSON error envelope;
/// 5. router.
Handler buildHandler() {
  final router =
      Router(
          notFoundHandler: (Request request) => errorResponse(
            404,
            'not_found',
            'Маршрут не найден',
            details: <String, Object?>{'path': request.requestedUri.path},
          ),
        )
        ..get('/health', healthHandler)
        ..all('/health', _methodNotAllowed(const <String>['GET']));

  return const Pipeline()
      .addMiddleware(requestId())
      .addMiddleware(requestLogging())
      .addMiddleware(corsMiddleware())
      .addMiddleware(errorHandler())
      .addHandler(router.call);
}

Handler _methodNotAllowed(List<String> allowedMethods) {
  return (Request request) => errorResponse(
    405,
    'method_not_allowed',
    'Метод ${request.method} не поддерживается для этого маршрута',
    details: <String, Object?>{
      'method': request.method,
      'allowedMethods': allowedMethods,
    },
    headers: <String, String>{'allow': allowedMethods.join(', ')},
  );
}
