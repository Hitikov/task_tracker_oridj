import 'package:shelf/shelf.dart';

import '../http/json_response.dart';
import '../version.dart';

/// Handles `GET /health`.
///
/// The endpoint is intentionally independent from PostgreSQL: it only reports
/// that the HTTP server is alive. Migrations are applied at startup instead.
Response healthHandler(Request request) {
  return jsonResponse(<String, Object?>{
    'status': 'ok',
    'service': serviceName,
    'version': serverVersion,
    'time': DateTime.now().toUtc().toIso8601String(),
  });
}
