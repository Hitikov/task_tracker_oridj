import 'dart:math';

import 'package:shelf/shelf.dart';

/// Key used to store the request id in [Request.context].
const String requestIdContextKey = 'arij.requestId';

final RegExp _validRequestId = RegExp(r'^[A-Za-z0-9._-]{1,128}$');
final Random _random = Random.secure();

/// Adds an `X-Request-Id` header to every response.
///
/// A client-provided id is reused when it is safe; otherwise a random id is
/// generated. The value is also stored in [Request.context] for logging.
Middleware requestId() {
  return (Handler inner) {
    return (Request request) async {
      final provided = request.headers['x-request-id'];
      final id = provided != null && _validRequestId.hasMatch(provided)
          ? provided
          : _generateRequestId();

      final response = await inner(
        request.change(context: <String, Object>{requestIdContextKey: id}),
      );
      return response.change(headers: <String, String>{'x-request-id': id});
    };
  };
}

/// Returns the request id stored by [requestId], if present.
String? requestIdOf(Request request) {
  final value = request.context[requestIdContextKey];
  return value is String ? value : null;
}

String _generateRequestId() {
  final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}
