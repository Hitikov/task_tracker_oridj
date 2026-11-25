/// Настраиваемый тип задачи проекта
/// (`GET /api/v1/projects/{id}/task-types`).
///
/// Тип — сущность проекта (bug/feature/custom), не путать с
/// [TaskKind] (epic/task/subtask).
class TaskType {
  const TaskType({
    required this.id,
    required this.projectId,
    required this.name,
    this.color,
  });

  factory TaskType.fromJson(Map<String, dynamic> json) {
    return TaskType(
      id: json['id'] as String? ?? '',
      projectId: json['projectId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      color: json['color'] as String?,
    );
  }

  final String id;
  final String projectId;
  final String name;

  /// Необязательный цвет для чипа (`#RRGGBB`).
  final String? color;

  /// Сервер возвращает только `id`, `projectId`, `name`, `createdAt`;
  /// устаревшее поле `color` в контракт не входит.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'projectId': projectId,
        'name': name,
      };

  @override
  String toString() => 'TaskType($name)';
}
