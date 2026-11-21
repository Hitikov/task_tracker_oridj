import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../http/json_response.dart';
import '../middleware/auth_middleware.dart';
import '../repositories/project_repository.dart';
import '../services/project_service.dart';

/// HTTP handlers of the projects stream (`/api/v1/projects*`).
///
/// Binds a [ProjectService]: parses the request shape, calls the service and
/// maps its domain exceptions to the shared error envelope. Business rules
/// live in the service; SQL lives in the repository.
///
/// Handlers read the authenticated user via [authenticatedUser] (the context
/// populated by [authMiddleware] — the app pipeline mounts it around these
/// routes) and path parameters via [Request.params] (shelf_router's
/// `<name>` syntax, e.g. `router.get('/api/v1/projects/<id>', ...)`).
class ProjectRoutes {
  const ProjectRoutes(this.service);

  final ProjectService service;

  /// `GET /api/v1/projects` — `200` array of projects the user is a member
  /// of (owner or member).
  Future<Response> list(Request request) async {
    final user = authenticatedUser(request);
    if (user == null) {
      return _unauthorized();
    }
    final projects = await service.listProjects(user.id);
    return jsonResponse(projects.map((p) => p.toJson()).toList());
  }

  /// `POST /api/v1/projects` — `201` created project;
  /// `409 project_key_taken` on duplicate key.
  Future<Response> create(Request request) async {
    final user = authenticatedUser(request);
    if (user == null) {
      return _unauthorized();
    }
    try {
      final body = await _readBody(request);
      final project = await service.createProject(
        userId: user.id,
        key: _requiredString(body, 'key'),
        name: _requiredString(body, 'name'),
        description: _optionalString(body, 'description'),
      );
      return jsonResponse(project.toJson(), statusCode: 201);
    } on Object catch (error) {
      return _errorResponse(error);
    }
  }

  /// `GET /api/v1/projects/{id}` — `200` project; accessible to the owner
  /// and to members; `403 forbidden` otherwise.
  Future<Response> getById(Request request) async {
    final user = authenticatedUser(request);
    if (user == null) {
      return _unauthorized();
    }
    final projectId = _pathParam(request, 'id');
    if (projectId == null) {
      return _invalidPath();
    }
    try {
      final project = await service.getProject(
        userId: user.id,
        projectId: projectId,
      );
      return jsonResponse(project.toJson());
    } on Object catch (error) {
      return _errorResponse(error);
    }
  }

  /// `PATCH /api/v1/projects/{id}` — `200` updated project; owner only.
  Future<Response> update(Request request) async {
    final user = authenticatedUser(request);
    if (user == null) {
      return _unauthorized();
    }
    final projectId = _pathParam(request, 'id');
    if (projectId == null) {
      return _invalidPath();
    }
    try {
      final body = await _readBody(request);
      final project = await service.updateProject(
        userId: user.id,
        projectId: projectId,
        fields: body,
      );
      return jsonResponse(project.toJson());
    } on Object catch (error) {
      return _errorResponse(error);
    }
  }

  /// `DELETE /api/v1/projects/{id}` — `204`; owner only.
  Future<Response> delete(Request request) async {
    final user = authenticatedUser(request);
    if (user == null) {
      return _unauthorized();
    }
    final projectId = _pathParam(request, 'id');
    if (projectId == null) {
      return _invalidPath();
    }
    try {
      await service.deleteProject(userId: user.id, projectId: projectId);
      return Response(204);
    } on Object catch (error) {
      return _errorResponse(error);
    }
  }

  /// `GET /api/v1/projects/{id}/members` — `200` array of members;
  /// accessible to the owner and to members.
  Future<Response> listMembers(Request request) async {
    final user = authenticatedUser(request);
    if (user == null) {
      return _unauthorized();
    }
    final projectId = _pathParam(request, 'id');
    if (projectId == null) {
      return _invalidPath();
    }
    try {
      final members = await service.listMembers(
        userId: user.id,
        projectId: projectId,
      );
      return jsonResponse(members.map((m) => m.toJson()).toList());
    } on Object catch (error) {
      return _errorResponse(error);
    }
  }

  /// `POST /api/v1/projects/{id}/members` — `201` new member; owner only.
  Future<Response> addMember(Request request) async {
    final user = authenticatedUser(request);
    if (user == null) {
      return _unauthorized();
    }
    final projectId = _pathParam(request, 'id');
    if (projectId == null) {
      return _invalidPath();
    }
    try {
      final body = await _readBody(request);
      final member = await service.addMember(
        userId: user.id,
        projectId: projectId,
        email: _requiredString(body, 'email'),
        role: _optionalString(body, 'role'),
      );
      return jsonResponse(member.toJson(), statusCode: 201);
    } on Object catch (error) {
      return _errorResponse(error);
    }
  }

  /// `DELETE /api/v1/projects/{id}/members/{userId}` — `204`; owner only.
  Future<Response> removeMember(Request request) async {
    final user = authenticatedUser(request);
    if (user == null) {
      return _unauthorized();
    }
    final projectId = _pathParam(request, 'id');
    final userId = _pathParam(request, 'userId');
    if (projectId == null || userId == null) {
      return _invalidPath();
    }
    try {
      await service.removeMember(
        userId: user.id,
        projectId: projectId,
        userIdToRemove: userId,
      );
      return Response(204);
    } on Object catch (error) {
      return _errorResponse(error);
    }
  }

  // --- Shared helpers ---

  /// Maps [ProjectService] and [ProjectRepository] domain exceptions to the
  /// shared error envelope; rethrows anything else (the global error
  /// middleware turns it into `500 internal_error`).
  Response _errorResponse(Object error) {
    if (error is ValidationException) {
      return errorResponse(
        400,
        'validation_error',
        'Некорректные данные запроса',
        details: error.field == null
            ? null
            : <String, Object?>{'field': error.field},
      );
    }
    if (error is ForbiddenException) {
      return errorResponse(
        403,
        'forbidden',
        'Недостаточно прав для выполнения операции',
        details: const <String, Object?>{'requiredRole': 'owner'},
      );
    }
    if (error is NotFoundException) {
      return errorResponse(
        404,
        error.code,
        error.message,
        details: error.details,
      );
    }
    if (error is ProjectKeyTakenException) {
      return errorResponse(
        409,
        'project_key_taken',
        'Проект с таким ключом уже существует',
        details: const <String, Object?>{'field': 'key'},
      );
    }
    if (error is MemberExistsException) {
      return errorResponse(
        409,
        'member_exists',
        'Пользователь уже участвует в проекте',
        details: <String, Object?>{'userId': error.userId},
      );
    }
    if (error is OwnerRemovalException) {
      return errorResponse(
        409,
        'owner_removal_forbidden',
        'Нельзя удалить владельца проекта',
        details: <String, Object?>{'userId': error.userId},
      );
    }
    throw error;
  }

  Response _unauthorized() =>
      errorResponse(401, 'unauthorized', 'Требуется аутентификация');

  Response _invalidPath() => errorResponse(
    400,
    'validation_error',
    'Некорректные данные запроса',
    details: const <String, Object?>{'field': 'id'},
  );

  Future<Map<String, Object?>> _readBody(Request request) async {
    Object? decoded;
    try {
      decoded = jsonDecode(await request.readAsString());
    } on FormatException {
      decoded = null;
    }
    if (decoded is! Map<String, dynamic>) {
      throw const ValidationException(null);
    }
    return Map<String, Object?>.from(decoded);
  }

  String _requiredString(Map<String, Object?> body, String field) {
    final value = body[field];
    if (value is! String || value.trim().isEmpty) {
      throw ValidationException(field);
    }
    return value;
  }

  String? _optionalString(Map<String, Object?> body, String field) {
    final value = body[field];
    if (value == null) {
      return null;
    }
    if (value is! String) {
      throw ValidationException(field);
    }
    return value;
  }

  String? _pathParam(Request request, String name) => request.params[name];
}
