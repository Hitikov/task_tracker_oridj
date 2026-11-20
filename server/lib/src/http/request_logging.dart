import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';

import 'request_id.dart';

final Logger _log = Logger('arij.http');

/// Logs method, path, status code, duration and request id for every request.
Middleware requestLogging() {
  return (Handler inner) {
    return (Request request) async {
      final stopwatch = Stopwatch()..start();
      final response = await inner(request);
      stopwatch.stop();

      final requestId = requestIdOf(request) ?? '-';
      _log.info(
        'requestId=$requestId ${request.method} ${request.requestedUri.path} '
        '${response.statusCode} ${stopwatch.elapsedMilliseconds}ms',
      );
      return response;
    };
  };
}
