import '../models/status.dart';
import '../models/task.dart';
import '../models/task_status_change.dart';
import '../repositories/board_repository.dart';
import 'project_service.dart'
    show ForbiddenException, NotFoundException, ValidationException;

/// One Kanban column: a project status together with the tasks in it.
///
/// OpenAPI `BoardColumn`. Columns always follow the status `position` order,
/// including columns with no tasks, so drag & drop targets stay stable.
class BoardColumn {
  const BoardColumn({required this.status, required this.tasks});

  /// Status of the column, with its `position` on the board.
  final Status status;

  /// Tasks currently in [status], ordered by their project number.
  final List<Task> tasks;

  Map<String, Object?> toJson() => <String, Object?>{
    'status': status.toJson(),
    'tasks': tasks.map((task) => task.toJson()).toList(),
  };
}

/// Business rules of the Kanban stream (stage 3).
///
/// Only an owner or a member of a project may read its board or move its
/// tasks. A status must belong to the task's project; a foreign status is a
/// validation error (HTTP 400), as in the stage-2 task endpoints. SQL lives
/// in [BoardRepository], the HTTP envelope in `BoardRoutes`.
class BoardService {
  BoardService({required this.repository});

  final BoardRepository repository;

  /// Changes the status of a task (`PATCH /tasks/{id}/status`).
  ///
  /// Unknown task → `task_not_found` (404), missing project →
  /// `project_not_found` (404), non-member → `forbidden` (403), empty or
  /// foreign `statusId` → `validation_error` (400). Returns the updated task.
  /// Moving a task into its current status is allowed and is a no-op for the
  /// task itself; like every successful call it is recorded in the history
  /// with equal `fromStatusId` and `toStatusId`.
  Future<Task> changeStatus({
    required String userId,
    required String taskId,
    required String statusId,
  }) async {
    if (statusId.trim().isEmpty) {
      throw const ValidationException('statusId');
    }
    final task = await repository.findTaskById(taskId);
    if (task == null) {
      throw _taskNotFound(taskId);
    }
    await _ensureAccess(userId, task.projectId);

    // Look up by (project, id): a status of another project must not pass.
    final status = await repository.findStatus(task.projectId, statusId);
    if (status == null) {
      throw const ValidationException('statusId');
    }
    final updated = await repository.updateTaskStatus(taskId, status.id);
    if (updated == null) {
      throw _taskNotFound(taskId);
    }
    await repository.recordStatusChange(
      taskId: taskId,
      projectId: task.projectId,
      fromStatusId: task.statusId,
      toStatusId: status.id,
      changedBy: userId,
    );
    return updated;
  }

  /// Status-change history of a task (`GET /tasks/{id}/history`).
  ///
  /// Unknown task → `task_not_found` (404), missing project →
  /// `project_not_found` (404), non-member → `forbidden` (403). Returns the
  /// recorded transitions in chronological order.
  Future<List<TaskStatusChange>> getStatusHistory({
    required String userId,
    required String taskId,
  }) async {
    final task = await repository.findTaskById(taskId);
    if (task == null) {
      throw _taskNotFound(taskId);
    }
    await _ensureAccess(userId, task.projectId);
    return repository.findStatusHistory(taskId);
  }

  /// Board data for a project (`GET /projects/{id}/board`).
  ///
  /// Returns statuses ordered by `position` with their tasks grouped by
  /// `statusId`. Optional [assignee] and [priority] filters are applied to
  /// the tasks before grouping; empty columns are still returned.
  Future<List<BoardColumn>> getBoard({
    required String userId,
    required String projectId,
    String? assignee,
    String? priority,
  }) async {
    await _ensureAccess(userId, projectId);
    final statuses = await repository.listStatuses(projectId);
    final tasks = await repository.findTasks(
      projectId: projectId,
      assignee: assignee,
      priority: priority,
    );

    final grouped = <String, List<Task>>{
      for (final status in statuses) status.id: <Task>[],
    };
    for (final task in tasks) {
      // A task's status always exists in the same project (DB FK); grouping
      // defensively is cheap and keeps the response shape total.
      grouped.putIfAbsent(task.statusId, () => <Task>[]).add(task);
    }
    return <BoardColumn>[
      for (final status in statuses)
        BoardColumn(
          status: status,
          tasks: List<Task>.unmodifiable(grouped[status.id] ?? const <Task>[]),
        ),
    ];
  }

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

  NotFoundException _taskNotFound(String taskId) => NotFoundException(
    'task_not_found',
    'Задача не найдена',
    details: <String, Object?>{'resource': 'task', 'id': taskId},
  );
}
