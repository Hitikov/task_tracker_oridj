/// Запись истории смены статуса задачи.
///
/// Контракт: `GET /api/v1/tasks/{taskId}/history`
/// → `[{id, taskId, fromStatusId, toStatusId, changedBy, changedAt}]`.
/// `fromStatusId` отсутствует у первой записи (задача создана в статусе).
class TaskStatusChange {
  const TaskStatusChange({
    required this.id,
    required this.taskId,
    required this.toStatusId,
    required this.changedAt,
    this.fromStatusId,
    this.changedBy,
  });

  factory TaskStatusChange.fromJson(Map<String, dynamic> json) {
    return TaskStatusChange(
      id: json['id'] as String? ?? '',
      taskId: json['taskId'] as String? ?? '',
      fromStatusId: json['fromStatusId'] as String?,
      toStatusId: json['toStatusId'] as String? ?? '',
      changedBy: json['changedBy'] as String?,
      changedAt: _dateTimeFromJson(json['changedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  final String id;
  final String taskId;

  /// Статус до перехода; null для начальной записи.
  final String? fromStatusId;

  /// Статус после перехода.
  final String toStatusId;

  /// Идентификатор пользователя, изменившего статус.
  final String? changedBy;

  final DateTime changedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'taskId': taskId,
        'fromStatusId': fromStatusId,
        'toStatusId': toStatusId,
        'changedBy': changedBy,
        'changedAt': changedAt.toIso8601String(),
      };

  @override
  String toString() =>
      'TaskStatusChange($fromStatusId -> $toStatusId, $changedAt)';
}

DateTime? _dateTimeFromJson(Object? value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}
