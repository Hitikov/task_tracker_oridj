import '../api/api_client.dart';
import '../models/auth_response.dart';
import '../models/project.dart';
import '../models/project_create.dart';
import '../models/user.dart';
import 'token_store.dart';

/// Репозиторий аутентификации и проектов (слой под [ApiClient]).
///
/// Вызовы через REST по OpenAPI; в тестах подменяется фейком.
class AuthRepository {
  AuthRepository({required ApiClient api, required TokenStore tokens})
      : _api = api,
        _tokens = tokens;

  final ApiClient _api;
  final TokenStore _tokens;

  /// Текущий токен из хранилища (или null).
  Future<String?> get token => _tokens.read();

  /// Текущий пользователь (`GET /api/v1/auth/me`).
  ///
  /// null, если токена нет или сервер отклонил его.
  Future<User?> currentUser() async {
    final token = await this.token;
    if (token == null || token.isEmpty) return null;
    final data = await _api.get('/api/v1/auth/me');
    return User.fromJson(data);
  }

  /// Вход (`POST /api/v1/auth/login`) — сохраняет токен.
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final data = await _api.post(
      '/api/v1/auth/login',
      body: {'email': email, 'password': password},
    );
    return _saveSession(AuthResponse.fromJson(data));
  }

  /// Регистрация (`POST /api/v1/auth/register`) — сохраняет токен.
  Future<AuthResponse> register({
    required String email,
    required String password,
    required String name,
  }) async {
    final data = await _api.post(
      '/api/v1/auth/register',
      body: {'email': email, 'password': password, 'name': name},
    );
    return _saveSession(AuthResponse.fromJson(data));
  }

  Future<AuthResponse> _saveSession(AuthResponse response) async {
    await _tokens.write(response.token);
    return response;
  }

  /// Выход — удаляет токен.
  Future<void> logout() => _tokens.delete();

  /// Список проектов пользователя (`GET /api/v1/projects`).
  Future<List<Project>> listProjects() async {
    final data = await _api.getList('/api/v1/projects');
    return [for (final entry in data) Project.fromJson(entry)];
  }

  /// Создать проект (`POST /api/v1/projects`).
  Future<Project> createProject(ProjectCreate create) async {
    final data = await _api.post('/api/v1/projects', body: create.toJson());
    return Project.fromJson(data);
  }
}
