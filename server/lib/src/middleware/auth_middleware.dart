import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:shelf/shelf.dart';

import '../http/json_response.dart';
import '../models/user.dart';
import '../repositories/user_repository.dart';

/// Request context key under which [authenticateRequest] / [authMiddleware]
/// store the authenticated user.
const String authenticatedUserContextKey = 'arij.authenticatedUser';

/// Authenticates [request] via the `Authorization: Bearer <JWT>` header.
///
/// Verifies the token signature and expiry, then loads the user through
/// [repository] and returns it. Returns `null` when the header is missing,
/// malformed, expired or signed with another secret, or when the user no
/// longer exists — the caller decides how to respond (typically
/// `401 unauthorized`).
Future<User?> authenticateRequest(
  Request request, {
  required String jwtSecret,
  required UserRepository repository,
}) async {
  final userId = _verifyBearerToken(
    request.headers['authorization'],
    jwtSecret,
  );
  if (userId == null) {
    return null;
  }
  return repository.findById(userId);
}

/// Returns the [User] stored in the request context by [authenticateRequest]
/// or [authMiddleware], or `null`.
User? authenticatedUser(Request request) {
  return request.context[authenticatedUserContextKey] as User?;
}

/// [Middleware] that rejects unauthenticated requests with
/// `401 unauthorized` and otherwise calls [inner] with the user stored in
/// the request context (see [authenticatedUser]).
///
/// Intended for routes that require an authenticated user (the projects
/// stream, stage 2).
Middleware authMiddleware({
  required String jwtSecret,
  required UserRepository repository,
}) {
  return (Handler inner) {
    return (Request request) async {
      final user = await authenticateRequest(
        request,
        jwtSecret: jwtSecret,
        repository: repository,
      );
      if (user == null) {
        return errorResponse(401, 'unauthorized', 'Требуется аутентификация');
      }
      return inner(
        request.change(
          context: <String, Object>{authenticatedUserContextKey: user},
        ),
      );
    };
  };
}

/// Verifies the `Authorization: Bearer <JWT>` header of [authorization]
/// and returns the `sub` claim (user id).
String? _verifyBearerToken(String? authorization, String jwtSecret) {
  if (authorization == null) {
    return null;
  }
  final separator = authorization.indexOf(' ');
  if (separator <= 0 ||
      authorization.substring(0, separator).toLowerCase() != 'bearer') {
    return null;
  }
  final token = authorization.substring(separator + 1).trim();
  if (token.isEmpty) {
    return null;
  }
  try {
    return JWT.verify(token, SecretKey(jwtSecret)).subject;
  } on JWTException {
    // Missing/malformed/bad signature — no token to expose.
    return null;
  }
}
