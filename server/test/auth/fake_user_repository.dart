import 'package:arij_server/src/models/user.dart';
import 'package:arij_server/src/repositories/user_repository.dart';

/// In-memory [UserRepository] for route tests.
///
/// Mirrors the `citext` column: lookups ignore email case, like the
/// database unique constraint on the `users` table.
class FakeUserRepository implements UserRepository {
  final Map<String, _FakeRow> _byEmail = <String, _FakeRow>{};
  final Map<String, _FakeRow> _byId = <String, _FakeRow>{};

  int _nextSequence = 1;

  @override
  Future<UserRecord?> findByEmail(String email) async {
    final row = _byEmail[email.toLowerCase()];
    if (row == null) {
      return null;
    }
    return UserRecord(user: row.user, passwordHash: row.passwordHash);
  }

  @override
  Future<User?> findById(String id) async => _byId[id]?.user;

  @override
  Future<UserRecord> create({
    required String email,
    required String name,
    required String passwordHash,
  }) async {
    final id =
        '00000000-0000-4000-8000-${_nextSequence.toString().padLeft(12, '0')}';
    _nextSequence++;
    final now = DateTime.now().toUtc();
    final user = User(
      id: id,
      email: email,
      name: name,
      createdAt: now,
      updatedAt: now,
    );
    final row = _FakeRow(user, passwordHash);
    _byEmail[email.toLowerCase()] = row;
    _byId[id] = row;
    return UserRecord(user: user, passwordHash: passwordHash);
  }
}

final class _FakeRow {
  const _FakeRow(this.user, this.passwordHash);

  final User user;
  final String passwordHash;
}
