import 'dart:convert';

import 'package:shelf/shelf.dart';

/// Content type used by every JSON response of the API.
const String jsonContentType = 'application/json; charset=utf-8';

/// Encodes [body] as JSON and returns a response with the JSON content type.
Response jsonResponse(
  Object? body, {
  int statusCode = 200,
  Map<String, String> headers = const <String, String>{},
}) {
  return Response(
    statusCode,
    body: jsonEncode(body),
    headers: <String, String>{'content-type': jsonContentType, ...headers},
  );
}

/// Builds the standard API error envelope.
Response errorResponse(
  int statusCode,
  String code,
  String message, {
  Object? details,
  Map<String, String> headers = const <String, String>{},
}) {
  return jsonResponse(
    <String, Object?>{
      'error': <String, Object?>{
        'code': code,
        'message': message,
        'details': details,
      },
    },
    statusCode: statusCode,
    headers: headers,
  );
}
