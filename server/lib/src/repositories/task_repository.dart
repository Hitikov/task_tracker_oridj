import 'package:postgres/postgres.dart';

import '../db/database.dart';
import '../models/project.dart';
import '../models/status.dart';
import '../models/task.dart';
import '../models/task_type.dart';

/// [TaskRepository.createTask] could not assign a unique number within the
/// project after several attempts (HTTP 409 `task_number_race`).
class TaskNumberRaceException implements Exception {
  const TaskNumberRaceException(this.projectId);

  /// UUID of the project the number belongs to.
  final String projectId;
}

/// Columns of `tasks` that may be updated through [TaskRepository.updateTask].
/// Anything else is rejected before reaching the SQL builder.
const Map<String, String> taskUpdatableColumns = <String, String>{
  'title': 'title',
  'description': 'description',
  'kind': 'kind',
  'typeId': 'type_id',
  'statusId': 'status_id',
  'priority': 'priority',
  'assigneeId': 'assignee_id',
  'parentId': 'parent_id',
  'dueDate': 'due_date',
};

/// SQL access to `tasks`, `task_types`, `statuses` and the project/member
/// rows they depend on.
///
/// Storage rules (see stage-2 migrations, enforced by the DB):
/// - `task_kind` enum: `epic`, `task`, `subtask`;
/// - `task_priority` enum: `low`, `medium`, `high`, `critical`;
/// - `(project_id, number)` is unique; `type_id`/`status_id` reference
///   rows of the same project (`ON DELETE RESTRICT`);
/// - `parent_id` references `tasks(id)` (`ON DELETE RESTRICT`);
/// - access to a project goes through `project_members` (`owner`/`member`).
abstract interface class TaskRepository {
  /// Tasks of [projectId], optionally filtered by `status_id`,
  /// `assignee_id`, `priority` or `kind`, ordered by `number`.
  Future<List<Task>> findTasks({
    required String projectId,
    String? status,
    String? assignee,
    String? priority,
    String? kind,
  });

  /// Task by id (the UUID string); returns `null` when absent.
  Future<Task?> findTaskById(String taskId);

  /// Inserts a new task and assigns a unique `number` within the project:
  /// `SELECT COALESCE(MAX(number), 0) + 1 ...` inside a transaction, retried
  /// when the concurrent insert loses the `(project_id, number)` unique
  /// violation battle.
  ///
  /// Throws [TaskNumberRaceException] when the number cannot be assigned
  /// after several attempts.
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
  });

  /// Partially updates [taskId] with task-mutable columns and bumps
  /// `updated_at`. Returns `null` when no row matched.
  ///
  /// Only keys of [taskUpdatableColumns] are accepted.
  Future<Task?> updateTask(String taskId, Map<String, Object?> fields);

  /// Deletes [taskId]; returns whether a row was removed.
  Future<bool> deleteTask(String taskId);

  /// The project [projectId], or `null` when absent.
  Future<Project?> findProject(String projectId);

  /// The role of [userId] in [projectId] (`owner` or `member`), or `null`
  /// when the user is not a member or the project does not exist.
  Future<String?> findProjectRole(String projectId, String userId);

  /// The task type [typeId] of [projectId], or `null`.
  Future<TaskType?> findTaskType(String projectId, String typeId);

  /// The status [statusId] of [projectId], or `null`.
  Future<Status?> findStatus(String projectId, String statusId);

  /// Task types of [projectId], ordered by `position`.
  Future<List<TaskType>> listTaskTypes(String projectId);

  /// Statuses of [projectId], ordered by `position`.
  Future<List<Status>> listStatuses(String projectId);
}

/// [TaskRepository] over PostgreSQL via [Database].
class PostgresTaskRepository implements TaskRepository {
  PostgresTaskRepository(this._db);

  final Database _db;

  static const int _maxNumberRetries = 5;

  static const String _taskColumns = '''
    t.id, t.project_id, t.number, p.key AS key, t.kind, t.type_id, t.status_id,
    t.title, t.description, t.priority, t.assignee_id, t.reporter_id,
    t.parent_id, t.due_date, t.created_at, t.updated_at
  ''';

  static const String _typeColumns = 'id, project_id, name';
  static const String _statusColumns =
      'id, project_id, name, position, is_default';

  /// Maps a `ResultRow` to a plain map of column values.
  ///
  /// In text mode the `postgres` package returns UUID columns as
  /// [UndecodedBytes]; the models need plain strings.
  static Map<String, dynamic> _columnMap(ResultRow row) {
    return row.toColumnMap().map(
      (key, value) =>
          MapEntry(key, value is UndecodedBytes ? value.asString : value),
    );
  }

  @override
  Future<List<Task>> findTasks({
    required String projectId,
    String? status,
    String? assignee,
    String? priority,
    String? kind,
  }) async {
    final clauses = <String>['t.project_id = \$1'];
    final parameters = <Object?>[projectId];
    void addFilter(String? value, String column) {
      if (value == null || value.isEmpty) {
        return;
      }
      clauses.add('$column = \$${parameters.length + 1}');
      parameters.add(value);
    }

    addFilter(status, 't.status_id');
    addFilter(assignee, 't.assignee_id');
    addFilter(priority, 't.priority');
    addFilter(kind, 't.kind');

    final result = await _db.query(
      'SELECT $_taskColumns '
      'FROM tasks t JOIN projects p ON p.id = t.project_id '
      'WHERE ${clauses.join(' AND ')} '
      'ORDER BY t.number',
      parameters: parameters,
    );
    return <Task>[for (final row in result) _taskFromRow(row)];
  }

  @override
  Future<Task?> findTaskById(String taskId) async {
    final result = await _db.query(
      'SELECT $_taskColumns '
      'FROM tasks t JOIN projects p ON p.id = t.project_id '
      'WHERE t.id = \$1',
      parameters: <Object?>[taskId],
    );
    if (result.isEmpty) {
      return null;
    }
    return _taskFromRow(result.first);
  }

  /// Builds a [Task] from a joined row; `key` is `<project key>-<number>`.
  Task _taskFromRow(ResultRow row) {
    final map = _columnMap(row);
    map['key'] = '${map['key']}-${map['number']}';
    return Task.fromMap(map);
  }

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
    // [Database.transaction] returns void, so the created task is passed out
    // through a captured variable.
    Task? created;
    var attempt = 0;
    while (created == null) {
      attempt++;
      try {
        await _db.transaction((tx) async {
          final number = await _nextNumber(tx, projectId);
          final projectKey = await _projectKeyInTx(tx, projectId);
          if (projectKey == null) {
            throw StateError('Project $projectId does not exist');
          }
          final result = await tx.execute(
            'INSERT INTO tasks ('
            'project_id, number, kind, type_id, status_id, title, '
            'description, priority, assignee_id, reporter_id, parent_id, '
            'due_date, created_at, updated_at) '
            'VALUES (\$1, \$2, \$3, \$4, \$5, \$6, \$7, \$8, \$9, \$10, \$11, '
            '\$12, now(), now()) '
            'RETURNING id, project_id, number, kind, type_id, status_id, '
            'title, description, priority, assignee_id, reporter_id, '
            'parent_id, due_date, created_at, updated_at',
            parameters: <Object?>[
              projectId,
              number,
              kind,
              typeId,
              statusId,
              title,
              description,
              priority,
              assigneeId,
              reporterId,
              parentId,
              dueDate,
            ],
          );
          final map = _columnMap(result.first);
          map['key'] = '$projectKey-$number';
          created = Task.fromMap(map);
        });
      } on UniqueViolationException {
        // Lost a concurrent-insert race on the (project_id, number)
        // unique constraint — generate the next number and retry.
        if (attempt >= _maxNumberRetries) {
          throw TaskNumberRaceException(projectId);
        }
      }
    }
    return created!;
  }

  @override
  Future<Task?> updateTask(String taskId, Map<String, Object?> fields) async {
    if (fields.isEmpty) {
      throw ArgumentError('fields must not be empty');
    }
    final setClauses = <String>[];
    final parameters = <Object?>[];
    for (final entry in fields.entries) {
      final column = taskUpdatableColumns[entry.key];
      if (column == null) {
        // Unreachable: the service validates keys before calling.
        throw StateError('Unsupported update column: ${entry.key}');
      }
      setClauses.add('$column = \$${parameters.length + 1}');
      parameters.add(entry.value);
    }
    setClauses.add('updated_at = now()');
    parameters.add(taskId);
    final result = await _db.query(
      'UPDATE tasks SET ${setClauses.join(', ')} '
      'WHERE id = \$${parameters.length} '
      'RETURNING id, project_id, number, kind, type_id, status_id, title, '
      'description, priority, assignee_id, reporter_id, parent_id, '
      'due_date, created_at, updated_at',
      parameters: parameters,
    );
    if (result.isEmpty) {
      return null;
    }
    final map = _columnMap(result.first);
    final projectId = map['project_id'] as String;
    final key = await _projectKey(projectId);
    // The task exists, so its project exists as well.
    map['key'] = '$key-${map['number']}';
    return Task.fromMap(map);
  }

  @override
  Future<bool> deleteTask(String taskId) async {
    final result = await _db.query(
      'DELETE FROM tasks WHERE id = \$1',
      parameters: <Object?>[taskId],
    );
    return result.affectedRows > 0;
  }

  @override
  Future<Project?> findProject(String projectId) async {
    final result = await _db.query(
      'SELECT id, key, name, description, owner_id, created_at, updated_at '
      'FROM projects WHERE id = \$1',
      parameters: <Object?>[projectId],
    );
    if (result.isEmpty) {
      return null;
    }
    return Project.fromMap(_columnMap(result.first));
  }

  @override
  Future<String?> findProjectRole(String projectId, String userId) async {
    final result = await _db.query(
      'SELECT role FROM project_members WHERE project_id = \$1 AND user_id = \$2',
      parameters: <Object?>[projectId, userId],
    );
    if (result.isEmpty) {
      return null;
    }
    return _columnMap(result.first)['role'] as String?;
  }

  @override
  Future<TaskType?> findTaskType(String projectId, String typeId) async {
    final result = await _db.query(
      'SELECT $_typeColumns FROM task_types WHERE project_id = \$1 AND id = \$2',
      parameters: <Object?>[projectId, typeId],
    );
    if (result.isEmpty) {
      return null;
    }
    return TaskType.fromMap(_columnMap(result.first));
  }

  @override
  Future<Status?> findStatus(String projectId, String statusId) async {
    final result = await _db.query(
      'SELECT $_statusColumns FROM statuses WHERE project_id = \$1 AND id = \$2',
      parameters: <Object?>[projectId, statusId],
    );
    if (result.isEmpty) {
      return null;
    }
    return Status.fromMap(_columnMap(result.first));
  }

  @override
  Future<List<TaskType>> listTaskTypes(String projectId) async {
    final result = await _db.query(
      'SELECT $_typeColumns FROM task_types WHERE project_id = \$1 '
      'ORDER BY name',
      parameters: <Object?>[projectId],
    );
    return <TaskType>[
      for (final row in result) TaskType.fromMap(_columnMap(row)),
    ];
  }

  @override
  Future<List<Status>> listStatuses(String projectId) async {
    final result = await _db.query(
      'SELECT $_statusColumns FROM statuses WHERE project_id = \$1 '
      'ORDER BY position',
      parameters: <Object?>[projectId],
    );
    return <Status>[for (final row in result) Status.fromMap(_columnMap(row))];
  }

  // --- Helpers ---

  /// Next free task number within [projectId]
  /// (`COALESCE(MAX(number), 0) + 1`) inside the current transaction.
  Future<int> _nextNumber(TxSession session, String projectId) async {
    final result = await session.execute(
      'SELECT COALESCE(MAX(number), 0) + 1 AS number '
      'FROM tasks WHERE project_id = \$1',
      parameters: <Object?>[projectId],
    );
    final value = _columnMap(result.first)['number'];
    return value is int ? value : int.parse(value.toString());
  }

  /// The `key` of [projectId], or `null` when the project does not exist.
  Future<String?> _projectKey(String projectId) async {
    final result = await _db.query(
      'SELECT key FROM projects WHERE id = \$1',
      parameters: <Object?>[projectId],
    );
    if (result.isEmpty) {
      return null;
    }
    return _columnMap(result.first)['key'] as String?;
  }

  /// The `key` of [projectId] inside [session], or `null` when absent.
  Future<String?> _projectKeyInTx(TxSession session, String projectId) async {
    final result = await session.execute(
      'SELECT key FROM projects WHERE id = \$1',
      parameters: <Object?>[projectId],
    );
    if (result.isEmpty) {
      return null;
    }
    return _columnMap(result.first)['key'] as String?;
  }
}
