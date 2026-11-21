import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../http/json_response.dart';
import '../middleware/auth_middleware.dart';
import '../repositories/task_repository.dart';
import '../services/project_service.dart'
    show ForbiddenException, NotFoundException, ValidationException;
import '../services/task_service.dart';

/// HTTP handlers of the tasks stream.
///
/// Routes:
/// - `GET/POST /api/v1/projects/<id>/tasks`
/// - `GET/PATCH/DELETE /api/v1/tasks/<id>`
/// - `GET /api/v1/projects/<id>/task-types`
/// - `GET /api/v1/projects/<id>/statuses`
///
/// Path parameters (`<id>`) are read via `request.params` (shelf_router
/// stores them under the `shelf_router/params` context key). The
/// authenticated user is read via [authenticatedUser], populated by
/// [authMiddleware] in the pipeline. Business rules live in
/// [TaskService]; SQL in [TaskRepository]; SQL details never leak into
/// responses — all errors use the shared JSON envelope.
class TaskRoutes {
  const TaskRoutes(this.service);

  final TaskService service;

  /// `GET /api/v1/projects/<id>/tasks` — `200` array of tasks; query
  /// parameters `status`, `assignee`, `priority`, `kind` filter the list.
  Future<Response> list(Request request) async {
    final user = authenticatedUser(request);
    if (user == null) {
      return _unauthorized();
    }
    final projectId = _pathParam(request, 'id');
    if (projectId == null) {
      return _invalidPath();
    }
    try {
      final tasks = await service.listTasks(
        userId: user.id,
        projectId: projectId,
        status: request.url.queryParameters['status'],
        assignee: request.url.queryParameters['assignee'],
        priority: request.url.queryParameters['priority'],
        kind: request.url.queryParameters['kind'],
      );
      return jsonResponse(tasks.map((task) => task.toJson()).toList());
    } on Object catch (error) {
      return _errorResponse(error);
    }
  }

  /// `POST /api/v1/projects/<id>/tasks` — `201` created task;
  /// `409 task_number_race` on a number-assignment race.
  Future<Response> create(Request request) async {
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
      final task = await service.createTask(
        userId: user.id,
        projectId: projectId,
        title: _requiredString(body, 'title'),
        kind: _requiredString(body, 'kind'),
        typeId: _requiredString(body, 'typeId'),
        statusId: _requiredString(body, 'statusId'),
        priority: _requiredString(body, 'priority'),
        description: _optionalString(body, 'description'),
        assigneeId: _optionalString(body, 'assigneeId'),
        parentId: _optionalString(body, 'parentId'),
        dueDate: _optionalDateTime(body, 'dueDate'),
      );
      return jsonResponse(task.toJson(), statusCode: 201);
    } on Object catch (error) {
      return _errorResponse(error);
    }
  }

  /// `GET /api/v1/tasks/<id>` — `200` task; `403 forbidden` without
  /// project access; `404 task_not_found` when unknown.
  Future<Response> getById(Request request) async {
    final user = authenticatedUser(request);
    if (user == null) {
      return _unauthorized();
    }
    final taskId = _pathParam(request, 'id');
    if (taskId == null) {
      return _invalidPath();
    }
    try {
      final task = await service.getTask(userId: user.id, taskId: taskId);
      return jsonResponse(task.toJson());
    } on Object catch (error) {
      return _errorResponse(error);
    }
  }

  /// `PATCH /api/v1/tasks/<id>` — `200` updated task; owner/member only.
  Future<Response> update(Request request) async {
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
      final fields = <String, Object?>{};
      for (final field in <String>[
        'title',
        'description',
        'kind',
        'typeId',
        'statusId',
        'priority',
        'assigneeId',
        'parentId',
        'dueDate',
      ]) {
        if (body.containsKey(field)) {
          fields[field] = field == 'dueDate'
              ? _optionalDateTime(body, field)
              : body[field];
        }
      }
      final task = await service.updateTask(
        userId: user.id,
        taskId: taskId,
        fields: fields,
      );
      return jsonResponse(task.toJson());
    } on Object catch (error) {
      return _errorResponse(error);
    }
  }

  /// `DELETE /api/v1/tasks/<id>` — `204`; owner/member only.
  Future<Response> delete(Request request) async {
    final user = authenticatedUser(request);
    if (user == null) {
      return _unauthorized();
    }
    final taskId = _pathParam(request, 'id');
    if (taskId == null) {
      return _invalidPath();
    }
    try {
      await service.deleteTask(userId: user.id, taskId: taskId);
      return Response(204);
    } on Object catch (error) {
      return _errorResponse(error);
    }
  }

  /// `GET /api/v1/projects/<id>/task-types` — `200` array of task types.
  Future<Response> listTypes(Request request) async {
    final user = authenticatedUser(request);
    if (user == null) {
      return _unauthorized();
    }
    final projectId = _pathParam(request, 'id');
    if (projectId == null) {
      return _invalidPath();
    }
    try {
      final types = await service.listTaskTypes(
        userId: user.id,
        projectId: projectId,
      );
      return jsonResponse(types.map((type) => type.toJson()).toList());
    } on Object catch (error) {
      return _errorResponse(error);
    }
  }

  /// `GET /api/v1/projects/<id>/statuses` — `200` array of statuses.
  Future<Response> listStatuses(Request request) async {
    final user = authenticatedUser(request);
    if (user == null) {
      return _unauthorized();
    }
    final projectId = _pathParam(request, 'id');
    if (projectId == null) {
      return _invalidPath();
    }
    try {
      final statuses = await service.listStatuses(
        userId: user.id,
        projectId: projectId,
      );
      return jsonResponse(statuses.map((s) => s.toJson()).toList());
    } on Object catch (error) {
      return _errorResponse(error);
    }
  }

  // --- Shared helpers ---

  /// Maps service/repository domain exceptions to the shared error
  /// envelope; rethrows anything unexpected (the global error middleware
  /// turns it into `500 internal_error`).
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
    if (error is TaskNumberRaceException) {
      return errorResponse(
        409,
        'task_number_race',
        'Не удалось присвоить задаче уникальный номер в проекте, '
            'попробуйте снова',
        details: <String, Object?>{'projectId': error.projectId},
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

  DateTime? _optionalDateTime(Map<String, Object?> body, String field) {
    final value = body[field];
    if (value == null) {
      return null;
    }
    if (value is! String || value.trim().isEmpty) {
      throw ValidationException(field);
    }
    try {
      return DateTime.parse(value.trim()).toUtc();
    } on FormatException {
      throw ValidationException(field);
    }
  }

  String? _pathParam(Request request, String name) => request.params[name];
}
