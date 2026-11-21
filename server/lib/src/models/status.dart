/// Status of a task within a project (OpenAPI `Status`).
///
/// Belongs to exactly one project; `position` orders statuses on a board,
/// `isDefault` marks the status of newly created tasks.
class Status {
  const Status({
    required this.id,
    required this.projectId,
    required this.name,
    required this.key,
    required this.position,
    required this.isDefault,
  });

  /// Builds a [Status] from a `statuses` row.
  factory Status.fromMap(Map<String, dynamic> row) {
    return Status(
      id: row['id'] as String,
      projectId: row['project_id'] as String,
      name: row['name'] as String,
      key: row['key'] as String,
      position: row['position'] as int,
      isDefault: row['is_default'] as bool,
    );
  }

  /// OpenAPI `Status` JSON shape: camelCase fields.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'projectId': projectId,
    'name': name,
    'key': key,
    'position': position,
    'isDefault': isDefault,
  };

  /// UUID строкой.
  final String id;

  /// UUID проекта, которому принадлежит статус.
  final String projectId;

  /// Название статуса (например, `To Do`, `In Progress`, `Done`).
  final String name;

  /// Код статуса (например, `todo`, `in_progress`, `done`).
  final String key;

  /// Позиция статуса на доске.
  final int position;

  /// Признак статуса по умолчанию для новых задач проекта.
  final bool isDefault;
}
