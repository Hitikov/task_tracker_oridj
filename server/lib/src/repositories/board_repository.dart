import '../models/project.dart';
import '../models/status.dart';
import '../models/task.dart';
import 'task_repository.dart';

/// Data access required by the Kanban board (stage 3).
///
/// The interface deliberately stays at the level of whole tasks/statuses:
/// grouping tasks into columns is a business rule and lives in
/// `BoardService`, not in SQL. Project membership checks reuse the same
/// `project_members` rows as the task stream, so owner/member semantics do
/// not diverge between Backlog and Kanban.
///
/// TODO(stage-3): status-change history. Persisting transitions needs a new
/// migration (`0007_task_status_history.sql`) and a `findStatusHistory`
/// method here; migrations are outside this stream's scope, so the history
/// endpoint is intentionally not implemented yet.
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
}

/// [BoardRepository] backed by an existing [TaskRepository].
///
/// Production wiring can pass `PostgresTaskRepository` here; tests pass an
/// in-memory fake. This adapter keeps board-specific SQL out of the task
/// repository while reusing its validated `updateTask` path (whitelisted
/// column, `updated_at` bump and key reconstruction).
class TaskBackedBoardRepository implements BoardRepository {
  TaskBackedBoardRepository(this._tasks);

  final TaskRepository _tasks;

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
}
