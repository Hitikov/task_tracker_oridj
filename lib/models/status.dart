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
    this.key = '',
    this.position = 0,
    bool? isDefault,
    this.color,
    bool? isDone,
  })  : isDefault = isDefault ?? isDone ?? false,
        isDone = isDone ?? isDefault ?? false;

  factory Status.fromJson(Map<String, dynamic> json) {
    final key = json['key'] as String? ?? '';
    return Status(
      id: json['id'] as String? ?? '',
      projectId: json['projectId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      key: key,
      position: (json['position'] as num?)?.toInt() ??
          (json['order'] as num?)?.toInt() ??
          0,
      isDefault: json['isDefault'] as bool? ?? false,
      isDone: key == 'done',
    );
  }

  final String id;
  final String projectId;
  final String name;

  /// Код статуса из OpenAPI (`todo`, `in_progress`, `done`, ...).
  final String key;

  /// Порядок в списке (для сортировки).
  final int position;

  /// Статус по умолчанию для новых задач проекта.
  final bool isDefault;

  /// Устаревший алиас: финальный статус (`done`). Не отправляется в API.
  final bool isDone;

  /// Устаревшее поле; сервер его не возвращает.
  final String? color;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'projectId': projectId,
        'name': name,
        'key': key,
        'position': position,
        'isDefault': isDefault,
      };

  @override
  String toString() => 'Status($name)';
}
