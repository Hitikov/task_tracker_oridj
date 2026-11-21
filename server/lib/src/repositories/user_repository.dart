import 'package:postgres/postgres.dart';

import '../db/database.dart';
import '../models/user.dart';

/// A `users` row including the password hash.
///
/// The hash exists only in records, never in [User]: consumers of the
/// repository (the auth service) are the only ones that see it.
class UserRecord {
  const UserRecord({required this.user, required this.passwordHash});

  /// The public user model — no hash field.
  final User user;

  /// The Argon2id hash of the password, in the storage format.
  final String passwordHash;
}

/// Domain exception: the email is already registered (HTTP 409 `email_taken`).
class EmailTakenException implements Exception {
  const EmailTakenException();
}

/// SQL access to the `users` table (the only table stage 1 touches).
///
/// Implementations must never return `password_hash` to the API layer —
/// only [UserRecord] carries it, and only the auth service reads records.
abstract interface class UserRepository {
  /// Finds a user by email; returns `null` when nobody is registered.
  ///
  /// The column is `citext` and the `UNIQUE` constraint is
  /// case-insensitive, so the lookup ignores email case, like the real
  /// constraint.
  Future<UserRecord?> findByEmail(String email);

  /// Finds a user by id (the UUID string); returns `null` when absent.
  Future<User?> findById(String id);

  /// Inserts a new user.
  ///
  /// Throws [EmailTakenException] when the email is already registered —
  /// including the race where two concurrent inserts lose the
  /// unique-violation battle.
  Future<UserRecord> create({
    required String email,
    required String name,
    required String passwordHash,
  });
}

/// [UserRepository] over the `users` table via [Database].
class PostgresUserRepository implements UserRepository {
  PostgresUserRepository(this._db);

  final Database _db;

  /// Public user columns only — the hash is read separately, never
  /// selected into the API model.
  static const String _publicColumns =
      'id, email, name, created_at, updated_at';

  /// Maps a `ResultRow` to a plain map of column values for [User.fromMap].
  ///
  /// In text mode the `postgres` package returns UUID columns as
  /// [UndecodedBytes]; the public API needs plain strings. `timestamptz`
  /// values are [DateTime] in both modes.
  static Map<String, dynamic> _columnMap(ResultRow row) {
    return row.toColumnMap().map(
      (key, value) =>
          MapEntry(key, value is UndecodedBytes ? value.asString : value),
    );
  }

  @override
  Future<UserRecord?> findByEmail(String email) async {
    final result = await _db.query(
      'SELECT $_publicColumns, password_hash FROM users WHERE email = \$1',
      parameters: <Object?>[email],
    );
    if (result.isEmpty) {
      return null;
    }
    final map = _columnMap(result.first);
    return UserRecord(
      user: User.fromMap(map),
      passwordHash: map['password_hash'] as String,
    );
  }

  @override
  Future<User?> findById(String id) async {
    final result = await _db.query(
      'SELECT $_publicColumns FROM users WHERE id = \$1',
      parameters: <Object?>[id],
    );
    if (result.isEmpty) {
      return null;
    }
    return User.fromMap(_columnMap(result.first));
  }

  @override
  Future<UserRecord> create({
    required String email,
    required String name,
    required String passwordHash,
  }) async {
    try {
      final result = await _db.query(
        'INSERT INTO users (email, name, password_hash) '
        'VALUES (\$1, \$2, \$3) '
        'RETURNING $_publicColumns, password_hash',
        parameters: <Object?>[email, name, passwordHash],
      );
      final map = _columnMap(result.first);
      return UserRecord(
        user: User.fromMap(map),
        passwordHash: map['password_hash'] as String,
      );
    } on UniqueViolationException {
      // Lost a concurrent-insert race on the UNIQUE constraint.
      throw EmailTakenException();
    }
  }
}
