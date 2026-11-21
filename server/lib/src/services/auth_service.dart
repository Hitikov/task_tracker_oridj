import 'dart:math';
import 'dart:typed_data';

import 'package:argon2/argon2.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

import '../models/user.dart';
import '../repositories/user_repository.dart';

/// Domain exception of [AuthService]: an input field failed validation.
///
/// The routes layer maps it to `400 validation_error` with the field name in
/// `details`.
class ValidationException implements Exception {
  const ValidationException(this.field);

  /// Name of the invalid field (OpenAPI `details.field`); `null` when the
  /// request itself is not a valid JSON object.
  final String? field;
}

/// Domain exception of [AuthService.login]: the email is unknown or the
/// password is wrong. The routes layer maps both cases to the same
/// `401 invalid_credentials` so the response does not reveal which.
class InvalidCredentialsException implements Exception {
  const InvalidCredentialsException();
}

/// Response body of `POST /api/v1/auth/register` and `POST /api/v1/auth/login`.
class AuthResponse {
  const AuthResponse({
    required this.token,
    required this.user,
    required this.expiresIn,
  });

  /// The signed JWT (HS256), usable as `Authorization: Bearer <token>`.
  final String token;

  /// OpenAPI `AuthResponse.tokenType` — always `Bearer`.
  static const String tokenType = 'Bearer';

  /// Seconds until the token expires.
  final int expiresIn;

  /// The authenticated user.
  final User user;

  /// OpenAPI `AuthResponse` JSON shape.
  Map<String, Object?> toJson() => <String, Object?>{
    'token': token,
    'tokenType': tokenType,
    'expiresIn': expiresIn,
    'user': user.toJson(),
  };
}

/// Auth business rules: registration, login, token issuance, current user.
///
/// The service never returns the password hash: it returns [AuthResponse]
/// or [User], both of which are hash-free.
class AuthService {
  AuthService({
    required this.repository,
    required this.jwtSecret,
    this.tokenTtl = const Duration(hours: 24),
  });

  /// Repository to the `users` table.
  final UserRepository repository;

  /// Secret used to sign JWTs (HS256).
  final String jwtSecret;

  /// Token lifetime — 24 hours in dev (see architecture docs).
  final Duration tokenTtl;

  // --- Validation limits (OpenAPI `AuthRegisterRequest`/`AuthLoginRequest`) ---

  static const int _minPasswordLength = 8;
  static const int _maxPasswordLength = 128;
  static const int _minNameLength = 1;
  static const int _maxNameLength = 100;
  static const int _maxEmailLength = 320;

  static final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  // --- Argon2id password hashing (RFC 9106) ---

  static const String _hashAlgorithm = 'argon2id';
  static const int _hashVersion = Argon2Parameters.ARGON2_VERSION_13; // 19
  static const int _hashMemoryKb = 65536; // 64 MiB
  static const int _hashIterations = 3;
  static const int _hashLanes = 4;
  static const int _hashOutputLength = 32;
  static const int _hashSaltLength = 16;

  static const String _dummyPassword = 'timing-equalization-password';
  static String? _dummyHash;

  // --- JWT ---

  String _issueToken(String userId) {
    return JWT(<String, dynamic>{}, subject: userId).sign(
      SecretKey(jwtSecret),
      algorithm: JWTAlgorithm.HS256,
      expiresIn: tokenTtl,
    );
  }

  AuthResponse _toAuthResponse(User user) {
    return AuthResponse(
      token: _issueToken(user.id),
      user: user,
      expiresIn: tokenTtl.inSeconds,
    );
  }

  /// Registers a new user and returns the issued token + user.
  ///
  /// Validation rules (OpenAPI): email — RFC-ish format, ≤ 320 chars
  /// (case is irrelevant, matches are case-insensitive); password —
  /// 8–128 chars; name — 1–100 chars. Email/name are trimmed.
  Future<AuthResponse> register({
    required String email,
    required String password,
    required String name,
  }) async {
    final normalizedEmail = email.trim();
    final normalizedName = name.trim();

    if (!_emailPattern.hasMatch(normalizedEmail) ||
        normalizedEmail.length > _maxEmailLength) {
      throw const ValidationException('email');
    }
    if (password.length < _minPasswordLength ||
        password.length > _maxPasswordLength) {
      throw const ValidationException('password');
    }
    if (normalizedName.length < _minNameLength ||
        normalizedName.length > _maxNameLength) {
      throw const ValidationException('name');
    }

    final existing = await repository.findByEmail(normalizedEmail);
    if (existing != null) {
      throw EmailTakenException();
    }

    final record = await repository.create(
      email: normalizedEmail,
      name: normalizedName,
      passwordHash: hashPassword(password),
    );
    return _toAuthResponse(record.user);
  }

  /// Verifies the password against the user registered with [email].
  ///
  /// Both an unknown email and a wrong password produce
  /// [InvalidCredentialsException] — the response does not reveal which.
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final record = await repository.findByEmail(email.trim());
    // When the email is unknown, verify against a fixed dummy hash so the
    // timing doesn't leak whether the account exists.
    final passwordValid = verifyPassword(
      record?.passwordHash ?? _dummyHashValue(),
      password,
    );
    if (record == null || !passwordValid) {
      throw const InvalidCredentialsException();
    }
    return _toAuthResponse(record.user);
  }

  String _dummyHashValue() => _dummyHash ??= hashPassword(_dummyPassword);

  // --- Argon2id password hashing ---

  /// Hashes [password] with Argon2id (random salt) and returns the
  /// serialized hash string:
  /// `argon2id$v=19$m=65536,t=3,p=4$<salt-hex>$<hash-hex>`.
  String hashPassword(String password) {
    final salt = _newSalt();
    final output = Uint8List(_hashOutputLength);
    final generator = Argon2BytesGenerator()
      ..init(
        Argon2Parameters(
          Argon2Parameters.ARGON2_id,
          salt,
          iterations: _hashIterations,
          memory: _hashMemoryKb,
          lanes: _hashLanes,
        ),
      );
    generator.generateBytesFromString(password, output);
    return _encodeHash(salt, output);
  }

  /// Verifies [password] against a hash string produced by [hashPassword].
  bool verifyPassword(String encodedHash, String password) {
    final parts = encodedHash.split('\$');
    if (parts.length != 5 ||
        parts[0] != _hashAlgorithm ||
        parts[1] != 'v=$_hashVersion') {
      return false;
    }
    final salt = _tryFromHex(parts[3]);
    final output = _tryFromHex(parts[4]);
    if (salt == null || output == null) {
      return false;
    }

    var memory = 0;
    var iterations = 0;
    var lanes = 0;
    for (final token in parts[2].split(',')) {
      final entry = token.split('=');
      if (entry.length != 2) {
        return false;
      }
      final value = int.tryParse(entry[1]);
      if (value == null) {
        return false;
      }
      switch (entry[0]) {
        case 'm':
          memory = value;
        case 't':
          iterations = value;
        case 'p':
          lanes = value;
        default:
          return false;
      }
    }
    if (lanes < 1 || memory < 2 * lanes || iterations < 1) {
      return false;
    }

    final generator = Argon2BytesGenerator()
      ..init(
        Argon2Parameters(
          Argon2Parameters.ARGON2_id,
          salt,
          iterations: iterations,
          memory: memory,
          lanes: lanes,
        ),
      );
    final computed = Uint8List(_hashOutputLength);
    generator.generateBytesFromString(password, computed);
    return _constantTimeEquals(computed, output);
  }

  static String _encodeHash(Uint8List salt, Uint8List output) {
    return '$_hashAlgorithm\$v=$_hashVersion\$'
        'm=$_hashMemoryKb,t=$_hashIterations,p=$_hashLanes\$'
        '${_toHex(salt)}\$${_toHex(output)}';
  }

  static String _toHex(List<int> bytes) {
    final buffer = StringBuffer();
    for (final byte in bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  static Uint8List? _tryFromHex(String hex) {
    if (hex.isEmpty || hex.length.isOdd) {
      return null;
    }
    final bytes = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < bytes.length; i++) {
      final byte = int.tryParse(hex.substring(i * 2, i * 2 + 2), radix: 16);
      if (byte == null) {
        return null;
      }
      bytes[i] = byte;
    }
    return bytes;
  }

  static Uint8List _newSalt() {
    final random = Random.secure();
    return Uint8List.fromList([
      for (var i = 0; i < _hashSaltLength; i++) random.nextInt(256),
    ]);
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) {
      return false;
    }
    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a[i] ^ b[i];
    }
    return difference == 0;
  }
}
