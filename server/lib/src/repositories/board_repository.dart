import 'package:postgres/postgres.dart';

import '../db/database.dart';
import '../models/project.dart';
import '../models/status.dart';
import '../models/task.dart';
import '../models/task_status_change.dart';
import 'task_repository.dart';

/// Data access required by the Kanban board (stage 3).
///
/// The interface deliberately stays at the level of whole tasks/statuses:
/// grouping tasks into columns is a business rule and lives in
/// `BoardService`, not in SQL. Project membership checks reuse the same
/// `project_members` rows as the task stream, so owner/member semantics do
/// not diverge between Backlog and Kanban.
///
/// Status-change history is stored by `0007_task_status_history.sql` and
/// exposed through [recordStatusChange]/[findStatusHistory]. The defaults
/// below keep lightweight in-memory implementations usable; the production
/// adapter overrides them with SQL.
abstract interface class BoardRepository {
  /// Task by id, or `null` when absent.
  Future<Task?> findTaskById(String taskId);

  /// Project by id, or `null` when absent.
  Future<Project?> findProject(String projectId);

  /// Role of [userId] in [projectId] (`owner`/`member`), or `null` when the
  /// user is not a member or the project does not exist.
  Future<String?> findProjectRole(String projectId, String userId);

  /// Status [statusId] of [projectId], or `null` when it belongs to another
  /// project or does not exist.
  Future<Status?> findStatus(String projectId, String statusId);

  /// Tasks of [projectId], optionally filtered by assignee/priority and
  /// ordered by their project number.
  Future<List<Task>> findTasks({
    required String projectId,
    String? assignee,
    String? priority,
  });

  /// Statuses of [projectId] ordered by `position` (board column order).
  Future<List<Status>> listStatuses(String projectId);

  /// Updates only `status_id` (and `updated_at`) of [taskId], returning the
  /// fresh task or `null` when no row matched.
  ///
  /// The project-scoped status check is a service rule; this method relies
  /// on the FK constraints of `tasks` to reject cross-project references.
  Future<Task?> updateTaskStatus(String taskId, String statusId);

  /// Persists one successful status transition of a task.
  ///
  /// [fromStatusId] is the status before the update; it may equal
  /// [toStatusId] when a client re-applies the current status. [changedBy]
  /// is the authenticated user id. Implementations backed by a database
  /// must override this method.
  Future<void> recordStatusChange({
    required String taskId,
    required String projectId,
    required String fromStatusId,
    required String toStatusId,
    required String changedBy,
  }) async {}

  /// Changes of [taskId] in chronological order, or an empty list when the
  /// implementation does not keep history.
  Future<List<TaskStatusChange>> findStatusHistory(String taskId) async =>
      const <TaskStatusChange>[];
}

/// [BoardRepository] backed by an existing [TaskRepository].
///
/// Production wiring passes `PostgresTaskRepository` and the [Database] used
/// for the history table; tests pass an in-memory fake and omit [database].
/// This adapter keeps board-specific SQL out of the task repository while
/// reusing its validated `updateTask` path (whitelisted column,
/// `updated_at` bump and key reconstruction).
class TaskBackedBoardRepository implements BoardRepository {
  TaskBackedBoardRepository(this._tasks, [this._database]);

  final TaskRepository _tasks;
  final Database? _database;

  static const String _historyColumns =
      'id, task_id, from_status_id, to_status_id, changed_by, changed_at';

  @override
  Future<Task?> findTaskById(String taskId) => _tasks.findTaskById(taskId);

  @override
  Future<Project?> findProject(String projectId) =>
      _tasks.findProject(projectId);

  @override
  Future<String?> findProjectRole(String projectId, String userId) =>
      _tasks.findProjectRole(projectId, userId);

  @override
  Future<Status?> findStatus(String projectId, String statusId) =>
      _tasks.findStatus(projectId, statusId);

  @override
  Future<List<Task>> findTasks({
    required String projectId,
    String? assignee,
    String? priority,
  }) => _tasks.findTasks(
    projectId: projectId,
    assignee: assignee,
    priority: priority,
  );

  @override
  Future<List<Status>> listStatuses(String projectId) =>
      _tasks.listStatuses(projectId);

  @override
  Future<Task?> updateTaskStatus(String taskId, String statusId) =>
      _tasks.updateTask(taskId, <String, Object?>{'statusId': statusId});

  @override
  Future<void> recordStatusChange({
    required String taskId,
    required String projectId,
    required String fromStatusId,
    required String toStatusId,
    required String changedBy,
  }) async {
    await _requireDatabase().query(
      'INSERT INTO task_status_changes '
      '(task_id, project_id, from_status_id, to_status_id, changed_by, '
      'changed_at) VALUES (\$1, \$2, \$3, \$4, \$5, now())',
      parameters: <Object?>[
        taskId,
        projectId,
        fromStatusId,
        toStatusId,
        changedBy,
      ],
    );
  }

  @override
  Future<List<TaskStatusChange>> findStatusHistory(String taskId) async {
    final result = await _requireDatabase().query(
      'SELECT $_historyColumns FROM task_status_changes '
      'WHERE task_id = \$1 ORDER BY changed_at, id',
      parameters: <Object?>[taskId],
    );
    return <TaskStatusChange>[
      for (final row in result) TaskStatusChange.fromMap(_columnMap(row)),
    ];
  }

  Database _requireDatabase() {
    final database = _database;
    if (database == null) {
      throw StateError('Database is required for task status history');
    }
    return database;
  }

  /// UUID columns arrive as [UndecodedBytes] in text query mode.
  static Map<String, dynamic> _columnMap(ResultRow row) {
    return row.toColumnMap().map(
      (key, value) =>
          MapEntry(key, value is UndecodedBytes ? value.asString : value),
    );
  }
}
