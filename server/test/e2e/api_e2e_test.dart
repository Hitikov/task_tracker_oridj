import 'dart:convert';
import 'dart:io';

import 'package:arij_server/arij_server.dart';
import 'package:arij_server/src/db/database.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../db/ensure_migrations.dart';

/// E2E-тесты на живом PostgreSQL через реальный HTTP-хендлер приложения.
///
/// Запросы идут не в фейковые репозитории, а в [buildHandler] с тем же
/// [AppConfig], что и у рабочего сервера: middleware аутентификации, роуты,
/// сервисы, SQL и триггеры БД работают как в production. Внешней сети нет —
/// [Request] собирается вручную и вызывается напрямую.
///
/// Без доступной БД все тесты пропускаются (как и в migrations_integration_test.dart).
/// Переменные окружения DB_*/JWT_SECRET задаёт CI job `backend`.

const String _password = 'correct-horse-battery-staple';

Map<String, String> _environment() => <String, String>{
  'DB_HOST': Platform.environment['DB_HOST'] ?? 'localhost',
  'DB_PORT': Platform.environment['DB_PORT'] ?? '5432',
  'DB_NAME': Platform.environment['DB_NAME'] ?? 'arij_test',
  'DB_USER': Platform.environment['DB_USER'] ?? 'arij',
  'DB_PASSWORD': Platform.environment['DB_PASSWORD'] ?? 'arij_test_password',
  'JWT_SECRET':
      Platform.environment['JWT_SECRET'] ??
      'test-secret-that-is-at-least-32-chars',
};

Future<bool> _databaseAvailable(Map<String, String> environment) async {
  final database = Database(AppConfig.fromEnvironment(environment));
  try {
    await database.open();
    await database.close();
    return true;
  } catch (_) {
    return false;
  }
}

void main() async {
  final environment = _environment();
  final available = await _databaseAvailable(environment);
  final skipReason = available
      ? null
      : 'База недоступна: запустите PostgreSQL и задайте env DB_* / JWT_SECRET';

  // Суффикс делает email и ключи проекта уникальными между прогонами, чтобы
  // тесты можно было запускать повторно на одной и той же БД без ручной чистки.
  final suffix = DateTime.now().microsecondsSinceEpoch.remainder(100000);
  final ownerEmail = 'e2e-owner-$suffix@example.com';
  final outsiderEmail = 'e2e-outsider-$suffix@example.com';
  final projectKey = 'E$suffix';

  late final Database database;
  late final Handler handler;
  late final String ownerToken;
  late final String outsiderToken;
  late final Map<String, dynamic> project;
  late final List<dynamic> statuses;
  late final List<dynamic> types;

  final createdUserIds = <String>[];

  /// Проекты, которые нужно удалить в конце (id → токен владельца).
  final createdProjects = <String, String>{};

  void e2eTest(String name, Future<void> Function() body) {
    test(name, skip: skipReason, body);
  }

  Future<Response> send(
    String method,
    String path, {
    String? token,
    Object? body,
  }) async {
    final headers = <String, String>{};
    if (token != null) {
      headers['authorization'] = 'Bearer $token';
    }
    if (body != null) {
      headers['content-type'] = 'application/json';
    }
    return handler(
      Request(
        method,
        Uri.parse('http://localhost$path'),
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      ),
    );
  }

  Future<Map<String, dynamic>> json(Response response) async =>
      jsonDecode(await response.readAsString()) as Map<String, dynamic>;

  Future<List<dynamic>> jsonList(Response response) async =>
      jsonDecode(await response.readAsString()) as List<dynamic>;

  Map<String, dynamic> errorOf(Map<String, dynamic> body) =>
      body['error'] as Map<String, dynamic>;

  Future<Map<String, dynamic>> register({
    required String email,
    required String name,
  }) async {
    final response = await send(
      'POST',
      '/api/v1/auth/register',
      body: <String, Object?>{
        'email': email,
        'password': _password,
        'name': name,
      },
    );
    expect(response.statusCode, 201);
    final body = await json(response);
    createdUserIds.add((body['user'] as Map<String, dynamic>)['id'] as String);
    return body;
  }

  Future<Map<String, dynamic>> createProject(
    String token, {
    required String key,
    required String name,
  }) async {
    final response = await send(
      'POST',
      '/api/v1/projects',
      token: token,
      body: <String, Object?>{'key': key, 'name': name},
    );
    expect(response.statusCode, 201);
    final created = await json(response);
    createdProjects[created['id'] as String] = token;
    return created;
  }

  String statusId(List<dynamic> list, String name) {
    final found =
        list.firstWhere(
              (item) => (item as Map<String, dynamic>)['name'] == name,
            )
            as Map<String, dynamic>;
    return found['id'] as String;
  }

  String typeId(List<dynamic> list, String name) {
    final found =
        list.firstWhere(
              (item) => (item as Map<String, dynamic>)['name'] == name,
            )
            as Map<String, dynamic>;
    return found['id'] as String;
  }

  Map<String, Object?> taskBody({
    required String title,
    required String kind,
    required String typeId,
    required String statusId,
    String? parentId,
  }) => <String, Object?>{
    'title': title,
    'kind': kind,
    'typeId': typeId,
    'statusId': statusId,
    'priority': 'medium',
    'parentId': ?parentId,
  };

  setUpAll(() async {
    if (!available) {
      return;
    }
    final config = AppConfig.fromEnvironment(environment);
    database = Database(config);
    await database.open();
    await ensureMigrations(database);
    handler = buildHandler(config: config);

    ownerToken =
        (await register(email: ownerEmail, name: 'E2E Owner'))['token']
            as String;
    outsiderToken =
        (await register(email: outsiderEmail, name: 'E2E Outsider'))['token']
            as String;

    project = await createProject(
      ownerToken,
      key: projectKey,
      name: 'E2E Shared',
    );
    final projectId = project['id'] as String;
    statuses = await jsonList(
      await send(
        'GET',
        '/api/v1/projects/$projectId/statuses',
        token: ownerToken,
      ),
    );
    types = await jsonList(
      await send(
        'GET',
        '/api/v1/projects/$projectId/task-types',
        token: ownerToken,
      ),
    );
  });

  tearDownAll(() async {
    if (!available) {
      return;
    }
    try {
      for (final entry in createdProjects.entries) {
        final response = await send(
          'DELETE',
          '/api/v1/projects/${entry.key}',
          token: entry.value,
        );
        expect(
          response.statusCode,
          204,
          reason: 'не удалось удалить проект ${entry.key}',
        );
      }
      // Users API не реализован: созданные тестом пользователи удаляются
      // напрямую. Проекты уже удалены, поэтому ссылок на них нет.
      for (final userId in createdUserIds) {
        await database.query(
          'DELETE FROM users WHERE id = \$1',
          parameters: <Object?>[userId],
        );
      }
    } finally {
      await database.close();
    }
  });

  group('E2E: полный сценарий MVP на живом PostgreSQL', () {
    e2eTest(
      'register → login → project → Epic/Task/Subtask → To Do → In Progress '
      '→ Done → board → delete task → cleanup',
      () async {
        final email = 'e2e-runner-$suffix@example.com';
        final registered = await send(
          'POST',
          '/api/v1/auth/register',
          body: <String, Object?>{
            'email': email,
            'password': _password,
            'name': 'E2E Runner',
          },
        );
        expect(registered.statusCode, 201);
        final registration = await json(registered);
        final runnerId =
            (registration['user'] as Map<String, dynamic>)['id'] as String;
        createdUserIds.add(runnerId);

        final loggedIn = await send(
          'POST',
          '/api/v1/auth/login',
          body: <String, Object?>{'email': email, 'password': _password},
        );
        expect(loggedIn.statusCode, 200);
        final token = (await json(loggedIn))['token'] as String;
        expect(token, isNotEmpty);

        final me = await send('GET', '/api/v1/auth/me', token: token);
        expect(me.statusCode, 200);
        expect((await json(me))['id'], runnerId);

        final flowProject = await createProject(
          token,
          key: 'F$suffix',
          name: 'E2E Flow',
        );
        final projectId = flowProject['id'] as String;
        expect(flowProject['key'], 'F$suffix');
        expect(flowProject['ownerId'], runnerId);

        final flowStatuses = await jsonList(
          await send(
            'GET',
            '/api/v1/projects/$projectId/statuses',
            token: token,
          ),
        );
        final flowTypes = await jsonList(
          await send(
            'GET',
            '/api/v1/projects/$projectId/task-types',
            token: token,
          ),
        );
        expect(
          flowStatuses.map((s) => (s as Map<String, dynamic>)['name']).toList(),
          <String>['To Do', 'In Progress', 'Done'],
        );
        final todoId = statusId(flowStatuses, 'To Do');
        final inProgressId = statusId(flowStatuses, 'In Progress');
        final doneId = statusId(flowStatuses, 'Done');
        final featureId = typeId(flowTypes, 'feature');

        Future<Map<String, dynamic>> createTask({
          required String title,
          required String kind,
          required String statusIdValue,
          String? parentId,
        }) async {
          final response = await send(
            'POST',
            '/api/v1/projects/$projectId/tasks',
            token: token,
            body: taskBody(
              title: title,
              kind: kind,
              typeId: featureId,
              statusId: statusIdValue,
              parentId: parentId,
            ),
          );
          expect(response.statusCode, 201);
          return json(response);
        }

        final epic = await createTask(
          title: 'Epic: MVP',
          kind: 'epic',
          statusIdValue: todoId,
        );
        expect(epic['number'], 1);
        expect(epic['key'], 'F$suffix-1');
        expect(epic['parentId'], isNull);

        final task = await createTask(
          title: 'Task: status flow',
          kind: 'task',
          statusIdValue: todoId,
          parentId: epic['id'] as String,
        );
        expect(task['number'], 2);
        expect(task['parentId'], epic['id']);

        final subtask = await createTask(
          title: 'Subtask: check board',
          kind: 'subtask',
          statusIdValue: todoId,
          parentId: task['id'] as String,
        );
        expect(subtask['number'], 3);
        expect(subtask['parentId'], task['id']);

        final backlog = await jsonList(
          await send('GET', '/api/v1/projects/$projectId/tasks', token: token),
        );
        expect(backlog, hasLength(3));
        expect(
          backlog.map((t) => (t as Map<String, dynamic>)['number']).toList(),
          <int>[1, 2, 3],
        );

        final taskId = task['id'] as String;
        for (final nextStatus in <String>[inProgressId, doneId]) {
          final moved = await send(
            'PATCH',
            '/api/v1/tasks/$taskId/status',
            token: token,
            body: <String, Object?>{'statusId': nextStatus},
          );
          expect(moved.statusCode, 200);
          expect((await json(moved))['statusId'], nextStatus);
        }
        final movedTask = await send(
          'GET',
          '/api/v1/tasks/$taskId',
          token: token,
        );
        expect((await json(movedTask))['statusId'], doneId);

        final board = await jsonList(
          await send('GET', '/api/v1/projects/$projectId/board', token: token),
        );
        expect(board, hasLength(3));
        final columns = <String, List<dynamic>>{
          for (final column in board)
            ((column as Map<String, dynamic>)['status']
                        as Map<String, dynamic>)['name']
                    as String:
                (column['tasks'] as List<dynamic>),
        };
        expect(columns.keys.toList(), <String>['To Do', 'In Progress', 'Done']);
        expect(columns['To Do'], hasLength(2)); // epic + subtask
        expect(columns['Done'], hasLength(1));
        expect((columns['Done']!.single as Map<String, dynamic>)['id'], taskId);

        final deleted = await send(
          'DELETE',
          '/api/v1/tasks/$taskId',
          token: token,
        );
        expect(deleted.statusCode, 204);
        final missing = await send(
          'GET',
          '/api/v1/tasks/$taskId',
          token: token,
        );
        expect(missing.statusCode, 404);
        expect(errorOf(await json(missing))['code'], 'task_not_found');

        final removedProject = await send(
          'DELETE',
          '/api/v1/projects/$projectId',
          token: token,
        );
        expect(removedProject.statusCode, 204);
        createdProjects.remove(projectId);
      },
    );
  });

  group('API: граничные случаи на живом PostgreSQL', () {
    String projectId() => project['id'] as String;
    String todoId() => statusId(statuses, 'To Do');
    String featureId() => typeId(types, 'feature');

    e2eTest('дубликат email → 409 email_taken', () async {
      final duplicate = await send(
        'POST',
        '/api/v1/auth/register',
        body: <String, Object?>{
          'email': ownerEmail.toUpperCase(),
          'password': _password,
          'name': 'Duplicate',
        },
      );
      expect(duplicate.statusCode, 409);
      final error = errorOf(await json(duplicate));
      expect(error['code'], 'email_taken');
      expect(error['details'], <String, Object?>{'field': 'email'});
    });

    e2eTest(
      'неверный пароль и неизвестный email → 401 invalid_credentials',
      () async {
        final wrongPassword = await send(
          'POST',
          '/api/v1/auth/login',
          body: <String, Object?>{
            'email': ownerEmail,
            'password': 'definitely-not-the-password',
          },
        );
        expect(wrongPassword.statusCode, 401);
        expect(
          errorOf(await json(wrongPassword))['code'],
          'invalid_credentials',
        );

        final unknownEmail = await send(
          'POST',
          '/api/v1/auth/login',
          body: <String, Object?>{
            'email': 'e2e-nobody-$suffix@example.com',
            'password': _password,
          },
        );
        expect(unknownEmail.statusCode, 401);
        expect(
          errorOf(await json(unknownEmail))['code'],
          'invalid_credentials',
        );
      },
    );

    e2eTest('чужой проект → 403 forbidden', () async {
      final read = await send(
        'GET',
        '/api/v1/projects/${projectId()}',
        token: outsiderToken,
      );
      expect(read.statusCode, 403);
      expect(errorOf(await json(read))['code'], 'forbidden');

      final write = await send(
        'POST',
        '/api/v1/projects/${projectId()}/tasks',
        token: outsiderToken,
        body: taskBody(
          title: 'Forbidden',
          kind: 'epic',
          typeId: featureId(),
          statusId: todoId(),
        ),
      );
      expect(write.statusCode, 403);
      expect(errorOf(await json(write))['code'], 'forbidden');
    });

    e2eTest('дубль key проекта → 409 project_key_taken', () async {
      final duplicate = await send(
        'POST',
        '/api/v1/projects',
        token: ownerToken,
        body: <String, Object?>{
          'key': projectKey.toLowerCase(),
          'name': 'Duplicate key',
        },
      );
      expect(duplicate.statusCode, 409);
      final error = errorOf(await json(duplicate));
      expect(error['code'], 'project_key_taken');
      expect(error['details'], <String, Object?>{'field': 'key'});
    });

    e2eTest(
      'параллельное создание задач даёт уникальные номера (ретрай)',
      () async {
        final raceProject = await createProject(
          ownerToken,
          key: 'N$suffix',
          name: 'E2E Number Race',
        );
        final raceProjectId = raceProject['id'] as String;
        final raceStatuses = await jsonList(
          await send(
            'GET',
            '/api/v1/projects/$raceProjectId/statuses',
            token: ownerToken,
          ),
        );
        final raceTypes = await jsonList(
          await send(
            'GET',
            '/api/v1/projects/$raceProjectId/task-types',
            token: ownerToken,
          ),
        );
        // Оба запроса читают COALESCE(MAX(number), 0) + 1. Проигравший гонку
        // за UNIQUE (project_id, number) ловит UniqueViolationException и
        // повторяет транзакцию с новым номером (до 5 попыток).
        final created = await Future.wait(<Future<Response>>[
          for (var i = 1; i <= 2; i++)
            send(
              'POST',
              '/api/v1/projects/$raceProjectId/tasks',
              token: ownerToken,
              body: taskBody(
                title: 'Race task $i',
                kind: 'epic',
                typeId: typeId(raceTypes, 'feature'),
                statusId: statusId(raceStatuses, 'To Do'),
              ),
            ),
        ]);
        for (final response in created) {
          expect(response.statusCode, 201);
        }
        final numbers = <int>[
          for (final response in created)
            (await json(response))['number'] as int,
        ]..sort();
        expect(numbers, <int>[1, 2]);
      },
    );

    e2eTest(
      'неверный parent → 400 validation_error, неизвестный → 404',
      () async {
        final epic = await send(
          'POST',
          '/api/v1/projects/${projectId()}/tasks',
          token: ownerToken,
          body: taskBody(
            title: 'Parent root',
            kind: 'epic',
            typeId: featureId(),
            statusId: todoId(),
          ),
        );
        expect(epic.statusCode, 201);
        final epicId = (await json(epic))['id'] as String;

        final badKind = await send(
          'POST',
          '/api/v1/projects/${projectId()}/tasks',
          token: ownerToken,
          body: taskBody(
            title: 'Bad parent kind',
            kind: 'subtask',
            typeId: featureId(),
            statusId: todoId(),
            parentId: epicId,
          ),
        );
        expect(badKind.statusCode, 400);
        final error = errorOf(await json(badKind));
        expect(error['code'], 'validation_error');
        expect(error['details'], <String, Object?>{'field': 'parentId'});

        const unknownTaskId = '00000000-0000-4000-8000-0000000000ff';
        final unknownParent = await send(
          'POST',
          '/api/v1/projects/${projectId()}/tasks',
          token: ownerToken,
          body: taskBody(
            title: 'Unknown parent',
            kind: 'task',
            typeId: featureId(),
            statusId: todoId(),
            parentId: unknownTaskId,
          ),
        );
        expect(unknownParent.statusCode, 404);
        expect(errorOf(await json(unknownParent))['code'], 'task_not_found');
      },
    );

    e2eTest('неверный statusId → 400 validation_error', () async {
      final otherProject = await createProject(
        outsiderToken,
        key: 'S$suffix',
        name: 'E2E Foreign Status',
      );
      final foreignStatuses = await jsonList(
        await send(
          'GET',
          '/api/v1/projects/${otherProject['id']}/statuses',
          token: outsiderToken,
        ),
      );
      final foreignStatusId = statusId(foreignStatuses, 'Done');

      final create = await send(
        'POST',
        '/api/v1/projects/${projectId()}/tasks',
        token: ownerToken,
        body: taskBody(
          title: 'Foreign status',
          kind: 'epic',
          typeId: featureId(),
          statusId: foreignStatusId,
        ),
      );
      expect(create.statusCode, 400);
      expect(errorOf(await json(create))['details'], <String, Object?>{
        'field': 'statusId',
      });

      final created = await send(
        'POST',
        '/api/v1/projects/${projectId()}/tasks',
        token: ownerToken,
        body: taskBody(
          title: 'Status move source',
          kind: 'epic',
          typeId: featureId(),
          statusId: todoId(),
        ),
      );
      expect(created.statusCode, 201);
      final taskId = (await json(created))['id'] as String;
      final move = await send(
        'PATCH',
        '/api/v1/tasks/$taskId/status',
        token: ownerToken,
        body: <String, Object?>{'statusId': foreignStatusId},
      );
      expect(move.statusCode, 400);
      expect(errorOf(await json(move))['details'], <String, Object?>{
        'field': 'statusId',
      });
    });

    e2eTest('404 на неизвестные id проекта и задачи', () async {
      const unknownProjectId = '00000000-0000-4000-8000-0000000000ee';
      const unknownTaskId = '00000000-0000-4000-8000-0000000000dd';

      final project = await send(
        'GET',
        '/api/v1/projects/$unknownProjectId',
        token: ownerToken,
      );
      expect(project.statusCode, 404);
      expect(errorOf(await json(project))['code'], 'project_not_found');

      final task = await send(
        'GET',
        '/api/v1/tasks/$unknownTaskId',
        token: ownerToken,
      );
      expect(task.statusCode, 404);
      expect(errorOf(await json(task))['code'], 'task_not_found');

      final changeStatus = await send(
        'PATCH',
        '/api/v1/tasks/$unknownTaskId/status',
        token: ownerToken,
        body: <String, Object?>{'statusId': todoId()},
      );
      expect(changeStatus.statusCode, 404);
      expect(errorOf(await json(changeStatus))['code'], 'task_not_found');

      final delete = await send(
        'DELETE',
        '/api/v1/tasks/$unknownTaskId',
        token: ownerToken,
      );
      expect(delete.statusCode, 404);
      expect(errorOf(await json(delete))['code'], 'task_not_found');
    });
  });
}
