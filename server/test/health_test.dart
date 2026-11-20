import 'dart:convert';

import 'package:arij_server/arij_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  late Handler handler;

  setUp(() {
    handler = buildHandler();
  });

  Future<Response> send(
    String method,
    String path, {
    Map<String, String>? headers,
  }) async {
    return handler(
      Request(method, Uri.parse('http://localhost$path'), headers: headers),
    );
  }

  group('GET /health', () {
    test('returns 200 with the documented JSON payload', () async {
      final response = await send('GET', '/health');

      expect(response.statusCode, 200);
      expect(
        response.headers['content-type'],
        'application/json; charset=utf-8',
      );

      final body =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect(body.keys.toSet(), <String>{
        'status',
        'service',
        'version',
        'time',
      });
      expect(body['status'], 'ok');
      expect(body['service'], 'arij-server');
      expect(body['version'], '0.1.0');

      final time = DateTime.parse(body['time'] as String);
      expect(time.isUtc, isTrue);
      expect(
        DateTime.now().toUtc().difference(time).inSeconds.abs(),
        lessThanOrEqualTo(5),
      );
    });
  });

  group('routing errors', () {
    test('returns a JSON 404 for an unknown path', () async {
      final response = await send('GET', '/does-not-exist');

      expect(response.statusCode, 404);
      expect(
        response.headers['content-type'],
        'application/json; charset=utf-8',
      );

      final error = _errorBody(await response.readAsString());
      expect(error['code'], 'not_found');
      expect(error['message'], isNotEmpty);
      expect(error['details'], <String, Object?>{'path': '/does-not-exist'});
    });

    test('returns a JSON 405 for a wrong method', () async {
      final response = await send('POST', '/health');

      expect(response.statusCode, 405);
      expect(response.headers['allow'], 'GET');
      expect(
        response.headers['content-type'],
        'application/json; charset=utf-8',
      );

      final error = _errorBody(await response.readAsString());
      expect(error['code'], 'method_not_allowed');
    });
  });

  group('CORS', () {
    test('answers an OPTIONS preflight with 204 and CORS headers', () async {
      final response = await send(
        'OPTIONS',
        '/health',
        headers: <String, String>{
          'origin': 'http://localhost:3000',
          'access-control-request-method': 'GET',
        },
      );

      expect(response.statusCode, 204);
      expect(response.headers['access-control-allow-origin'], '*');

      final methods = response.headers['access-control-allow-methods'] ?? '';
      expect(methods, contains('GET'));
      expect(methods, contains('POST'));
      expect(methods, contains('PATCH'));
      expect(methods, contains('DELETE'));
      expect(methods, contains('OPTIONS'));

      final allowedHeaders =
          response.headers['access-control-allow-headers'] ?? '';
      expect(allowedHeaders, contains('Authorization'));
      expect(allowedHeaders, contains('Content-Type'));

      expect(await response.readAsString(), isEmpty);
    });

    test('adds CORS headers to regular responses', () async {
      final response = await send('GET', '/health');

      expect(response.headers['access-control-allow-origin'], '*');
    });
  });

  group('request id', () {
    test('echoes a valid client request id', () async {
      final response = await send(
        'GET',
        '/health',
        headers: <String, String>{'x-request-id': 'test-request-1'},
      );

      expect(response.headers['x-request-id'], 'test-request-1');
    });

    test('generates a request id when none is provided', () async {
      final response = await send('GET', '/health');

      expect(response.headers['x-request-id'], isNotEmpty);
    });
  });
}

Map<String, dynamic> _errorBody(String body) {
  final decoded = jsonDecode(body) as Map<String, dynamic>;
  return decoded['error'] as Map<String, dynamic>;
}
