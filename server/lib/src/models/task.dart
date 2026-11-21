/// The public task model of the API.
///
/// `kind` (структурная роль в иерархии: `epic` / `task` / `subtask`) и
/// `typeId` (ссылка на `task_types` проекта, классификация) — разные
/// измерения задачи, их не смешивать.
class Task {
  const Task({
    required this.id,
    required this.projectId,
    required this.number,
    required this.key,
    required this.kind,
    required this.typeId,
    required this.statusId,
    required this.title,
    this.description,
    required this.priority,
    this.assigneeId,
    required this.reporterId,
    this.parentId,
    this.dueDate,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Builds a [Task] from a `tasks` row joined with `projects`
  /// (`p.key AS key`).
  factory Task.fromMap(Map<String, dynamic> row) {
    return Task(
      id: row['id'] as String,
      projectId: row['project_id'] as String,
      number: row['number'] as int,
      key: row['key'] as String,
      kind: row['kind'] as String,
      typeId: row['type_id'] as String,
      statusId: row['status_id'] as String,
      title: row['title'] as String,
      description: row['description'] as String?,
      priority: row['priority'] as String,
      assigneeId: row['assignee_id'] as String?,
      reporterId: row['reporter_id'] as String,
      parentId: row['parent_id'] as String?,
      dueDate: row['due_date'] as DateTime?,
      createdAt: row['created_at'] as DateTime,
      updatedAt: row['updated_at'] as DateTime,
    );
  }

  /// OpenAPI `Task` JSON shape: camelCase fields, `DateTime` as ISO 8601
  /// strings. `number`/`key` are assigned by the server and read-only.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'projectId': projectId,
    'number': number,
    'key': key,
    'kind': kind,
    'typeId': typeId,
    'statusId': statusId,
    'title': title,
    'description': description,
    'priority': priority,
    'assigneeId': assigneeId,
    'reporterId': reporterId,
    'parentId': parentId,
    'dueDate': dueDate?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  /// UUID строкой.
  final String id;

  /// UUID проекта, которому принадлежит задача.
  final String projectId;

  /// Уникальный номер задачи в рамках проекта.
  final int number;

  /// Ключ задачи (`PROJECT_KEY`-`number`, например `ARIJ-1`).
  final String key;

  /// Роль в иерархии: `epic`, `task` или `subtask`.
  final String kind;

  /// Классификация задачи — ссылка на `task_types` того же проекта.
  final String typeId;

  /// Статус задачи — ссылка на `statuses` того же проекта.
  final String statusId;

  /// Название задачи.
  final String title;

  /// Описание задачи (может быть null).
  final String? description;

  /// Приоритет: `low`, `medium`, `high`, `critical`.
  final String priority;

  /// Исполнитель задачи (может быть null).
  final String? assigneeId;

  /// Автор задачи — пользователь, создавший задачу.
  final String reporterId;

  /// Родительская задача (может быть null).
  final String? parentId;

  /// Дедлайн (может быть null).
  final DateTime? dueDate;

  /// Когда задача создана (UTC).
  final DateTime createdAt;

  /// Когда задача обновлена (UTC).
  final DateTime updatedAt;
}

/// Допустимые значения [Task.kind].
const Set<String> taskKinds = <String>{'epic', 'task', 'subtask'};

/// Допустимые значения [Task.priority].
const Set<String> taskPriorities = <String>{
  'low',
  'medium',
  'high',
  'critical',
};
