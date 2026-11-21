import 'package:arij_server/src/models/project.dart';
import 'package:arij_server/src/models/user.dart';
import 'package:arij_server/src/repositories/project_repository.dart';

import '../auth/fake_user_repository.dart';

/// In-memory [ProjectRepository] for service and route tests.
///
/// Mirrors the storage rules of `projects`/`project_members`: global key
/// uniqueness (throws [ProjectKeyTakenException] on duplicates, like the
/// DB unique constraint) and the `updatedAt`/`joinedAt` semantics the
/// service relies on.
class FakeProjectRepository implements ProjectRepository {
  FakeProjectRepository([FakeUserRepository? userRepository])
    : _users = userRepository ?? FakeUserRepository();

  final FakeUserRepository _users;
  final Map<String, Project> _projects = <String, Project>{};
  final Map<String, List<ProjectMember>> _members =
      <String, List<ProjectMember>>{};
  int _nextSequence = 1;

  String _nextId() =>
      'proj-00000000-0000-4000-8000-'
      '${_nextSequence.toString().padLeft(12, '0')}';

  @override
  Future<Project> create({
    required String key,
    required String name,
    required String? description,
    required String ownerId,
  }) async {
    for (final project in _projects.values) {
      if (project.key == key) {
        throw const ProjectKeyTakenException();
      }
    }
    final now = DateTime.now().toUtc();
    final owner = (await _users.findById(ownerId))!;
    final id = _nextId();
    _nextSequence++;
    final project = Project(
      id: id,
      key: key,
      name: name,
      description: description,
      ownerId: ownerId,
      createdAt: now,
      updatedAt: now,
    );
    _projects[id] = project;
    _members[id] = <ProjectMember>[
      ProjectMember(
        userId: ownerId,
        email: owner.email,
        name: owner.name,
        role: 'owner',
        joinedAt: now,
      ),
    ];
    return project;
  }

  @override
  Future<Project?> findById(String projectId) async => _projects[projectId];

  @override
  Future<List<Project>> findByUser(String userId) async {
    final result = <Project>[];
    for (final project in _projects.values) {
      if (await findMember(project.id, userId) != null) {
        result.add(project);
      }
    }
    result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return result;
  }

  @override
  Future<Project?> update(String projectId, Map<String, Object?> fields) async {
    final project = _projects[projectId];
    if (project == null) {
      return null;
    }
    final updated = Project(
      id: project.id,
      key: project.key,
      name: fields['name'] as String? ?? project.name,
      description: fields.containsKey('description')
          ? fields['description'] as String?
          : project.description,
      ownerId: project.ownerId,
      createdAt: project.createdAt,
      updatedAt: DateTime.now().toUtc(),
    );
    _projects[projectId] = updated;
    return updated;
  }

  @override
  Future<bool> delete(String projectId) async {
    final removed = _projects.remove(projectId) != null;
    _members.remove(projectId);
    return removed;
  }

  @override
  Future<List<ProjectMember>> listMembers(String projectId) async =>
      List.unmodifiable(_members[projectId] ?? const <ProjectMember>[]);

  @override
  Future<ProjectMember?> findMember(String projectId, String userId) async {
    for (final member in _members[projectId] ?? const <ProjectMember>[]) {
      if (member.userId == userId) {
        return member;
      }
    }
    return null;
  }

  @override
  Future<String?> findRole(String projectId, String userId) async {
    return (await findMember(projectId, userId))?.role;
  }

  @override
  Future<ProjectMember> addMember(
    String projectId,
    String userId, {
    required String role,
  }) async {
    if (await findMember(projectId, userId) != null) {
      throw MemberExistsException(userId);
    }
    final user = (await _users.findById(userId))!;
    final member = ProjectMember(
      userId: userId,
      email: user.email,
      name: user.name,
      role: role,
      joinedAt: DateTime.now().toUtc(),
    );
    _members.putIfAbsent(projectId, () => <ProjectMember>[]).add(member);
    return member;
  }

  @override
  Future<bool> removeMember(String projectId, String userId) async {
    final members = _members[projectId];
    if (members == null) {
      return false;
    }
    final before = members.length;
    members.removeWhere((member) => member.userId == userId);
    return members.length != before;
  }

  @override
  Future<User?> findUserByEmail(String email) async {
    final record = await _users.findByEmail(email);
    return record?.user;
  }
}
