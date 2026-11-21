import 'dart:convert';

import 'package:arij_server/arij_server.dart';
import 'package:arij_server/src/middleware/auth_middleware.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'fake_user_repository.dart';

void main() {
  const jwtSecret = 'test-jwt-secret-0123456789abcdef';
  const validPassword = 'correct-horse-battery-staple';

  late Handler handler;
  late FakeUserRepository repository;

  setUp(() {
    repository = FakeUserRepository();
    handler = buildHandler(userRepository: repository, jwtSecret: jwtSecret);
  });

  Future<Response> send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) async {
    final allHeaders = <String, String>{...?headers};
    if (body != null) {
      allHeaders.putIfAbsent('content-type', () => 'application/json');
    }
    return handler(
      Request(
        method,
        Uri.parse('http://localhost$path'),
        headers: allHeaders,
        body: body == null ? null : (body is String ? body : jsonEncode(body)),
      ),
    );
  }

  Future<Map<String, dynamic>> json(Response response) async {
    return jsonDecode(await response.readAsString()) as Map<String, dynamic>;
  }

  Map<String, dynamic> errorOf(Map<String, dynamic> body) =>
      body['error'] as Map<String, dynamic>;

  group('POST /api/v1/auth/register', () {
    final valid = <String, String>{
      'email': 'ada@example.com',
      'password': validPassword,
      'name': 'Ада Лавлейс',
    };

    test('creates user and returns 201 with token + user', () async {
      final response = await send('POST', '/api/v1/auth/register', body: valid);
      expect(response.statusCode, 201);

      final body = await json(response);
      expect(body['tokenType'], 'Bearer');
      expect(body['expiresIn'], 86400);

      final user = body['user'] as Map<String, dynamic>;
      expect(user['email'], 'ada@example.com');
      expect(user['name'], 'Ада Лавлейс');
      expect(user['id'], isNotEmpty);
      expect(user['createdAt'], isA<String>());
      expect(user['updatedAt'], isA<String>());
      expect(user.keys.toSet(), <String>{
        'id',
        'email',
        'name',
        'createdAt',
        'updatedAt',
      });

      // The password hash must never leak into the API.
      expect(jsonEncode(body), isNot(contains('passwordHash')));
      expect(jsonEncode(body), isNot(contains('password_hash')));

      final token = JWT.verify(body['token'] as String, SecretKey(jwtSecret));
      expect(token.subject, user['id']);
    });

    test('duplicate email → 409 email_taken', () async {
      expect(
        (await send('POST', '/api/v1/auth/register', body: valid)).statusCode,
        201,
      );
      final second = await send('POST', '/api/v1/auth/register', body: valid);
      expect(second.statusCode, 409);
      final error = errorOf(await json(second));
      expect(error['code'], 'email_taken');
      expect(error['details'], <String, Object?>{'field': 'email'});
    });

    test('duplicate email ignoring case → 409 (citext)', () async {
      expect(
        (await send('POST', '/api/v1/auth/register', body: valid)).statusCode,
        201,
      );
      final second = await send(
        'POST',
        '/api/v1/auth/register',
        body: {...valid, 'email': 'ADA@EXAMPLE.COM'},
      );
      expect(second.statusCode, 409);
      expect(errorOf(await json(second))['code'], 'email_taken');
    });

    test('invalid email → 400 validation_error, details.field=email', () async {
      final response = await send(
        'POST',
        '/api/v1/auth/register',
        body: {'email': 'not-an-email', 'password': validPassword, 'name': 'A'},
      );
      expect(response.statusCode, 400);
      final error = errorOf(await json(response));
      expect(error['code'], 'validation_error');
      expect(error['details'], <String, Object?>{'field': 'email'});
    });

    test('password shorter than 8 → 400, details.field=password', () async {
      final response = await send(
        'POST',
        '/api/v1/auth/register',
        body: {'email': 'a@example.com', 'password': 'short7', 'name': 'A'},
      );
      expect(response.statusCode, 400);
      final error = errorOf(await json(response));
      expect(error['code'], 'validation_error');
      expect(error['details'], <String, Object?>{'field': 'password'});
    });

    test('password longer than 128 → 400', () async {
      final response = await send(
        'POST',
        '/api/v1/auth/register',
        body: {'email': 'a@example.com', 'password': 'a' * 129, 'name': 'A'},
      );
      expect(response.statusCode, 400);
      expect(errorOf(await json(response))['code'], 'validation_error');
    });

    test('name longer than 100 → 400, details.field=name', () async {
      final response = await send(
        'POST',
        '/api/v1/auth/register',
        body: {
          'email': 'a@example.com',
          'password': validPassword,
          'name': 'А' * 101,
        },
      );
      expect(response.statusCode, 400);
      expect(errorOf(await json(response))['details'], <String, Object?>{
        'field': 'name',
      });
    });

    test('blank name → 400', () async {
      final response = await send(
        'POST',
        '/api/v1/auth/register',
        body: {
          'email': 'a@example.com',
          'password': validPassword,
          'name': '   ',
        },
      );
      expect(response.statusCode, 400);
    });

    test('missing required field → 400 with details.field', () async {
      final response = await send(
        'POST',
        '/api/v1/auth/register',
        body: {'email': 'a@example.com', 'password': validPassword},
      );
      expect(response.statusCode, 400);
      final error = errorOf(await json(response));
      expect(error['code'], 'validation_error');
      expect(error['details'], <String, Object?>{'field': 'name'});
    });

    test('non-object body → 400', () async {
      final response = await send('POST', '/api/v1/auth/register', body: 42);
      expect(response.statusCode, 400);
    });

    test('malformed JSON → 400', () async {
      final response = await send(
        'POST',
        '/api/v1/auth/register',
        body: '{"email":',
      );
      expect(response.statusCode, 400);
    });
  });

  group('POST /api/v1/auth/login', () {
    setUp(() async {
      final response = await send(
        'POST',
        '/api/v1/auth/register',
        body: {
          'email': 'ada@example.com',
          'password': validPassword,
          'name': 'Ада Лавлейс',
        },
      );
      expect(response.statusCode, 201);
    });

    test('correct credentials → 200 with token', () async {
      final response = await send(
        'POST',
        '/api/v1/auth/login',
        body: {'email': 'ada@example.com', 'password': validPassword},
      );
      expect(response.statusCode, 200);

      final body = await json(response);
      expect(body['tokenType'], 'Bearer');
      final user = body['user'] as Map<String, dynamic>;
      expect(user['email'], 'ada@example.com');
      final token = JWT.verify(body['token'] as String, SecretKey(jwtSecret));
      expect(token.subject, user['id']);
    });

    test('wrong password → 401 invalid_credentials', () async {
      final response = await send(
        'POST',
        '/api/v1/auth/login',
        body: {'email': 'ada@example.com', 'password': 'not-the-password'},
      );
      expect(response.statusCode, 401);
      expect(errorOf(await json(response))['code'], 'invalid_credentials');
    });

    test('unknown email → 401 invalid_credentials', () async {
      final response = await send(
        'POST',
        '/api/v1/auth/login',
        body: {'email': 'nobody@example.com', 'password': validPassword},
      );
      expect(response.statusCode, 401);
      expect(errorOf(await json(response))['code'], 'invalid_credentials');
    });

    test('unknown email and wrong password → identical responses', () async {
      final unknown = await send(
        'POST',
        '/api/v1/auth/login',
        body: {'email': 'nobody@example.com', 'password': 'whatever-password'},
      );
      final wrong = await send(
        'POST',
        '/api/v1/auth/login',
        body: {'email': 'ada@example.com', 'password': 'whatever-password'},
      );
      expect(unknown.statusCode, wrong.statusCode);
      expect(await unknown.readAsString(), await wrong.readAsString());
    });

    test('case-insensitive email → 200', () async {
      final response = await send(
        'POST',
        '/api/v1/auth/login',
        body: {'email': 'ADA@EXAMPLE.COM', 'password': validPassword},
      );
      expect(response.statusCode, 200);
    });

    test('missing email/password → 400 validation_error', () async {
      final response = await send(
        'POST',
        '/api/v1/auth/login',
        body: {'password': validPassword},
      );
      expect(response.statusCode, 400);
      expect(errorOf(await json(response))['code'], 'validation_error');
    });

    test('malformed JSON → 400', () async {
      final response = await send(
        'POST',
        '/api/v1/auth/login',
        body: 'not json at all',
      );
      expect(response.statusCode, 400);
    });
  });

  group('GET /api/v1/auth/me', () {
    late String token;
    late String userId;

    /// Sends `GET /api/v1/auth/me` with `Authorization: Bearer <token>`.
    Future<Response> me(String token) async {
      return send(
        'GET',
        '/api/v1/auth/me',
        headers: <String, String>{'authorization': 'Bearer $token'},
      );
    }

    /// Sends `GET /api/v1/auth/me` without the `Authorization` header.
    Future<Response> meWithoutToken() async {
      return send('GET', '/api/v1/auth/me');
    }

    setUp(() async {
      final response = await send(
        'POST',
        '/api/v1/auth/register',
        body: {
          'email': 'ada@example.com',
          'password': validPassword,
          'name': 'Ада Лавлейс',
        },
      );
      expect(response.statusCode, 201);
      final body = await json(response);
      final user = body['user'] as Map<String, dynamic>;
      userId = user['id'] as String;
      token = body['token'] as String;
    });

    test('no token → 401 unauthorized', () async {
      final response = await meWithoutToken();
      expect(response.statusCode, 401);
      expect(errorOf(await json(response))['code'], 'unauthorized');
    });

    test('malformed token → 401 unauthorized', () async {
      final response = await me('not-a-jwt');
      expect(response.statusCode, 401);
    });

    test('wrong scheme → 401 unauthorized', () async {
      final response = await send(
        'GET',
        '/api/v1/auth/me',
        headers: {'authorization': 'Basic $token'},
      );
      expect(response.statusCode, 401);
    });

    test('token signed with another secret → 401 unauthorized', () async {
      final forged = JWT(
        <String, dynamic>{},
        subject: userId,
      ).sign(SecretKey('another-jwt-secret-0123456789abcdef'));
      final response = await me(forged);
      expect(response.statusCode, 401);
    });

    test('expired token → 401 unauthorized', () async {
      final expired = JWT(<String, dynamic>{}, subject: userId).sign(
        SecretKey(jwtSecret),
        algorithm: JWTAlgorithm.HS256,
        expiresIn: const Duration(seconds: -10),
      );
      final response = await me(expired);
      expect(response.statusCode, 401);
    });

    test('unknown user id in token → 401 unauthorized', () async {
      const unknownId = 'ffffffff-ffff-4fff-8fff-ffffffffffff';
      final minted = JWT(
        <String, dynamic>{},
        subject: unknownId,
      ).sign(SecretKey(jwtSecret));
      final response = await me(minted);
      expect(response.statusCode, 401);
    });

    test('valid token → 200 User without hash fields', () async {
      final response = await me(token);
      expect(response.statusCode, 200);

      final body = await json(response);
      expect(body['email'], 'ada@example.com');
      expect(body['name'], 'Ада Лавлейс');
      expect(body['id'], userId);
      expect(body['createdAt'], isA<String>());
      expect(body['updatedAt'], isA<String>());
      expect(body.keys.toSet(), <String>{
        'id',
        'email',
        'name',
        'createdAt',
        'updatedAt',
      });
      expect(jsonEncode(body), isNot(contains('passwordHash')));
    });
  });

  group('authenticateRequest', () {
    late String userId;
    late String token;

    Request request({Map<String, String>? headers}) => Request(
      'GET',
      Uri.parse('http://localhost/api/v1/auth/me'),
      headers: headers,
    );

    setUp(() async {
      final response = await send(
        'POST',
        '/api/v1/auth/register',
        body: {
          'email': 'ada@example.com',
          'password': validPassword,
          'name': 'Ада Лавлейс',
        },
      );
      expect(response.statusCode, 201);
      final body = await json(response);
      final user = body['user'] as Map<String, dynamic>;
      userId = user['id'] as String;
      token = body['token'] as String;
    });

    test('returns the user for a valid token', () async {
      final user = await authenticateRequest(
        request(headers: {'authorization': 'Bearer $token'}),
        jwtSecret: jwtSecret,
        repository: repository,
      );
      expect(user, isNotNull);
      expect(user!.id, userId);
      expect(user.email, 'ada@example.com');
    });

    test('returns null when the token is expired', () async {
      final expired = JWT(<String, dynamic>{}, subject: userId).sign(
        SecretKey(jwtSecret),
        algorithm: JWTAlgorithm.HS256,
        expiresIn: const Duration(seconds: -10),
      );
      final user = await authenticateRequest(
        request(headers: {'authorization': 'Bearer $expired'}),
        jwtSecret: jwtSecret,
        repository: repository,
      );
      expect(user, isNull);
    });

    test('returns null when the user is missing from the repository', () async {
      const unknownId = 'ffffffff-ffff-4fff-8fff-ffffffffffff';
      final minted = JWT(
        <String, dynamic>{},
        subject: unknownId,
      ).sign(SecretKey(jwtSecret));
      final user = await authenticateRequest(
        request(headers: {'authorization': 'Bearer $minted'}),
        jwtSecret: jwtSecret,
        repository: repository,
      );
      expect(user, isNull);
    });

    test('returns null when the header is missing', () async {
      final user = await authenticateRequest(
        request(),
        jwtSecret: jwtSecret,
        repository: repository,
      );
      expect(user, isNull);
    });
  });
}
