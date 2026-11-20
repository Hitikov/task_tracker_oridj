import 'package:shelf/shelf.dart';

const String _allowedMethods = 'GET, POST, PATCH, DELETE, OPTIONS';
const String _allowedHeaders = 'Authorization, Content-Type, X-Request-Id';

/// Adds CORS headers and answers preflight `OPTIONS` requests with `204`.
///
/// Stage 0 does not use cookies or credentials, so `*` is a safe default. The
/// allowed origin can be narrowed when the web client is introduced.
Middleware corsMiddleware({String allowedOrigin = '*'}) {
  return (Handler inner) {
    return (Request request) async {
      final headers = <String, String>{
        'access-control-allow-origin': allowedOrigin,
        'access-control-allow-methods': _allowedMethods,
        'access-control-allow-headers': _allowedHeaders,
        'access-control-max-age': '86400',
        'access-control-expose-headers': 'X-Request-Id',
      };

      if (request.method == 'OPTIONS') {
        return Response(204, headers: headers);
      }

      final response = await inner(request);
      return response.change(headers: headers);
    };
  };
}
