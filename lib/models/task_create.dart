import 'task.dart';

/// Запрос на создание задачи
/// (`POST /api/v1/projects/{id}/tasks`, схема `TaskCreate`).
///
/// Номер (`number`/`key`) и статус назначает сервер.
class TaskCreate {
  const TaskCreate({
    required this.kind,
    required this.typeId,
    required this.title,
    this.description,
    this.priority = TaskPriority.medium,
    this.assigneeId,
    this.dueDate,
    this.parentId,
  });

  factory TaskCreate.fromJson(Map<String, dynamic> json) {
    return TaskCreate(
      kind: TaskKind.fromWire(json['kind'] as String?),
      typeId: json['typeId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      priority: TaskPriority.fromWire(json['priority'] as String?),
      assigneeId: json['assigneeId'] as String?,
      dueDate: json['dueDate'] == null
          ? null
          : DateTime.tryParse(json['dueDate'] as String),
      parentId: json['parentId'] as String?,
    );
  }

  /// epic/task/subtask.
  final TaskKind kind;

  /// Настраиваемый тип задачи.
  final String typeId;
  final String title;
  final String? description;
  final TaskPriority priority;
  final String? assigneeId;
  final DateTime? dueDate;
  final String? parentId;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'kind': kind.wire,
        'typeId': typeId,
        'title': title,
        if (description != null) 'description': description,
        'priority': priority.wire,
        if (assigneeId != null) 'assigneeId': assigneeId,
        if (dueDate != null) 'dueDate': dueDate!.toIso8601String(),
        if (parentId != null) 'parentId': parentId,
      };
}
