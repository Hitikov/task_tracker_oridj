import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:task_tracker_oridj/api/api_client.dart';
import 'package:task_tracker_oridj/api/api_error.dart';

/// Фейковый HttpClientAdapter: возвращает фиксированный JSON-ответ и
/// фиксирует пришедшие [RequestOptions].
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({required this.body, required this.statusCode});

  final Object body;
  final int statusCode;
  final captured = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    captured.add(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      statusMessage: 'fake',
      headers: {
        'content-type': ['application/json']
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _makeDio(HttpClientAdapter adapter) {
  return Dio(
    BaseOptions(
      baseUrl: 'http://localhost:8080',
      receiveDataWhenStatusError: true,
    ),
  )..httpClientAdapter = adapter;
}

void main() {
  group('ApiClient', () {
    test('авторизационный заголовок передаётся с токеном', () async {
      final adapter = _FakeAdapter(body: {}, statusCode: 200);
      final client = ApiClient(
        dio: _makeDio(adapter),
        getToken: () async => 'tok-abc',
      );

      await client.get('/api/v1/projects');

      final headers = adapter.captured.single.headers;
      final hasAuth = headers.entries.any(
        (e) =>
            e.key.toLowerCase() == 'authorization' &&
            e.value == 'Bearer tok-abc',
      );
      expect(hasAuth, isTrue);
    });

    test('без токена заголовок не добавляется', () async {
      final adapter = _FakeAdapter(body: {}, statusCode: 200);
      final client = ApiClient(
        dio: _makeDio(adapter),
        getToken: () async => null,
      );

      await client.get('/api/v1/projects');

      final headers = adapter.captured.single.headers;
      final hasAuth =
          headers.keys.any((k) => k.toLowerCase() == 'authorization');
      expect(hasAuth, isFalse);
    });

    test('ошибка 401 с конвертом разбирается в ApiException', () async {
      final adapter = _FakeAdapter(
        body: {
          'error': {
            'code': 'unauthorized',
            'message': 'Требуется аутентификация',
            'details': null,
          },
        },
        statusCode: 401,
      );
      final client = ApiClient(dio: _makeDio(adapter));

      Object? error;
      try {
        await client.get('/api/v1/auth/me');
      } on ApiException catch (e) {
        error = e;
      }

      expect(error, isA<ApiException>());
      final apiError = error as ApiException;
      expect(apiError.code, 'unauthorized');
      expect(apiError.message, 'Требуется аутентификация');
      expect(apiError.isUnauthorized, isTrue);
      expect(apiError.details, isNull);
    });

    test('details из конверта сохраняются', () async {
      final adapter = _FakeAdapter(
        body: {
          'error': {
            'code': 'email_taken',
            'message': 'Пользователь с таким email уже существует',
            'details': {'field': 'email'},
          },
        },
        statusCode: 409,
      );
      final client = ApiClient(dio: _makeDio(adapter));

      Object? error;
      try {
        await client.post('/api/v1/auth/register', body: {
          'email': 'ada@example.com',
        });
      } on ApiException catch (e) {
        error = e;
      }

      expect(error, isA<ApiException>());
      final apiError = error as ApiException;
      expect(apiError.code, 'email_taken');
      expect(apiError.details, {'field': 'email'});
    });

    test('без конверта — код по HTTP-статусу', () async {
      final adapter = _FakeAdapter(body: {'message': 'oops'}, statusCode: 500);
      final client = ApiClient(dio: _makeDio(adapter));

      Object? error;
      try {
        await client.get('/api/v1/health');
      } on ApiException catch (e) {
        error = e;
      }

      expect(error, isA<ApiException>());
      final apiError = error as ApiException;
      expect(apiError.code, 'internal_error');
      expect(apiError.message, 'Ошибка сервера (500)');
    });

    test('успешный ответ возвращает данные', () async {
      final adapter = _FakeAdapter(
        body: {
          'id': 'user-1',
          'email': 'ada@example.com',
          'name': 'Ада',
          'createdAt': '2026-11-15T12:00:00.000Z',
          'updatedAt': '2026-11-15T12:00:00.000Z',
        },
        statusCode: 200,
      );
      final client = ApiClient(dio: _makeDio(adapter));

      final data = await client.get('/api/v1/auth/me');

      expect(data['id'], 'user-1');
      expect(data['email'], 'ada@example.com');
    });

    test('post передаёт body и разбирает ошибку 409', () async {
      final adapter = _FakeAdapter(
        body: {
          'error': {
            'code': 'project_key_taken',
            'message': 'Проект с таким ключом уже существует',
            'details': {'field': 'key'},
          },
        },
        statusCode: 409,
      );
      final client = ApiClient(dio: _makeDio(adapter));

      Object? error;
      try {
        await client.post('/api/v1/projects', body: {'key': 'ARIJ'});
      } on ApiException catch (e) {
        error = e;
      }

      expect(error, isA<ApiException>());
      final apiError = error as ApiException;
      expect(apiError.code, 'project_key_taken');
      expect(apiError.details, {'field': 'key'});
      expect(adapter.captured.single.data, {'key': 'ARIJ'});
    });

    test('getList возвращает массив объектов', () async {
      final adapter = _FakeAdapter(
        body: [
          {'key': 'ARIJ', 'name': 'Arij MVP'},
        ],
        statusCode: 200,
      );
      final client = ApiClient(dio: _makeDio(adapter));

      final list = await client.getList('/api/v1/projects');

      expect(list, hasLength(1));
      expect(list.single['key'], 'ARIJ');
    });
  });
}
