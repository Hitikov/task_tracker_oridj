import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../http/json_response.dart';
import '../middleware/auth_middleware.dart';
import '../repositories/user_repository.dart';
import '../services/auth_service.dart';

/// HTTP handlers of the `/api/v1/auth/*` routes.
///
/// Binds an [AuthService]: parses the request shape, calls the service and
/// maps its domain exceptions to the shared error envelope. Business rules
/// live in the service; SQL lives in the repository.
class AuthRoutes {
  const AuthRoutes(this.service);

  final AuthService service;

  /// `POST /api/v1/auth/register` — `201` with `{token, tokenType,
  /// expiresIn, user}`; `409 email_taken` on duplicate email;
  /// `400 validation_error` on invalid input.
  Future<Response> register(Request request) async {
    try {
      final body = await _readBody(request);
      final auth = await service.register(
        email: _requiredString(body, 'email'),
        password: _requiredString(body, 'password'),
        name: _requiredString(body, 'name'),
      );
      return jsonResponse(auth.toJson(), statusCode: 201);
    } on ValidationException catch (error) {
      return _validationError(error);
    } on EmailTakenException {
      return errorResponse(
        409,
        'email_taken',
        'Пользователь с таким email уже существует',
        details: const <String, Object?>{'field': 'email'},
      );
    }
  }

  /// `POST /api/v1/auth/login` — `200` with the same payload as
  /// [register]. Unknown email and wrong password both yield
  /// `401 invalid_credentials` (identical response); malformed input —
  /// `400 validation_error`.
  Future<Response> login(Request request) async {
    try {
      final body = await _readBody(request);
      final auth = await service.login(
        email: _requiredString(body, 'email'),
        password: _requiredString(body, 'password'),
      );
      return jsonResponse(auth.toJson());
    } on ValidationException catch (error) {
      return _validationError(error);
    } on InvalidCredentialsException {
      return errorResponse(
        401,
        'invalid_credentials',
        'Неверный email или пароль',
      );
    }
  }

  /// `GET /api/v1/auth/me` — `200 User` when `Authorization: Bearer <JWT>`
  /// is present and valid; `401 unauthorized` otherwise.
  Future<Response> me(Request request) async {
    final user = await authenticateRequest(
      request,
      jwtSecret: service.jwtSecret,
      repository: service.repository,
    );
    if (user == null) {
      return errorResponse(401, 'unauthorized', 'Требуется аутентификация');
    }
    return jsonResponse(user.toJson());
  }

  Response _validationError(ValidationException error) {
    final field = error.field;
    return errorResponse(
      400,
      'validation_error',
      'Некорректные данные запроса',
      details: field == null ? null : <String, Object?>{'field': field},
    );
  }

  Future<Map<String, dynamic>> _readBody(Request request) async {
    Object? decoded;
    try {
      decoded = jsonDecode(await request.readAsString());
    } on FormatException {
      decoded = null;
    }
    if (decoded is! Map<String, dynamic>) {
      throw ValidationException(null);
    }
    return decoded;
  }

  String _requiredString(Map<String, dynamic> body, String field) {
    final value = body[field];
    if (value is! String || value.trim().isEmpty) {
      throw ValidationException(field);
    }
    return value;
  }
}
