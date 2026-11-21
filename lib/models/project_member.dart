/// Участник проекта (схема `ProjectMember` OpenAPI).
///
/// Используется в Backlog для отображения исполнителя по `assigneeId`.
class ProjectMember {
  const ProjectMember({
    required this.userId,
    required this.email,
    required this.name,
    required this.role,
    required this.joinedAt,
  });

  factory ProjectMember.fromJson(Map<String, dynamic> json) {
    return ProjectMember(
      userId: json['userId'] as String? ?? '',
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      role: json['role'] as String? ?? 'member',
      joinedAt: json['joinedAt'] == null
          ? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
          : DateTime.tryParse(json['joinedAt'] as String) ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  final String userId;
  final String email;
  final String name;
  final String role;
  final DateTime joinedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'userId': userId,
        'email': email,
        'name': name,
        'role': role,
        'joinedAt': joinedAt.toIso8601String(),
      };

  @override
  String toString() => 'ProjectMember($userId, $name)';
}
