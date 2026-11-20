import 'dart:convert';

import 'package:arij_server/src/http/api_exception.dart';
import 'package:arij_server/src/http/error_handler.dart';
import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  setUpAll(() {
    Logger.root.level = Level.OFF;
  });

  test('converts ApiException into the standard error envelope', () async {
    final handler = const Pipeline()
        .addMiddleware(errorHandler())
        .addHandler(
          (Request request) => throw const ApiException(
            400,
            'validation_error',
            'Некорректные данные запроса',
            details: <String, Object?>{'field': 'email'},
          ),
        );

    final response = await handler(
      Request('POST', Uri.parse('http://localhost/api/v1/auth/register')),
    );

    expect(response.statusCode, 400);
    expect(response.headers['content-type'], 'application/json; charset=utf-8');

    final error = _errorBody(await response.readAsString());
    expect(error['code'], 'validation_error');
    expect(error['message'], 'Некорректные данные запроса');
    expect(error['details'], <String, Object?>{'field': 'email'});
  });

  test('hides details of unexpected exceptions', () async {
    final handler = const Pipeline()
        .addMiddleware(errorHandler())
        .addHandler(
          (Request request) => throw StateError('secret database detail'),
        );

    final response = await handler(
      Request('GET', Uri.parse('http://localhost/health')),
    );

    expect(response.statusCode, 500);

    final raw = await response.readAsString();
    expect(raw, isNot(contains('secret database detail')));

    final error = _errorBody(raw);
    expect(error['code'], 'internal_error');
    expect(error['message'], 'Внутренняя ошибка сервера');
    expect(error['details'], isNull);
  });
}

Map<String, dynamic> _errorBody(String body) {
  final decoded = jsonDecode(body) as Map<String, dynamic>;
  return decoded['error'] as Map<String, dynamic>;
}
