/// Classification of a task within a project (OpenAPI `TaskType`).
///
/// Belongs to exactly one project; used for filters and display.
/// Different dimension from [Task.kind].
class TaskType {
  const TaskType({
    required this.id,
    required this.projectId,
    required this.name,
  });

  /// Builds a [TaskType] from a `task_types` row.
  factory TaskType.fromMap(Map<String, dynamic> row) {
    return TaskType(
      id: row['id'] as String,
      projectId: row['project_id'] as String,
      name: row['name'] as String,
    );
  }

  /// OpenAPI `TaskType` JSON shape: `id`, `projectId`, `name` — camelCase.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'projectId': projectId,
    'name': name,
  };

  /// UUID строкой.
  final String id;

  /// UUID проекта, которому принадлежит тип.
  final String projectId;

  /// Название типа (например, `bug`, `feature`, `custom`).
  final String name;
}
