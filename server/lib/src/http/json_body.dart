import 'dart:convert';
import 'dart:typed_data';

import 'package:shelf/shelf.dart';

import 'api_exception.dart';

/// Maximum accepted JSON request body (1 MiB).
const int maxJsonBodyBytes = 1024 * 1024;

/// Reads and decodes a JSON object body with a hard size limit.
///
/// The declared `Content-Length` is checked first; the stream is counted as
/// well so chunked requests cannot bypass the limit.
Future<Map<String, Object?>> readJsonBody(Request request) async {
  final declared = int.tryParse(request.headers['content-length'] ?? '');
  if (declared != null && declared > maxJsonBodyBytes) {
    throw const ApiException(
      413,
      'payload_too_large',
      'Слишком большой запрос',
    );
  }

  final bytes = BytesBuilder(copy: false);
  var count = 0;
  await for (final chunk in request.read()) {
    count += chunk.length;
    if (count > maxJsonBodyBytes) {
      throw const ApiException(
        413,
        'payload_too_large',
        'Слишком большой запрос',
      );
    }
    bytes.add(chunk);
  }

  Object? decoded;
  try {
    decoded = jsonDecode(utf8.decode(bytes.takeBytes(), allowMalformed: false));
  } on FormatException {
    decoded = null;
  }
  if (decoded is! Map<String, dynamic>) {
    throw const ApiException(
      400,
      'validation_error',
      'Некорректные данные запроса',
    );
  }
  return Map<String, Object?>.from(decoded);
}
