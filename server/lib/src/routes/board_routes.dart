import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../http/json_response.dart';
import '../middleware/auth_middleware.dart';
import '../services/board_service.dart';
import '../services/project_service.dart'
    show ForbiddenException, NotFoundException, ValidationException;

/// HTTP handlers of the Kanban stream (stage 3).
///
/// Routes (wired in `app.dart` by the stage owner):
/// - `PATCH /api/v1/tasks/<id>/status`
/// - `GET /api/v1/projects/<id>/board`
///
/// Path parameters are read via `request.params` (shelf_router stores them
/// under `shelf_router/params`); the authenticated user comes from
/// [authenticatedUser], populated by `authMiddleware`. Business rules live
/// in [BoardService]; errors use the shared JSON error envelope.
class BoardRoutes {
  const BoardRoutes(this.service);

  final BoardService service;

  /// `PATCH /api/v1/tasks/<id>/status` — `200` updated task.
  ///
  /// Body: `{ "statusId": "<uuid>" }`. `400 validation_error` for an empty
  /// or foreign-project status, `403 forbidden` for a non-member,
  /// `404 task_not_found` for an unknown id.
  Future<Response> changeStatus(Request request) async {
    final user = authenticatedUser(request);
    if (user == null) {
      return _unauthorized();
    }
    final taskId = _pathParam(request, 'id');
    if (taskId == null) {
      return _invalidPath();
    }
    try {
      final body = await _readBody(request);
      final task = await service.changeStatus(
        userId: user.id,
        taskId: taskId,
        statusId: _requiredString(body, 'statusId'),
      );
      return jsonResponse(task.toJson());
    } on Object catch (error) {
      return _errorResponse(error);
    }
  }

  /// `GET /api/v1/projects/<id>/board` — `200` array of board columns.
  ///
  /// Each item is `{ "status": Status, "tasks": Task[] }`, ordered by status
  /// position. Optional query filters: `assignee`, `priority`.
  Future<Response> getBoard(Request request) async {
    final user = authenticatedUser(request);
    if (user == null) {
      return _unauthorized();
    }
    final projectId = _pathParam(request, 'id');
    if (projectId == null) {
      return _invalidPath();
    }
    try {
      final columns = await service.getBoard(
        userId: user.id,
        projectId: projectId,
        assignee: request.url.queryParameters['assignee'],
        priority: request.url.queryParameters['priority'],
      );
      return jsonResponse(columns.map((column) => column.toJson()).toList());
    } on Object catch (error) {
      return _errorResponse(error);
    }
  }

  // --- Shared helpers ---

  /// Maps domain exceptions to the shared error envelope; rethrows anything
  /// unexpected so the global error middleware turns it into 500.
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
        details: const <String, Object?>{'requiredRole': 'member'},
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

  String? _pathParam(Request request, String name) => request.params[name];
}
