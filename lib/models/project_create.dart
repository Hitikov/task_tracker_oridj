/// Запрос на создание проекта (схема `ProjectCreate`).
class ProjectCreate {
  const ProjectCreate({
    required this.key,
    required this.name,
    this.description,
  });

  factory ProjectCreate.fromJson(Map<String, dynamic> json) {
    return ProjectCreate(
      key: json['key'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
    );
  }

  final String key;
  final String name;
  final String? description;

  Map<String, dynamic> toJson() => {
    'key': key,
    'name': name,
    if (description != null) 'description': description,
  };
}
