import 'package:arij_server/src/models/project.dart';
import 'package:arij_server/src/models/status.dart';
import 'package:arij_server/src/models/task.dart';
import 'package:arij_server/src/models/task_type.dart';
import 'package:arij_server/src/repositories/task_repository.dart';

/// In-memory [TaskRepository] for service and route tests.
///
/// Mirrors the storage rules of `tasks`/`task_types`/`statuses`:
/// unique `(project_id, number)` ([TaskNumberRaceException] can be forced
/// with [throwNumberRaceOnCreate]) and project membership as the access
/// rule (`owner`/`member` rows seeded with [seedProject]).
class FakeTaskRepository implements TaskRepository {
  FakeTaskRepository({this.throwNumberRaceOnCreate = false});

  /// When true, [createTask] throws [TaskNumberRaceException] instead of
  /// assigning a number — simulates a lost numbering race.
  final bool throwNumberRaceOnCreate;

  final Map<String, Project> _projects = <String, Project>{};

  /// project_id → (user_id → role).
  final Map<String, Map<String, String>> _roles =
      <String, Map<String, String>>{};
  final Map<String, TaskType> _types = <String, TaskType>{};
  final Map<String, Status> _statuses = <String, Status>{};
  final Map<String, Task> _tasks = <String, Task>{};

  int _nextSequence = 1;

  String _nextId() =>
      'task-00000000-0000-4000-8000-'
      '${_nextSequence.toString().padLeft(12, '0')}';

  // --- Test-only seeding -------------------------------------------------

  /// Registers [project] and records [ownerId] as its `owner` member;
  /// [memberIds] are added as `member`s.
  void seedProject({
    required String id,
    required String key,
    required String ownerId,
    Iterable<String> memberIds = const [],
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

  void seedTaskType({
    required String id,
    required String projectId,
    required String name,
  }) {
    _types[id] = TaskType(id: id, projectId: projectId, name: name);
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

  /// Inserts a ready-made [Task] (useful for seeding parents).
  void seedTask(Task task) {
    _tasks[task.id] = task;
  }

  /// The project's key, or `null`.
  String? projectKey(String projectId) => _projects[projectId]?.key;

  // --- TaskRepository ----------------------------------------------------

  @override
  Future<List<Task>> findTasks({
    required String projectId,
    String? status,
    String? assignee,
    String? priority,
    String? kind,
  }) async {
    var result = _tasks.values.where((task) => task.projectId == projectId);
    if (status != null && status.isNotEmpty) {
      result = result.where((task) => task.statusId == status);
    }
    if (assignee != null && assignee.isNotEmpty) {
      result = result.where((task) => task.assigneeId == assignee);
    }
    if (priority != null && priority.isNotEmpty) {
      result = result.where((task) => task.priority == priority);
    }
    if (kind != null && kind.isNotEmpty) {
      result = result.where((task) => task.kind == kind);
    }
    final list = result.toList();
    list.sort((a, b) => a.number.compareTo(b.number));
    return List.unmodifiable(list);
  }

  @override
  Future<Task?> findTaskById(String taskId) async => _tasks[taskId];

  @override
  Future<Task> createTask({
    required String projectId,
    required String kind,
    required String typeId,
    required String statusId,
    required String title,
    String? description,
    required String priority,
    String? assigneeId,
    required String reporterId,
    String? parentId,
    DateTime? dueDate,
  }) async {
    final project = _projects[projectId];
    if (project == null) {
      throw StateError('Project $projectId does not exist');
    }
    final numbers = _tasks.values
        .where((task) => task.projectId == projectId)
        .map((task) => task.number);
    final number = numbers.isEmpty
        ? 1
        : numbers.reduce((a, b) => a > b ? a : b) + 1;
    if (throwNumberRaceOnCreate) {
      throw TaskNumberRaceException(projectId);
    }
    final id = _nextId();
    _nextSequence++;
    final now = DateTime.now().toUtc();
    final task = Task(
      id: id,
      projectId: projectId,
      number: number,
      key: '${project.key}-$number',
      kind: kind,
      typeId: typeId,
      statusId: statusId,
      title: title.trim(),
      description: description,
      priority: priority,
      assigneeId: assigneeId,
      reporterId: reporterId,
      parentId: parentId,
      dueDate: dueDate,
      createdAt: now,
      updatedAt: now,
    );
    _tasks[id] = task;
    return task;
  }

  @override
  Future<Task?> updateTask(String taskId, Map<String, Object?> fields) async {
    final task = _tasks[taskId];
    if (task == null) {
      return null;
    }
    final updated = Task(
      id: task.id,
      projectId: task.projectId,
      number: task.number,
      key: task.key,
      kind: fields['kind'] as String? ?? task.kind,
      typeId: fields['typeId'] as String? ?? task.typeId,
      statusId: fields['statusId'] as String? ?? task.statusId,
      title: fields['title'] as String? ?? task.title,
      description: fields.containsKey('description')
          ? fields['description'] as String?
          : task.description,
      priority: fields['priority'] as String? ?? task.priority,
      assigneeId: fields.containsKey('assigneeId')
          ? fields['assigneeId'] as String?
          : task.assigneeId,
      reporterId: task.reporterId,
      parentId: fields.containsKey('parentId')
          ? fields['parentId'] as String?
          : task.parentId,
      dueDate: fields.containsKey('dueDate')
          ? fields['dueDate'] as DateTime?
          : task.dueDate,
      createdAt: task.createdAt,
      updatedAt: DateTime.now().toUtc(),
    );
    _tasks[taskId] = updated;
    return updated;
  }

  @override
  Future<bool> deleteTask(String taskId) async {
    return _tasks.remove(taskId) != null;
  }

  @override
  Future<Project?> findProject(String projectId) async => _projects[projectId];

  @override
  Future<String?> findProjectRole(String projectId, String userId) async =>
      _roles[projectId]?[userId];

  @override
  Future<TaskType?> findTaskType(String projectId, String typeId) async {
    for (final type in _types.values) {
      if (type.projectId == projectId && type.id == typeId) {
        return type;
      }
    }
    return null;
  }

  @override
  Future<Status?> findStatus(String projectId, String statusId) async {
    for (final status in _statuses.values) {
      if (status.projectId == projectId && status.id == statusId) {
        return status;
      }
    }
    return null;
  }

  @override
  Future<List<TaskType>> listTaskTypes(String projectId) async {
    final list = _types.values
        .where((type) => type.projectId == projectId)
        .toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return List.unmodifiable(list);
  }

  @override
  Future<List<Status>> listStatuses(String projectId) async {
    final list = _statuses.values
        .where((status) => status.projectId == projectId)
        .toList();
    list.sort((a, b) => a.position.compareTo(b.position));
    return List.unmodifiable(list);
  }
}
