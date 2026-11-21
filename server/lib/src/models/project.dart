/// The public project model of the API (OpenAPI `Project`).
class Project {
  const Project({
    required this.id,
    required this.key,
    required this.name,
    required this.description,
    required this.ownerId,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Builds a [Project] from a `projects` row (snake_case storage columns).
  factory Project.fromMap(Map<String, dynamic> row) {
    return Project(
      id: row['id'] as String,
      key: row['key'] as String,
      name: row['name'] as String,
      description: row['description'] as String?,
      ownerId: row['owner_id'] as String,
      createdAt: row['created_at'] as DateTime,
      updatedAt: row['updated_at'] as DateTime,
    );
  }

  /// OpenAPI `Project` JSON shape: `id`, `key`, `name`, `description`,
  /// `ownerId`, `createdAt`, `updatedAt` — camelCase, `DateTime` as ISO 8601
  /// strings.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'key': key,
    'name': name,
    'description': description,
    'ownerId': ownerId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  /// UUID string.
  final String id;

  /// Short unique project key for task numbers (`ARIJ` → `ARIJ-1`).
  /// Matches `^[A-Z][A-Z0-9]{1,9}$`; unique globally, never changes.
  final String key;

  /// Display name (1–100 characters).
  final String name;

  /// Optional description (max 2000 characters, may be null).
  final String? description;

  /// UUID of the user who owns the project.
  final String ownerId;

  /// When the project was created (server time, UTC).
  final DateTime createdAt;

  /// When the project was last updated (server time, UTC).
  final DateTime updatedAt;
}

/// A project member with the user's display data
/// (OpenAPI `ProjectMember`).
class ProjectMember {
  const ProjectMember({
    required this.userId,
    required this.email,
    required this.name,
    required this.role,
    required this.joinedAt,
  });

  /// Builds a [ProjectMember] from `project_members` + `users` columns.
  factory ProjectMember.fromMap(Map<String, dynamic> row) {
    return ProjectMember(
      userId: row['user_id'] as String,
      email: row['email'] as String,
      name: row['name'] as String,
      role: row['role'] as String,
      joinedAt: row['joined_at'] as DateTime,
    );
  }

  /// OpenAPI `ProjectMember` JSON shape: `userId`, `email`, `name`, `role`,
  /// `joinedAt` — camelCase, `DateTime` as ISO 8601 strings.
  Map<String, Object?> toJson() => <String, Object?>{
    'userId': userId,
    'email': email,
    'name': name,
    'role': role,
    'joinedAt': joinedAt.toIso8601String(),
  };

  /// UUID string of the user.
  final String userId;

  /// Email of the user.
  final String email;

  /// Display name of the user.
  final String name;

  /// Role in the project: `owner` or `member` (OpenAPI `user_role`).
  final String role;

  /// When the user joined the project (server time, UTC).
  final DateTime joinedAt;
}
