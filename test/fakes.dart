import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:task_tracker_oridj/api/api_client.dart';
import 'package:task_tracker_oridj/api/api_error.dart';
import 'package:task_tracker_oridj/auth/token_store.dart';
import 'package:task_tracker_oridj/models/project.dart';
import 'package:task_tracker_oridj/models/project_create.dart';
import 'package:task_tracker_oridj/models/user.dart';
import 'package:task_tracker_oridj/state/auth_providers.dart';
import 'package:task_tracker_oridj/state/projects_providers.dart';

/// Статический пользователь для тестовых ответов API.
User fakeUser(String email, {String name = ''}) {
  return User(
    id: 'user-1',
    email: email,
    name: name.isEmpty ? email : name,
    createdAt: DateTime.utc(2026, 11, 15, 12),
    updatedAt: DateTime.utc(2026, 11, 15, 12),
  );
}

/// Фиктивный проект для тестов.
Project fakeProject(String key) {
  return Project(
    id: 'project-$key',
    key: key,
    name: key,
    description: null,
    ownerId: 'user-1',
    createdAt: DateTime(2026, 11, 15, 12),
    updatedAt: DateTime(2026, 11, 15, 12),
  );
}

const List<Map<String, dynamic>> fakeProjectsList = [
  {
    'id': 'project-ARIJ',
    'key': 'ARIJ',
    'name': 'Arij MVP',
    'description': 'Трекер задач',
    'ownerId': 'user-1',
    'createdAt': '2026-11-15T12:00:00.000Z',
    'updatedAt': '2026-11-15T12:00:00.000Z',
  },
  {
    'id': 'project-DEMO',
    'key': 'DEMO',
    'name': 'Демо-проект',
    'description': null,
    'ownerId': 'user-2',
    'createdAt': '2026-11-14T09:30:00.000Z',
    'updatedAt': '2026-11-14T09:30:00.000Z',
  },
];

/// Подменённый [TokenStore] — простая карта в памяти.
class FakeTokenStore implements TokenStore {
  String? storedToken;

  @override
  Future<String?> read() async => storedToken;

  @override
  Future<void> write(String token) async => storedToken = token;

  @override
  Future<void> delete() async => storedToken = null;
}

/// Подменённый [ApiClient] без сети.
///
/// - `post` на `/api/v1/auth/login`, `/api/v1/auth/register` — возвращает
///   карту ответа `AuthResponse`.
/// - `post` на `/api/v1/projects` — возвращает фейковый проект.
/// - `get` на `/api/v1/auth/me` — возвращает пользователя из текущего токена
///   (или `unauthorized`).
/// - `getList` на `/api/v1/projects` — [projectsList].
///
/// Все вызовы регистрируются в [calls].
class FakeApiClient extends ApiClient {
  FakeApiClient({
    this.projectsList = const <Map<String, dynamic>>[],
    this.throwOnPost = false,
    String? token,
  }) : _token = token;

  final List<Map<String, dynamic>> projectsList;
  final bool throwOnPost;
  final List<({String path, Map<String, dynamic>? body})> calls = [];

  static const String _tokenPrefix = 'token-';

  String? _token;

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    calls.add((path: path, body: body));
    if (throwOnPost) {
      throw ApiException(
        code: 'validation_error',
        message: 'Некорректные данные запроса',
        details: {'field': 'email'},
      );
    }
    switch (path) {
      case '/api/v1/auth/login':
      case '/api/v1/auth/register':
        final email = (body?['email'] as String?) ?? '';
        final name = (body?['name'] as String?) ?? email;
        final response = <String, dynamic>{
          'token': 'token-$email',
          'tokenType': 'Bearer',
          'expiresIn': 86400,
          'user': fakeUser(email, name: name).toJson(),
        };
        _token = response['token'] as String;
        return response;
      case '/api/v1/projects':
        return Project(
          id: 'project-${(body?['key'] as String?) ?? ''}',
          key: (body?['key'] as String?) ?? '',
          name: (body?['name'] as String?) ?? '',
          description: body?['description'] as String?,
          ownerId: 'user-1',
          createdAt: DateTime.utc(2026, 11, 15, 12),
          updatedAt: DateTime.utc(2026, 11, 15, 12),
        ).toJson();
      default:
        throw ApiException(
          code: 'not_found',
          message: 'Не найдено',
          details: null,
        );
    }
  }

  @override
  Future<Map<String, dynamic>> get(String path) async {
    calls.add((path: path, body: null));
    if (path == '/api/v1/auth/me') {
      final token = _token;
      if (token == null || !token.startsWith(_tokenPrefix)) {
        throw ApiException(
          code: 'unauthorized',
          message: 'Требуется аутентификация',
          details: null,
        );
      }
      return fakeUser(token.substring(_tokenPrefix.length)).toJson();
    }
    throw ApiException(
      code: 'not_found',
      message: 'Не найдено',
      details: null,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getList(String path) async {
    calls.add((path: path, body: null));
    return projectsList;
  }
}

/// Подменённый [AuthSession] без сети.
class FakeAuthSession extends AuthSession {
  FakeAuthSession({
    this.loginResponder,
    this.registerResponder,
  });

  final FutureOr<User?> Function(String email, String password)? loginResponder;
  final FutureOr<User?> Function(
    String email,
    String name,
    String password,
  )? registerResponder;

  @override
  Future<User?> build() async => null;

  @override
  Future<User?> login({
    required String email,
    required String password,
  }) async {
    state = AsyncValue.loading();
    User? user;
    if (loginResponder != null) {
      user = await loginResponder!(email, password);
    } else {
      user = fakeUser(email);
    }
    if (user == null) {
      state = AsyncValue.error(
        ApiException(
          code: 'invalid_credentials',
          message: 'Неверный email или пароль',
          details: null,
        ),
        StackTrace.current,
      );
      return null;
    }
    state = AsyncValue.data(user);
    return user;
  }

  @override
  Future<User?> register({
    required String email,
    required String password,
    required String name,
  }) async {
    state = AsyncValue.loading();
    User? user;
    if (registerResponder != null) {
      user = await registerResponder!(email, name, password);
    } else {
      user = fakeUser(email);
    }
    // После регистрации пользователь остаётся на экране входа: сюда он
    // попадёт из диалога «Вы зарегистрированы» (см. RegisterPage).
    return user;
  }

  @override
  Future<void> logout() async {
    state = AsyncValue.data(null);
  }
}

/// Подменённый [ProjectsNotifier] без сети.
class FakeProjectsNotifier extends ProjectsNotifier {
  FakeProjectsNotifier({this.initialProjects = const <Project>[]});

  final List<Project> initialProjects;
  final createdProjects = <ProjectCreate>[];

  @override
  Future<List<Project>> build() async => initialProjects;

  @override
  Future<Project> createProject(ProjectCreate create) async {
    createdProjects.add(create);
    final project = fakeProject(create.key);
    state = AsyncValue.data([...initialProjects, project]);
    return project;
  }
}
