/// The public user model of the API (OpenAPI `User`).
///
/// Deliberately contains no password hash: the hash exists only inside
/// [UserRecord] values of the repository and never crosses the API boundary.
class User {
  const User({
    required this.id,
    required this.email,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Builds a [User] from a `users` row (snake_case storage columns).
  factory User.fromMap(Map<String, dynamic> row) {
    return User(
      id: row['id'] as String,
      email: row['email'] as String,
      name: row['name'] as String,
      createdAt: row['created_at'] as DateTime,
      updatedAt: row['updated_at'] as DateTime,
    );
  }

  /// OpenAPI `User` JSON shape: `id`, `email`, `name`, `createdAt`,
  /// `updatedAt` — camelCase, `DateTime` as ISO 8601 strings.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'email': email,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  /// UUID string.
  final String id;

  /// Email (stored as provided on registration, matched case-insensitively).
  final String email;

  /// Display name (1–100 characters).
  final String name;

  /// When the user was created (server time, UTC).
  final DateTime createdAt;

  /// When the user was last updated (server time, UTC).
  final DateTime updatedAt;
}
