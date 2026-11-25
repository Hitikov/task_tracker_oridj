import '../models/status.dart';
import '../models/task.dart';
import '../models/task_type.dart';
import '../repositories/task_repository.dart';
import 'project_service.dart'
    show ForbiddenException, NotFoundException, ValidationException;

/// Business rules of the tasks stream (OpenAPI `Task`, `TaskType`, `Status`).
///
/// The service validates input, checks project membership, enforces the
/// `epic`/`task`/`subtask` hierarchy and translates storage outcomes into
/// domain exceptions; SQL lives in the repository and the HTTP envelope in
/// routes. Access: only the owner or a member of the project may see or
/// change its tasks.
class TaskService {
  TaskService({required this.repository});

  /// Repository to `tasks`, `task_types`, `statuses` and project access.
  final TaskRepository repository;

  // Must match the CHECK constraints of `tasks` and `docs/api/openapi.yaml`.
  static const int _maxTitleLength = 200;
  static const int _maxDescriptionLength = 5000;

  /// A date in the past is not a valid deadline.
  DateTime get _now => DateTime.now().toUtc();

  // --- Reads ---

  /// Tasks of the project for an owner or member
  /// (`GET /projects/{id}/tasks`). Query filters: `status`, `assignee`,
  /// `priority`, `kind`.
  Future<List<Task>> listTasks({
    required String userId,
    required String projectId,
    String? status,
    String? assignee,
    String? priority,
    String? kind,
  }) async {
    await _ensureAccess(userId, projectId);
    return repository.findTasks(
      projectId: projectId,
      status: status,
      assignee: assignee,
      priority: priority,
      kind: kind,
    );
  }

  /// Task by id for an owner or member of its project (`GET /tasks/{id}`).
  Future<Task> getTask({required String userId, required String taskId}) async {
    final task = await repository.findTaskById(taskId);
    if (task == null) {
      throw _taskNotFound(taskId);
    }
    await _ensureAccess(userId, task.projectId);
    return task;
  }

  /// Task types of the project (`GET /projects/{id}/task-types`).
  Future<List<TaskType>> listTaskTypes({
    required String userId,
    required String projectId,
  }) async {
    await _ensureAccess(userId, projectId);
    return repository.listTaskTypes(projectId);
  }

  /// Statuses of the project (`GET /projects/{id}/statuses`).
  Future<List<Status>> listStatuses({
    required String userId,
    required String projectId,
  }) async {
    await _ensureAccess(userId, projectId);
    return repository.listStatuses(projectId);
  }

  // --- Writes ---

  /// Creates a task and assigns the next unique number within the project
  /// (`POST /projects/{id}/tasks`). The reporter is the caller.
  ///
  /// Hierarchy rules:
  /// - `epic` — without a parent;
  /// - `task` — without a parent or inside an `epic`;
  /// - `subtask` — only inside a `task`.
  ///
  /// `typeId` defaults to the project's `feature` type and `statusId` to its
  /// default column. `title` is required, `kind` and `priority` must be valid
  /// enum values, `dueDate` may not be in the past. The assignee must be a
  /// member of the project.
  Future<Task> createTask({
    required String userId,
    required String projectId,
    required String title,
    required String kind,
    String? typeId,
    String statusId = '',
    String? priority,
    String? description,
    String? assigneeId,
    String? parentId,
    DateTime? dueDate,
  }) async {
    await _ensureAccess(userId, projectId);
    final effectiveStatusId = statusId.isNotEmpty
        ? statusId
        : await _defaultStatusId(projectId);
    final effectiveTypeId = typeId != null && typeId.isNotEmpty
        ? typeId
        : await _defaultTypeId(projectId);
    final effectivePriority = priority ?? 'medium';
    _validateCreateInput(
      title: title,
      kind: kind,
      typeId: effectiveTypeId,
      statusId: effectiveStatusId,
      priority: effectivePriority,
      description: description,
      dueDate: dueDate,
    );
    if (await repository.findTaskType(projectId, effectiveTypeId) == null) {
      throw const ValidationException('typeId');
    }
    if (await repository.findStatus(projectId, effectiveStatusId) == null) {
      throw const ValidationException('statusId');
    }
    if (assigneeId != null &&
        await repository.findProjectRole(projectId, assigneeId) == null) {
      throw const ValidationException('assigneeId');
    }
    await _validateHierarchy(projectId, kind, parentId);

    return repository.createTask(
      projectId: projectId,
      kind: kind,
      typeId: effectiveTypeId,
      statusId: effectiveStatusId,
      title: title.trim(),
      description: description?.trim(),
      priority: effectivePriority,
      assigneeId: assigneeId,
      reporterId: userId,
      parentId: parentId,
      dueDate: dueDate,
    );
  }

  /// Partially updates a task (`PATCH /tasks/{id}`); owner or member only.
  ///
  /// Accepts any of `title`, `description`, `kind`, `typeId`, `statusId`,
  /// `priority`, `assigneeId`, `parentId`, `dueDate`. Changing `kind` or
  /// `parentId` re-validates the hierarchy.
  Future<Task> updateTask({
    required String userId,
    required String taskId,
    required Map<String, Object?> fields,
  }) async {
    final task = await repository.findTaskById(taskId);
    if (task == null) {
      throw _taskNotFound(taskId);
    }
    await _ensureAccess(userId, task.projectId);

    final updates = <String, Object?>{};
    String? providedKind;
    String? providedParentId;
    DateTime? providedDueDate;
    bool kindProvided = false;
    bool parentIdProvided = false;

    for (final entry in fields.entries) {
      switch (entry.key) {
        case 'title':
          final value = entry.value;
          if (value is! String) {
            throw const ValidationException('title');
          }
          final name = value.trim();
          if (name.isEmpty || name.runes.length > _maxTitleLength) {
            throw const ValidationException('title');
          }
          updates['title'] = name;
        case 'description':
          final value = entry.value;
          if (value != null && value is! String) {
            throw const ValidationException('description');
          }
          if (value is String &&
              value.trim().runes.length > _maxDescriptionLength) {
            throw const ValidationException('description');
          }
          updates['description'] = value;
        case 'kind':
          final value = entry.value;
          if (value is! String || !taskKinds.contains(value)) {
            throw const ValidationException('kind');
          }
          providedKind = value;
          updates['kind'] = value;
          kindProvided = true;
        case 'priority':
          final value = entry.value;
          if (value is! String || !taskPriorities.contains(value)) {
            throw const ValidationException('priority');
          }
          updates['priority'] = value;
        case 'typeId':
          final value = entry.value;
          if (value is! String || value.isEmpty) {
            throw const ValidationException('typeId');
          }
          if (await repository.findTaskType(task.projectId, value) == null) {
            throw const ValidationException('typeId');
          }
          updates['typeId'] = value;
        case 'statusId':
          final value = entry.value;
          if (value is! String || value.isEmpty) {
            throw const ValidationException('statusId');
          }
          if (await repository.findStatus(task.projectId, value) == null) {
            throw const ValidationException('statusId');
          }
          updates['statusId'] = value;
        case 'assigneeId':
          final value = entry.value;
          if (value != null && value is! String) {
            throw const ValidationException('assigneeId');
          }
          if (value is String &&
              await repository.findProjectRole(task.projectId, value) == null) {
            throw const ValidationException('assigneeId');
          }
          updates['assigneeId'] = value;
        case 'parentId':
          final value = entry.value;
          if (value != null && value is! String) {
            throw const ValidationException('parentId');
          }
          providedParentId = value as String?;
          updates['parentId'] = value;
          parentIdProvided = true;
        case 'dueDate':
          final value = entry.value;
          if (value != null && value is! DateTime) {
            throw const ValidationException('dueDate');
          }
          providedDueDate = value as DateTime?;
          updates['dueDate'] = value;
        default:
          throw ValidationException(entry.key);
      }
    }
    if (updates.isEmpty) {
      throw const ValidationException(null);
    }

    final kind = kindProvided ? providedKind! : task.kind;
    final parentId = parentIdProvided ? providedParentId : task.parentId;
    if (kindProvided || parentIdProvided) {
      await _validateHierarchy(task.projectId, kind, parentId);
    }
    if (kindProvided && kind != task.kind) {
      final children = await repository.findChildTasks(taskId);
      final allowedChildKind = switch (kind) {
        'epic' => 'task',
        'task' => 'subtask',
        _ => null,
      };
      if (children.isNotEmpty &&
          (allowedChildKind == null ||
              children.any((child) => child.kind != allowedChildKind))) {
        throw const ValidationException('kind');
      }
    }
    if (providedDueDate != null && providedDueDate.isBefore(_now)) {
      throw const ValidationException('dueDate');
    }

    final updated = await repository.updateTask(taskId, updates);
    if (updated == null) {
      throw _taskNotFound(taskId);
    }
    return updated;
  }

  /// Deletes a task (`DELETE /tasks/{id}`); owner or member only.
  Future<void> deleteTask({
    required String userId,
    required String taskId,
  }) async {
    final task = await repository.findTaskById(taskId);
    if (task == null) {
      throw _taskNotFound(taskId);
    }
    await _ensureAccess(userId, task.projectId);
    final deleted = await repository.deleteTask(taskId);
    if (!deleted) {
      throw _taskNotFound(taskId);
    }
  }

  // --- Helpers ---

  /// Requires [projectId] to exist and [userId] to be its owner or member.
  Future<void> _ensureAccess(String userId, String projectId) async {
    final project = await repository.findProject(projectId);
    if (project == null) {
      throw NotFoundException(
        'project_not_found',
        'Проект не найден',
        details: <String, Object?>{'resource': 'project', 'id': projectId},
      );
    }
    final role = await repository.findProjectRole(projectId, userId);
    if (role == null) {
      throw const ForbiddenException();
    }
  }

  /// Returns the project's default status id, or its first status.
  ///
  /// `TaskCreate.statusId` is optional in OpenAPI: new tasks start in the
  /// project's default column (`is_default`).
  Future<String> _defaultStatusId(String projectId) async {
    final statuses = await repository.listStatuses(projectId);
    Status? first;
    for (final status in statuses) {
      if (status.isDefault) return status.id;
      first ??= status;
    }
    if (first != null) return first.id;
    throw const ValidationException('statusId');
  }

  /// Returns the project's `feature` type, or its first type, so a request
  /// without `typeId` stays valid against OpenAPI.
  Future<String> _defaultTypeId(String projectId) async {
    final types = await repository.listTaskTypes(projectId);
    for (final type in types) {
      if (type.name == 'feature') return type.id;
    }
    if (types.isNotEmpty) return types.first.id;
    throw const ValidationException('typeId');
  }

  void _validateCreateInput({
    required String title,
    required String kind,
    required String typeId,
    required String statusId,
    required String priority,
    String? description,
    DateTime? dueDate,
  }) {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty ||
        normalizedTitle.runes.length > _maxTitleLength) {
      throw const ValidationException('title');
    }
    if (description != null &&
        description.trim().runes.length > _maxDescriptionLength) {
      throw const ValidationException('description');
    }
    if (!taskKinds.contains(kind)) {
      throw const ValidationException('kind');
    }
    if (!taskPriorities.contains(priority)) {
      throw const ValidationException('priority');
    }
    if (typeId.isEmpty) {
      throw const ValidationException('typeId');
    }
    if (statusId.isEmpty) {
      throw const ValidationException('statusId');
    }
    if (dueDate != null && dueDate.isBefore(_now)) {
      throw const ValidationException('dueDate');
    }
  }

  /// Enforces the epic/task/subtask hierarchy:
  /// - `epic` — no parent;
  /// - `task` — no parent or parent is an `epic` of the same project;
  /// - `subtask` — parent is a `task` of the same project.
  Future<void> _validateHierarchy(
    String projectId,
    String kind,
    String? parentId,
  ) async {
    if (kind == 'epic') {
      if (parentId != null) {
        throw const ValidationException('parentId');
      }
      return;
    }
    if (kind == 'task' && parentId == null) {
      return;
    }
    if (kind == 'subtask' && parentId == null) {
      throw const ValidationException('parentId');
    }
    final parent = await repository.findTaskById(parentId!);
    if (parent == null) {
      throw NotFoundException(
        'task_not_found',
        'Родительская задача не найдена',
        details: <String, Object?>{'resource': 'task', 'id': parentId},
      );
    }
    if (parent.projectId != projectId) {
      throw const ValidationException('parentId');
    }
    if (kind == 'task') {
      if (parent.kind != 'epic') {
        throw const ValidationException('parentId');
      }
    } else {
      // subtask
      if (parent.kind != 'task') {
        throw const ValidationException('parentId');
      }
    }
  }

  NotFoundException _taskNotFound(String taskId) => NotFoundException(
    'task_not_found',
    'Задача не найдена',
    details: <String, Object?>{'resource': 'task', 'id': taskId},
  );
}
