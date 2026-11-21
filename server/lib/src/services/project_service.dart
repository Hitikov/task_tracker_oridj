import '../models/project.dart';
import '../repositories/project_repository.dart';

/// Domain exception of [ProjectService]: an input field failed validation
/// (HTTP 400 `validation_error`).
///
/// The routes layer maps it to `400 validation_error` with the field name in
/// `details.field`.
class ValidationException implements Exception {
  const ValidationException(this.field);

  /// Name of the invalid field (OpenAPI `details.field`); `null` when the
  /// request itself is not a valid JSON object or there is no specific
  /// field.
  final String? field;
}

/// Domain exception of [ProjectService]: the user is not allowed to perform
/// the operation (HTTP 403 `forbidden`).
class ForbiddenException implements Exception {
  const ForbiddenException();
}

/// Domain exception of [ProjectService]: a resource was not found or is
/// not visible to the caller (HTTP 404 with the OpenAPI error code).
class NotFoundException implements Exception {
  const NotFoundException(this.code, this.message, {this.details});

  /// Machine-readable snake_case code: `project_not_found` or
  /// `member_not_found`.
  final String code;

  /// Human-readable message safe for clients.
  final String message;

  /// Structured context (`resource`, `id`, ...) or `null`.
  final Object? details;
}

/// Domain exception of [ProjectService.removeMember]: the owner cannot be
/// removed without ownership transfer first (HTTP 409
/// `owner_removal_forbidden`).
class OwnerRemovalException implements Exception {
  const OwnerRemovalException(this.userId);

  /// UUID of the owner that was targeted.
  final String userId;
}

/// Business rules of the projects stream (OpenAPI `Project`, `ProjectCreate`,
/// `ProjectUpdate`, `MemberAdd`).
///
/// The service validates input, checks authorization and translates storage
/// outcomes into [ValidationException], [ForbiddenException],
/// [NotFoundException] or [OwnerRemovalException]; SQL lives in the
/// repository and the HTTP envelope in routes.
class ProjectService {
  ProjectService({required this.repository});

  /// Repository to `projects`, `project_members` and `users`.
  final ProjectRepository repository;

  static const int _maxProjectNameLength = 100;
  static const int _maxProjectDescriptionLength = 2000;

  /// OpenAPI `ProjectCreate.key`: `^[A-Za-z][A-Za-z0-9]{1,9}$`
  /// (`minLength: 2`, `maxLength: 10`). The stored key is always uppercased
  /// (`^[A-Z][A-Z0-9]{1,9}$`, OpenAPI `Project.key`).
  static final RegExp _inputKeyPattern = RegExp(r'^[A-Za-z][A-Za-z0-9]{1,9}$');

  // --- Reads ---

  /// Projects of the user — owner or member (`GET /projects`).
  Future<List<Project>> listProjects(String userId) =>
      repository.findByUser(userId);

  /// Project by id for an owner or member (`GET /projects/{id}`).
  Future<Project> getProject({
    required String userId,
    required String projectId,
  }) async {
    final project = await repository.findById(projectId);
    if (project == null) {
      throw _projectNotFound(projectId);
    }
    await _requireMember(userId, projectId);
    return project;
  }

  /// Members of the project for an owner or member
  /// (`GET /projects/{id}/members`).
  Future<List<ProjectMember>> listMembers({
    required String userId,
    required String projectId,
  }) async {
    final project = await repository.findById(projectId);
    if (project == null) {
      throw _projectNotFound(projectId);
    }
    await _requireMember(userId, projectId);
    return repository.listMembers(projectId);
  }

  // --- Writes ---

  /// Creates a project and records the caller as its owner member
  /// (`POST /projects`).
  ///
  /// The key is validated against the OpenAPI create pattern and uppercased
  /// before storage; duplicates surface as [ProjectKeyTakenException] →
  /// `409 project_key_taken`.
  Future<Project> createProject({
    required String userId,
    required String key,
    required String name,
    String? description,
  }) async {
    final normalizedKey = key.trim().toUpperCase();
    if (!_inputKeyPattern.hasMatch(normalizedKey)) {
      throw const ValidationException('key');
    }
    final normalizedName = name.trim();
    if (normalizedName.isEmpty ||
        normalizedName.length > _maxProjectNameLength) {
      throw const ValidationException('name');
    }
    if (description != null &&
        description.trim().length > _maxProjectDescriptionLength) {
      throw const ValidationException('description');
    }
    final normalizedDescription = description?.trim();
    return repository.create(
      key: normalizedKey,
      name: normalizedName,
      description: normalizedDescription,
      ownerId: userId,
    );
  }

  /// Updates mutable project fields (`PATCH /projects/{id}`); owner only.
  ///
  /// [fields] maps `name`/`description` to new values; a null `description`
  /// clears it. `key` and `ownerId` are immutable — passing `key` is a
  /// [ValidationException].
  Future<Project> updateProject({
    required String userId,
    required String projectId,
    required Map<String, Object?> fields,
  }) async {
    final project = await repository.findById(projectId);
    if (project == null) {
      throw _projectNotFound(projectId);
    }
    await _requireOwner(userId, projectId);

    final updates = <String, Object?>{};
    for (final entry in fields.entries) {
      switch (entry.key) {
        case 'name':
          final value = entry.value;
          if (value is! String) {
            throw const ValidationException('name');
          }
          final name = value.trim();
          if (name.isEmpty || name.length > _maxProjectNameLength) {
            throw const ValidationException('name');
          }
          updates['name'] = name;
        case 'description':
          final value = entry.value;
          if (value != null && value is! String) {
            throw const ValidationException('description');
          }
          if (value is String) {
            final description = value.trim();
            if (description.length > _maxProjectDescriptionLength) {
              throw const ValidationException('description');
            }
            updates['description'] = description;
          } else {
            updates['description'] = null;
          }
        default:
          // Immutable or unknown: `key`, `ownerId`, anything else.
          throw ValidationException(entry.key);
      }
    }
    if (updates.isEmpty) {
      // OpenAPI `ProjectUpdate.minProperties: 1` — a no-op patch is a 400.
      throw const ValidationException(null);
    }

    final updated = await repository.update(projectId, updates);
    if (updated == null) {
      throw _projectNotFound(projectId);
    }
    return updated;
  }

  /// Deletes the project (`DELETE /projects/{id}`); owner only.
  /// Members are removed by the DB cascade.
  Future<void> deleteProject({
    required String userId,
    required String projectId,
  }) async {
    final project = await repository.findById(projectId);
    if (project == null) {
      throw _projectNotFound(projectId);
    }
    await _requireOwner(userId, projectId);
    final deleted = await repository.delete(projectId);
    if (!deleted) {
      throw _projectNotFound(projectId);
    }
  }

  /// Adds an existing user to the project by email
  /// (`POST /projects/{id}/members`); owner only.
  ///
  /// The new member always gets role `member` — passing `owner` is how a
  /// caller attempts a second owner, and that is a 400
  /// [ValidationException] (the single-owner invariant).
  Future<ProjectMember> addMember({
    required String userId,
    required String projectId,
    required String email,
    String? role,
  }) async {
    final project = await repository.findById(projectId);
    if (project == null) {
      throw _projectNotFound(projectId);
    }
    await _requireOwner(userId, projectId);
    if (role != null && role != 'member') {
      throw ValidationException('role');
    }
    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty) {
      throw const ValidationException('email');
    }
    final targetUser = await repository.findUserByEmail(normalizedEmail);
    if (targetUser == null) {
      throw NotFoundException(
        'user_not_found',
        'Пользователь не найден',
        details: <String, Object?>{'field': 'email', 'email': normalizedEmail},
      );
    }
    final existing = await repository.findMember(projectId, targetUser.id);
    if (existing != null) {
      throw MemberExistsException(targetUser.id);
    }
    return repository.addMember(projectId, targetUser.id, role: 'member');
  }

  /// Removes a member from the project
  /// (`DELETE /projects/{id}/members/{userId}`); owner only.
  Future<void> removeMember({
    required String userId,
    required String projectId,
    required String userIdToRemove,
  }) async {
    final project = await repository.findById(projectId);
    if (project == null) {
      throw _projectNotFound(projectId);
    }
    await _requireOwner(userId, projectId);
    final member = await repository.findMember(projectId, userIdToRemove);
    if (member == null) {
      throw _memberNotFound(userIdToRemove);
    }
    if (member.role == 'owner') {
      throw OwnerRemovalException(userIdToRemove);
    }
    final removed = await repository.removeMember(projectId, userIdToRemove);
    if (!removed) {
      throw _memberNotFound(userIdToRemove);
    }
  }

  // --- Helpers ---

  /// Requires the user to be a member (owner or member) of [projectId].
  Future<void> _requireMember(String userId, String projectId) async {
    final member = await repository.findMember(projectId, userId);
    if (member == null) {
      throw const ForbiddenException();
    }
  }

  /// Requires the user to be the owner of [projectId].
  Future<void> _requireOwner(String userId, String projectId) async {
    final member = await repository.findMember(projectId, userId);
    if (member == null || member.role != 'owner') {
      throw const ForbiddenException();
    }
  }

  NotFoundException _projectNotFound(String projectId) => NotFoundException(
    'project_not_found',
    'Проект не найден',
    details: <String, Object?>{'resource': 'project', 'id': projectId},
  );

  NotFoundException _memberNotFound(String userId) => NotFoundException(
    'member_not_found',
    'Участник не найден',
    details: <String, Object?>{'resource': 'project_member', 'userId': userId},
  );
}
