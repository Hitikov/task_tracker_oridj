import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'config/app_config.dart';
import 'db/database.dart';
import 'http/cors_middleware.dart';
import 'http/error_handler.dart';
import 'http/json_response.dart';
import 'http/request_id.dart';
import 'http/request_logging.dart';
import 'repositories/user_repository.dart';
import 'routes/auth_routes.dart';
import 'routes/health_routes.dart';
import 'services/auth_service.dart';

/// Builds the HTTP handler for the Arij API.
///
/// The pipeline order is significant:
/// 1. request id — available to logging and error handling;
/// 2. request logging — records the final status and duration;
/// 3. CORS — adds headers to success and error responses;
/// 4. error handling — converts exceptions into the JSON error envelope;
/// 5. router.
///
/// Auth routes are always connected (stage 1). The projects stream mounts
/// more routes later; [AuthRoutes] is the boundary for auth-specific paths.
///
/// [userRepository]/[jwtSecret] exist for tests: when omitted, production
/// wiring is lazy — [AppConfig] is loaded from the environment only when an
/// auth route is actually hit, so `GET /health` keeps working without env
/// or a database.
Handler buildHandler({UserRepository? userRepository, String? jwtSecret}) {
  late final AppConfig config = AppConfig.fromEnvironment(Platform.environment);
  late final UserRepository repository =
      userRepository ?? PostgresUserRepository(Database(config));
  late final AuthService authService = AuthService(
    repository: repository,
    jwtSecret: jwtSecret ?? config.jwtSecret,
  );
  // Routes are wrapped in closures: `AuthRoutes(authService)` must not
  // evaluate the lazy service, otherwise `GET /health` in tests would
  // require a configured environment.
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
        ..all('/health', _methodNotAllowed(const <String>['GET']))
        ..post(
          '/api/v1/auth/register',
          (Request request) => AuthRoutes(authService).register(request),
        )
        ..post(
          '/api/v1/auth/login',
          (Request request) => AuthRoutes(authService).login(request),
        )
        ..get(
          '/api/v1/auth/me',
          (Request request) => AuthRoutes(authService).me(request),
        );

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
