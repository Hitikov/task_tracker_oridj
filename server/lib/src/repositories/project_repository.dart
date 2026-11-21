import 'package:postgres/postgres.dart';

import '../db/database.dart';
import '../models/project.dart';
import '../models/user.dart';

/// Domain exception of [ProjectRepository.create]: the project key is
/// already taken by another project (HTTP 409 `project_key_taken`).
class ProjectKeyTakenException implements Exception {
  const ProjectKeyTakenException();
}

/// Domain exception of [ProjectRepository.addMember]: the user is already
/// a member of the project (HTTP 409 `member_exists`).
class MemberExistsException implements Exception {
  const MemberExistsException(this.userId);

  /// UUID of the user that already has a membership row.
  final String userId;
}

/// SQL access to `projects`, `project_members` and the `users` rows used
/// by member lookups.
///
/// Storage rules (see migrations `0002_projects.sql` and
/// `0003_project_members.sql`, enforced by the DB):
/// - `projects.key` is globally unique and matches `^[A-Z][A-Z0-9]{1,9}$`;
/// - the owner is recorded in `project_members` with role `owner`; a
///   partial unique index (`uq_project_members_owner`) guarantees at most
///   one owner per project;
/// - member/project rows are removed by `ON DELETE CASCADE`.
abstract interface class ProjectRepository {
  /// Inserts a new project and records the owner in `project_members`
  /// in a single transaction.
  ///
  /// Throws [ProjectKeyTakenException] when another project already uses
  /// [key] — including the race where two concurrent inserts lose the
  /// unique-violation battle.
  Future<Project> create({
    required String key,
    required String name,
    required String? description,
    required String ownerId,
  });

  /// Finds a project by id (the UUID string); returns `null` when absent
  /// or not visible to anyone.
  Future<Project?> findById(String projectId);

  /// Projects the user is a member of, ordered by `updated_at` DESC
  /// (most recently updated first, per OpenAPI `GET /projects`).
  Future<List<Project>> findByUser(String userId);

  /// Updates mutable project fields (`name`, `description`) and bumps
  /// `updated_at`. Returns `null` when no row matched.
  Future<Project?> update(String projectId, Map<String, Object?> fields);

  /// Deletes the project; member rows go with it through the DB cascade.
  /// Returns whether a project was deleted.
  Future<bool> delete(String projectId);

  /// All members of the project (owner included), ordered by `joined_at`.
  Future<List<ProjectMember>> listMembers(String projectId);

  /// The membership row of [userId] in [projectId], or `null` when the
  /// user is not a member.
  Future<ProjectMember?> findMember(String projectId, String userId);

  /// The role of [userId] in [projectId] (`owner` or `member`), or `null`
  /// when the user is not a member.
  Future<String?> findRole(String projectId, String userId);

  /// Adds [userId] to `project_members` of [projectId] with [role].
  /// Returns the new membership row.
  ///
  /// Throws [MemberExistsException] when a row already exists — including
  /// the race where two concurrent inserts lose the unique-violation
  /// battle on the `(project_id, user_id)` primary key.
  Future<ProjectMember> addMember(
    String projectId,
    String userId, {
    required String role,
  });

  /// Removes [userId] from the project's membership.
  /// Returns whether a row was removed.
  Future<bool> removeMember(String projectId, String userId);

  /// Finds a user by email (the `citext` lookup); returns `null` when
  /// nobody is registered with it.
  Future<User?> findUserByEmail(String email);
}

/// [ProjectRepository] over the `projects`, `project_members` and `users`
/// tables via [Database].
class PostgresProjectRepository implements ProjectRepository {
  PostgresProjectRepository(this._db);

  final Database _db;

  static const String _projectColumns =
      'id, key, name, description, owner_id, created_at, updated_at';

  /// Columns updatable through [update]; anything else is rejected before
  /// reaching the SQL builder (the service validates keys first).
  static const Map<String, String> _updatableColumns = <String, String>{
    'name': 'name',
    'description': 'description',
  };

  /// Maps a `ResultRow` to a plain map of column values.
  ///
  /// In text mode the `postgres` package returns UUID columns as
  /// [UndecodedBytes]; the models need plain strings.
  static Map<String, dynamic> _columnMap(ResultRow row) {
    return row.toColumnMap().map(
      (key, value) =>
          MapEntry(key, value is UndecodedBytes ? value.asString : value),
    );
  }

  @override
  Future<Project> create({
    required String key,
    required String name,
    required String? description,
    required String ownerId,
  }) async {
    Project? project;
    try {
      await _db.transaction((tx) async {
        final result = await tx.execute(
          'INSERT INTO projects (key, name, description, owner_id) '
          'VALUES (\$1, \$2, \$3, \$4) '
          'RETURNING $_projectColumns',
          parameters: <Object?>[key, name, description, ownerId],
        );
        project = Project.fromMap(_columnMap(result.first));
        await tx.execute(
          'INSERT INTO project_members (project_id, user_id, role) '
          "VALUES (\$1, \$2, 'owner')",
          parameters: <Object?>[project!.id, ownerId],
        );
      });
    } on UniqueViolationException {
      // Lost a concurrent-insert race on the UNIQUE key constraint.
      throw const ProjectKeyTakenException();
    }
    return project!;
  }

  @override
  Future<Project?> findById(String projectId) async {
    final result = await _db.query(
      'SELECT $_projectColumns FROM projects WHERE id = \$1',
      parameters: <Object?>[projectId],
    );
    if (result.isEmpty) {
      return null;
    }
    return Project.fromMap(_columnMap(result.first));
  }

  @override
  Future<List<Project>> findByUser(String userId) async {
    final result = await _db.query(
      'SELECT p.id, p.key, p.name, p.description, p.owner_id, '
      'p.created_at, p.updated_at '
      'FROM projects p JOIN project_members pm ON pm.project_id = p.id '
      'WHERE pm.user_id = \$1 ORDER BY p.updated_at DESC',
      parameters: <Object?>[userId],
    );
    return <Project>[
      for (final row in result) Project.fromMap(_columnMap(row)),
    ];
  }

  @override
  Future<Project?> update(String projectId, Map<String, Object?> fields) async {
    if (fields.isEmpty) {
      throw ArgumentError('fields must not be empty');
    }
    final setClauses = <String>[];
    final parameters = <Object?>[];
    for (final entry in fields.entries) {
      final column = _updatableColumns[entry.key];
      if (column == null) {
        // Unreachable: the service validates keys before calling.
        throw StateError('Unsupported update column: ${entry.key}');
      }
      setClauses.add('$column = \$${parameters.length + 1}');
      parameters.add(entry.value);
    }
    setClauses.add('updated_at = now()');
    parameters.add(projectId);
    final result = await _db.query(
      'UPDATE projects SET ${setClauses.join(', ')} '
      'WHERE id = \$${parameters.length} '
      'RETURNING $_projectColumns',
      parameters: parameters,
    );
    if (result.isEmpty) {
      return null;
    }
    return Project.fromMap(_columnMap(result.first));
  }

  @override
  Future<bool> delete(String projectId) async {
    final result = await _db.query(
      'DELETE FROM projects WHERE id = \$1',
      parameters: <Object?>[projectId],
    );
    return result.affectedRows > 0;
  }

  @override
  Future<List<ProjectMember>> listMembers(String projectId) async {
    final result = await _db.query(
      'SELECT u.id AS user_id, u.email, u.name, pm.role, pm.joined_at '
      'FROM project_members pm JOIN users u ON u.id = pm.user_id '
      'WHERE pm.project_id = \$1 ORDER BY pm.joined_at',
      parameters: <Object?>[projectId],
    );
    return <ProjectMember>[
      for (final row in result) ProjectMember.fromMap(_columnMap(row)),
    ];
  }

  @override
  Future<ProjectMember?> findMember(String projectId, String userId) async {
    final result = await _db.query(
      'SELECT u.id AS user_id, u.email, u.name, pm.role, pm.joined_at '
      'FROM project_members pm JOIN users u ON u.id = pm.user_id '
      'WHERE pm.project_id = \$1 AND pm.user_id = \$2',
      parameters: <Object?>[projectId, userId],
    );
    if (result.isEmpty) {
      return null;
    }
    return ProjectMember.fromMap(_columnMap(result.first));
  }

  @override
  Future<String?> findRole(String projectId, String userId) async {
    final result = await _db.query(
      'SELECT role FROM project_members WHERE project_id = \$1 '
      'AND user_id = \$2',
      parameters: <Object?>[projectId, userId],
    );
    if (result.isEmpty) {
      return null;
    }
    return _columnMap(result.first)['role'] as String?;
  }

  @override
  Future<ProjectMember> addMember(
    String projectId,
    String userId, {
    required String role,
  }) async {
    try {
      await _db.query(
        'INSERT INTO project_members (project_id, user_id, role) '
        'VALUES (\$1, \$2, \$3)',
        parameters: <Object?>[projectId, userId, role],
      );
    } on UniqueViolationException {
      // Lost a concurrent-insert race on the `(project_id, user_id)` PK.
      throw MemberExistsException(userId);
    }
    final member = await findMember(projectId, userId);
    // The row was inserted a moment ago — the lookup cannot come back empty.
    return member!;
  }

  @override
  Future<bool> removeMember(String projectId, String userId) async {
    final result = await _db.query(
      'DELETE FROM project_members WHERE project_id = \$1 AND user_id = \$2',
      parameters: <Object?>[projectId, userId],
    );
    return result.affectedRows > 0;
  }

  @override
  Future<User?> findUserByEmail(String email) async {
    final result = await _db.query(
      'SELECT id, email, name, created_at, updated_at FROM users '
      'WHERE email = \$1',
      parameters: <Object?>[email],
    );
    if (result.isEmpty) {
      return null;
    }
    return User.fromMap(_columnMap(result.first));
  }
}
