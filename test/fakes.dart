import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:task_tracker_oridj/api/api_client.dart';
import 'package:task_tracker_oridj/api/api_error.dart';
import 'package:task_tracker_oridj/auth/token_store.dart';
import 'package:task_tracker_oridj/models/project.dart';
import 'package:task_tracker_oridj/models/project_create.dart';
import 'package:task_tracker_oridj/models/project_member.dart';
import 'package:task_tracker_oridj/models/status.dart';
import 'package:task_tracker_oridj/models/task.dart';
import 'package:task_tracker_oridj/models/task_type.dart';
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

TaskType fakeTaskType({
  String id = 'type-task',
  String projectId = 'project-ARIJ',
  String name = 'Task',
}) {
  return TaskType(id: id, projectId: projectId, name: name);
}

Status fakeStatus({
  String id = 'status-todo',
  String projectId = 'project-ARIJ',
  String name = 'Todo',
  int position = 0,
  bool isDone = false,
}) {
  return Status(
    id: id,
    projectId: projectId,
    name: name,
    position: position,
    isDone: isDone,
  );
}

ProjectMember fakeMember({
  String userId = 'user-1',
  String email = 'ada@example.com',
  String name = 'Ada',
  String role = 'member',
}) {
  return ProjectMember(
    userId: userId,
    email: email,
    name: name,
    role: role,
    joinedAt: DateTime.utc(2026, 11, 15, 12),
  );
}

Task fakeTask({
  String id = 'task-1',
  String projectId = 'project-ARIJ',
  int number = 1,
  String? key,
  TaskKind kind = TaskKind.task,
  String typeId = 'type-task',
  String statusId = 'status-todo',
  String title = 'Task 1',
  String? description,
  TaskPriority priority = TaskPriority.medium,
  String? assigneeId,
  String? reporterId = 'user-1',
  String? parentId,
  DateTime? dueDate,
}) {
  return Task(
    id: id,
    projectId: projectId,
    number: number,
    key: key ?? 'ARIJ-$number',
    kind: kind,
    typeId: typeId,
    statusId: statusId,
    title: title,
    description: description,
    priority: priority,
    assigneeId: assigneeId,
    reporterId: reporterId,
    parentId: parentId,
    dueDate: dueDate,
    createdAt: DateTime.utc(2026, 11, 15, 12),
    updatedAt: DateTime.utc(2026, 11, 15, 12),
  );
}

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
/// Поддерживает auth, projects и task-endpoints этапа 2. Все вызовы
/// регистрируются в [calls].
class FakeApiClient extends ApiClient {
  FakeApiClient({
    this.projectsList = const <Map<String, dynamic>>[],
    this.tasks = const <Map<String, dynamic>>[],
    this.taskTypes = const <Map<String, dynamic>>[],
    this.statuses = const <Map<String, dynamic>>[],
    this.members = const <Map<String, dynamic>>[],
    this.throwOnPost = false,
    this.throwOnPatch = false,
    this.throwOnDelete = false,
    this.postHandler,
    this.patchHandler,
    this.deleteHandler,
    String? token,
  }) : _token = token;

  final List<Map<String, dynamic>> projectsList;
  final List<Map<String, dynamic>> tasks;
  final List<Map<String, dynamic>> taskTypes;
  final List<Map<String, dynamic>> statuses;
  final List<Map<String, dynamic>> members;
  final bool throwOnPost;
  final bool throwOnPatch;
  final bool throwOnDelete;
  final Future<Map<String, dynamic>> Function(
    String path,
    Map<String, dynamic>? body,
  )? postHandler;
  final Future<Map<String, dynamic>> Function(
    String path,
    Map<String, dynamic>? body,
  )? patchHandler;
  final Future<Map<String, dynamic>> Function(String path)? deleteHandler;
  final List<({String path, Map<String, dynamic>? body})> calls = [];

  static const String _tokenPrefix = 'token-';

  String? _token;

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    calls.add((path: path, body: body));
    if (postHandler != null) return postHandler!(path, body);
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
        final taskCreate = RegExp(r'^/api/v1/projects/([^/]+)/tasks$');
        final match = taskCreate.firstMatch(path);
        if (match != null) {
          final projectId = match.group(1)!;
          final number = tasks.length + 1;
          final task = fakeTask(
            id: 'task-created-$number',
            projectId: projectId,
            number: number,
            title: body?['title'] as String? ?? '',
            description: body?['description'] as String?,
            kind: TaskKind.fromWire(body?['kind'] as String?),
            typeId: body?['typeId'] as String? ?? '',
            statusId: statuses.isNotEmpty
                ? statuses.first['id'] as String? ?? 'status-todo'
                : 'status-todo',
            priority: TaskPriority.fromWire(body?['priority'] as String?),
            assigneeId: body?['assigneeId'] as String?,
            parentId: body?['parentId'] as String?,
            dueDate: body?['dueDate'] == null
                ? null
                : DateTime.tryParse(body!['dueDate'] as String),
          );
          return task.toJson();
        }
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
    final taskGet = RegExp(r'^/api/v1/tasks/([^/]+)$');
    final match = taskGet.firstMatch(path);
    if (match != null) {
      final id = match.group(1)!;
      final task = tasks.where((t) => t['id'] == id).firstOrNull;
      if (task == null) {
        throw ApiException(
          code: 'not_found',
          message: 'Не найдено',
          details: null,
        );
      }
      return task;
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
    if (path == '/api/v1/projects') return projectsList;
    final tasksPath = RegExp(r'^/api/v1/projects/([^/]+)/tasks(?:\?.*)?$');
    if (tasksPath.hasMatch(path)) return tasks;
    final typesPath = RegExp(r'^/api/v1/projects/([^/]+)/task-types$');
    if (typesPath.hasMatch(path)) return taskTypes;
    final statusesPath = RegExp(r'^/api/v1/projects/([^/]+)/statuses$');
    if (statusesPath.hasMatch(path)) return statuses;
    final membersPath = RegExp(r'^/api/v1/projects/([^/]+)/members$');
    if (membersPath.hasMatch(path)) return members;
    return const <Map<String, dynamic>>[];
  }

  @override
  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    calls.add((path: path, body: body));
    if (patchHandler != null) return patchHandler!(path, body);
    if (throwOnPatch) {
      throw ApiException(
        code: 'validation_error',
        message: 'Некорректные данные запроса',
        details: null,
      );
    }
    final taskPatch = RegExp(r'^/api/v1/tasks/([^/]+)$');
    final match = taskPatch.firstMatch(path);
    if (match != null) {
      final id = match.group(1)!;
      final existing = tasks.where((t) => t['id'] == id).firstOrNull;
      if (existing == null) {
        throw ApiException(
          code: 'not_found',
          message: 'Не найдено',
          details: null,
        );
      }
      final merged = <String, dynamic>{...existing, ...?body};
      return merged;
    }
    throw ApiException(
      code: 'not_found',
      message: 'Не найдено',
      details: null,
    );
  }

  @override
  Future<Map<String, dynamic>> delete(String path) async {
    calls.add((path: path, body: null));
    if (deleteHandler != null) return deleteHandler!(path);
    if (throwOnDelete) {
      throw ApiException(
        code: 'internal_error',
        message: 'Ошибка сервера',
        details: null,
      );
    }
    final taskDelete = RegExp(r'^/api/v1/tasks/([^/]+)$');
    if (taskDelete.hasMatch(path)) {
      return <String, dynamic>{'ok': true};
    }
    throw ApiException(
      code: 'not_found',
      message: 'Не найдено',
      details: null,
    );
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
