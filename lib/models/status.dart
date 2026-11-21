/// Статус задачи проекта
/// (`GET /api/v1/projects/{id}/statuses`).
///
/// Статусы настраиваются в проекте; клиент использует их для отображения
/// и фильтрации. Статус по умолчанию назначает сервер при создании задачи.
class Status {
  const Status({
    required this.id,
    required this.projectId,
    required this.name,
    this.color,
    this.position = 0,
    this.isDone = false,
  });

  factory Status.fromJson(Map<String, dynamic> json) {
    return Status(
      id: json['id'] as String? ?? '',
      projectId: json['projectId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      color: json['color'] as String?,
      position: (json['position'] as num?)?.toInt() ??
          (json['order'] as num?)?.toInt() ??
          0,
      isDone: json['isDone'] as bool? ?? false,
    );
  }

  final String id;
  final String projectId;
  final String name;

  /// Необязательный цвет статуса (`#RRGGBB`).
  final String? color;

  /// Порядок в списке (для сортировки).
  final int position;

  /// Признак финального статуса (`Done`).
  final bool isDone;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'projectId': projectId,
        'name': name,
        'color': color,
        'position': position,
        'isDone': isDone,
      };

  @override
  String toString() => 'Status($name)';
}
