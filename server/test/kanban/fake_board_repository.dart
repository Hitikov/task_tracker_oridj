import 'package:arij_server/src/models/project.dart';
import 'package:arij_server/src/models/status.dart';
import 'package:arij_server/src/models/task.dart';
import 'package:arij_server/src/models/task_status_change.dart';
import 'package:arij_server/src/repositories/board_repository.dart';

/// In-memory [BoardRepository] for Kanban service and route tests.
///
/// Mirrors the storage rules that matter here: statuses are project-scoped,
/// project membership is the access rule, and `updateTaskStatus` bumps
/// `updated_at` without touching any other task field.
class FakeBoardRepository implements BoardRepository {
  final Map<String, Project> _projects = <String, Project>{};

  /// project_id → (user_id → role).
  final Map<String, Map<String, String>> _roles =
      <String, Map<String, String>>{};
  final Map<String, Status> _statuses = <String, Status>{};
  final Map<String, Task> _tasks = <String, Task>{};

  /// Registers [project] and records [ownerId] as its owner and [memberIds]
  /// as members.
  void seedProject({
    required String id,
    required String key,
    required String ownerId,
    Iterable<String> memberIds = const <String>[],
  }) {
    final now = DateTime.now().toUtc();
    _projects[id] = Project(
      id: id,
      key: key,
      name: key,
      description: null,
      ownerId: ownerId,
      createdAt: now,
      updatedAt: now,
    );
    _roles[id] = <String, String>{ownerId: 'owner'};
    for (final memberId in memberIds) {
      _roles[id]![memberId] = 'member';
    }
  }

  void seedStatus({
    required String id,
    required String projectId,
    required String name,
    required String key,
    required int position,
    required bool isDefault,
  }) {
    _statuses[id] = Status(
      id: id,
      projectId: projectId,
      name: name,
      key: key,
      position: position,
      isDefault: isDefault,
    );
  }

  /// Inserts a ready-made task (as-is, without validation).
  void seedTask(Task task) => _tasks[task.id] = task;

  /// Builds and inserts a task with sensible defaults; returns the task.
  Task addTask({
    required String id,
    required String projectId,
    required int number,
    required String statusId,
    String? assigneeId,
    String priority = 'medium',
    String kind = 'task',
    String title = 'Task',
    String typeId = 'type-default',
    String reporterId = 'reporter',
  }) {
    final now = DateTime.now().toUtc();
    final task = Task(
      id: id,
      projectId: projectId,
      number: number,
      key: '${_projects[projectId]?.key ?? 'TEST'}-$number',
      kind: kind,
      typeId: typeId,
      statusId: statusId,
      title: title,
      description: null,
      priority: priority,
      assigneeId: assigneeId,
      reporterId: reporterId,
      parentId: null,
      dueDate: null,
      createdAt: now,
      updatedAt: now,
    );
    seedTask(task);
    return task;
  }

  @override
  Future<Task?> findTaskById(String taskId) async => _tasks[taskId];

  @override
  Future<Project?> findProject(String projectId) async => _projects[projectId];

  @override
  Future<String?> findProjectRole(String projectId, String userId) async =>
      _roles[projectId]?[userId];

  @override
  Future<Status?> findStatus(String projectId, String statusId) async {
    final status = _statuses[statusId];
    if (status == null || status.projectId != projectId) {
      return null;
    }
    return status;
  }

  @override
  Future<List<Task>> findTasks({
    required String projectId,
    String? assignee,
    String? priority,
  }) async {
    var result = _tasks.values.where((task) => task.projectId == projectId);
    if (assignee != null && assignee.isNotEmpty) {
      result = result.where((task) => task.assigneeId == assignee);
    }
    if (priority != null && priority.isNotEmpty) {
      result = result.where((task) => task.priority == priority);
    }
    final list = result.toList()..sort((a, b) => a.number.compareTo(b.number));
    return List<Task>.unmodifiable(list);
  }

  @override
  Future<List<Status>> listStatuses(String projectId) async {
    final list =
        _statuses.values
            .where((status) => status.projectId == projectId)
            .toList()
          ..sort((a, b) => a.position.compareTo(b.position));
    return List<Status>.unmodifiable(list);
  }

  @override
  Future<Task?> updateTaskStatus(String taskId, String statusId) async {
    final task = _tasks[taskId];
    if (task == null) {
      return null;
    }
    final updated = Task(
      id: task.id,
      projectId: task.projectId,
      number: task.number,
      key: task.key,
      kind: task.kind,
      typeId: task.typeId,
      statusId: statusId,
      title: task.title,
      description: task.description,
      priority: task.priority,
      assigneeId: task.assigneeId,
      reporterId: task.reporterId,
      parentId: task.parentId,
      dueDate: task.dueDate,
      createdAt: task.createdAt,
      updatedAt: DateTime.now().toUtc(),
    );
    _tasks[taskId] = updated;
    return updated;
  }

  @override
  Future<void> recordStatusChange({
    required String taskId,
    required String projectId,
    required String fromStatusId,
    required String toStatusId,
    required String changedBy,
  }) async {}

  @override
  Future<List<TaskStatusChange>> findStatusHistory(String taskId) async =>
      const <TaskStatusChange>[];
}
