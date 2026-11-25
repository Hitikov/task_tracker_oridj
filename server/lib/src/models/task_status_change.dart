/// Одна запись истории переходов статусов задачи (OpenAPI
/// `TaskStatusChange`).
///
/// `fromStatusId` и `toStatusId` ссылаются на статусы проекта задачи;
/// `changedBy` — пользователь, выполнивший `PATCH /tasks/{id}/status`.
class TaskStatusChange {
  const TaskStatusChange({
    required this.id,
    required this.taskId,
    required this.fromStatusId,
    required this.toStatusId,
    required this.changedBy,
    required this.changedAt,
  });

  /// Builds a [TaskStatusChange] from a `task_status_changes` row.
  factory TaskStatusChange.fromMap(Map<String, dynamic> row) {
    return TaskStatusChange(
      id: row['id'] as String,
      taskId: row['task_id'] as String,
      fromStatusId: row['from_status_id'] as String,
      toStatusId: row['to_status_id'] as String,
      changedBy: row['changed_by'] as String,
      changedAt: row['changed_at'] as DateTime,
    );
  }

  /// OpenAPI `TaskStatusChange` JSON shape: camelCase fields, `changedAt`
  /// as an ISO 8601 string.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'taskId': taskId,
    'fromStatusId': fromStatusId,
    'toStatusId': toStatusId,
    'changedBy': changedBy,
    'changedAt': changedAt.toIso8601String(),
  };

  /// UUID записи.
  final String id;

  /// UUID задачи, чей статус изменён.
  final String taskId;

  /// Статус задачи до изменения.
  final String fromStatusId;

  /// Статус задачи после изменения.
  final String toStatusId;

  /// UUID пользователя, изменившего статус.
  final String changedBy;

  /// Когда изменение зафиксировано (UTC).
  final DateTime changedAt;
}
