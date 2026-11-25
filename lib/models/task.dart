/// Структурная роль задачи в иерархии (схема `task_kind`).
///
/// `kind` — фиксированный enum и не смешивается с [TaskType] (тип задачи).
enum TaskKind {
  epic,
  task,
  subtask;

  /// Значение в JSON/API.
  String get wire => name;

  /// Короткое имя для UI.
  String get label => switch (this) {
        TaskKind.epic => 'Эпик',
        TaskKind.task => 'Задача',
        TaskKind.subtask => 'Подзадача',
      };

  static TaskKind fromWire(String? value) => switch (value) {
        'epic' => TaskKind.epic,
        'subtask' => TaskKind.subtask,
        'task' => TaskKind.task,
        _ => TaskKind.task,
      };
}

/// Приоритет задачи (схема `task_priority`).
enum TaskPriority {
  low,
  medium,
  high,
  critical;

  /// Значение в JSON/API (/OpenAPI `task_priority`).
  String get wire => name;

  /// Имя для UI.
  String get label => switch (this) {
        TaskPriority.low => 'Низкий',
        TaskPriority.medium => 'Средний',
        TaskPriority.high => 'Высокий',
        TaskPriority.critical => 'Критический',
      };

  static TaskPriority fromWire(String? value) => switch (value) {
        'low' => TaskPriority.low,
        'high' => TaskPriority.high,
        'critical' => TaskPriority.critical,
        _ => TaskPriority.medium,
      };
}

/// Задача проекта (схема `Task` OpenAPI).
///
/// Номер и статус назначает сервер: `number`/`key` только на чтение,
/// `statusId` нельзя передать при создании.
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
    this.reporterId,
    this.parentId,
    this.dueDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String? ?? '',
      projectId: json['projectId'] as String? ?? '',
      number: (json['number'] as num?)?.toInt() ?? 0,
      key: json['key'] as String? ?? '',
      kind: TaskKind.fromWire(json['kind'] as String?),
      typeId: json['typeId'] as String? ?? '',
      statusId: json['statusId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      priority: TaskPriority.fromWire(json['priority'] as String?),
      assigneeId: json['assigneeId'] as String?,
      reporterId: json['reporterId'] as String?,
      parentId: json['parentId'] as String?,
      dueDate: _dateTimeFromJson(json['dueDate']),
      createdAt: _dateTimeFromJson(json['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      updatedAt: _dateTimeFromJson(json['updatedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  final String id;
  final String projectId;

  /// Порядковый номер задачи в проекте (выдаёт сервер).
  final int number;

  /// Публичный номер вида `ARIJ-1`.
  final String key;

  /// Структурная роль: epic/task/subtask.
  final TaskKind kind;

  /// Настраиваемый тип задачи (`bug`, `feature`, `custom`, ...).
  final String typeId;

  /// Текущий статус (назначает сервер при создании).
  final String statusId;

  final String title;
  final String? description;
  final TaskPriority priority;
  final String? assigneeId;
  final String? reporterId;
  final String? parentId;
  final DateTime? dueDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'projectId': projectId,
        'number': number,
        'key': key,
        'kind': kind.wire,
        'typeId': typeId,
        'statusId': statusId,
        'title': title,
        'description': description,
        'priority': priority.wire,
        'assigneeId': assigneeId,
        'reporterId': reporterId,
        'parentId': parentId,
        'dueDate': dueDate?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  /// Применяет частичное обновление для оптимистичного отображения.
  ///
  /// Поля, не входящие в [update], сохраняются; `clearAssignee`/
  /// `clearDueDate` позволяют сбросить значения.
  Task applyUpdate(TaskUpdate update) {
    return Task(
      id: id,
      projectId: projectId,
      number: number,
      key: key,
      kind: update.kind ?? kind,
      typeId: update.typeId ?? typeId,
      statusId: update.statusId ?? statusId,
      title: update.title ?? title,
      description: update.description ?? description,
      priority: update.priority ?? priority,
      assigneeId: update.clearAssignee ? null : update.assigneeId ?? assigneeId,
      reporterId: reporterId,
      parentId: update.clearParentId ? null : update.parentId ?? parentId,
      dueDate: update.clearDueDate ? null : update.dueDate ?? dueDate,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  String toString() => 'Task($key, $title)';
}

DateTime? _dateTimeFromJson(Object? value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}

/// Частичное обновление задачи (`PATCH /api/v1/tasks/{id}`).
class TaskUpdate {
  const TaskUpdate({
    this.kind,
    this.typeId,
    this.statusId,
    this.title,
    this.description,
    this.priority,
    this.assigneeId,
    this.dueDate,
    this.parentId,
    this.clearAssignee = false,
    this.clearDueDate = false,
    this.clearParentId = false,
  });

  final TaskKind? kind;
  final String? typeId;
  final String? statusId;
  final String? title;
  final String? description;
  final TaskPriority? priority;
  final String? assigneeId;
  final DateTime? dueDate;
  final String? parentId;

  /// Явно очищает `assigneeId` (отправить `null`).
  final bool clearAssignee;

  /// Явно очищает `dueDate` (отправить `null`).
  final bool clearDueDate;

  /// Явно очищает `parentId` (отправить `null`).
  final bool clearParentId;

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (kind != null) 'kind': kind!.wire,
        if (typeId != null) 'typeId': typeId,
        if (statusId != null) 'statusId': statusId,
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (priority != null) 'priority': priority!.wire,
        if (clearAssignee)
          'assigneeId': null
        else if (assigneeId != null)
          'assigneeId': assigneeId,
        if (clearDueDate)
          'dueDate': null
        else if (dueDate != null)
          'dueDate': dueDate!.toIso8601String(),
        if (clearParentId)
          'parentId': null
        else if (parentId != null)
          'parentId': parentId,
      };
}
