import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Абстракция над хранилищем токена (удобна для тестов).
abstract class TokenStore {
  /// Текущий токен или null.
  Future<String?> read();

  /// Сохранить токен.
  Future<void> write(String token);

  /// Удалить токен.
  Future<void> delete();
}

/// Реальное хранилище токена — `flutter_secure_storage`.
class FlutterSecureTokenStore implements TokenStore {
  const FlutterSecureTokenStore([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  static const String _tokenKey = 'token';

  @override
  Future<String?> read() => _storage.read(key: _tokenKey);

  @override
  Future<void> write(String token) =>
      _storage.write(key: _tokenKey, value: token);

  @override
  Future<void> delete() => _storage.delete(key: _tokenKey);
}
