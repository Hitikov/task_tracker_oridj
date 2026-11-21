import 'dart:convert';

import 'package:arij_server/src/middleware/auth_middleware.dart';
import 'package:arij_server/src/models/user.dart';
import 'package:arij_server/src/routes/task_routes.dart';
import 'package:arij_server/src/services/task_service.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../auth/fake_user_repository.dart';
import 'fake_task_repository.dart';

void main() {
  const jwtSecret = 'test-jwt-secret-0123456789abcdef';
  const unknownProjectId = '00000000-0000-4000-8000-000000000000';
  const unknownTaskId = '00000000-0000-4000-8000-000000000001';

  late FakeUserRepository userRepository;
  late FakeTaskRepository repository;
  late TaskService service;
  late TaskRoutes routes;

  setUp(() {
    userRepository = FakeUserRepository();
    repository = FakeTaskRepository();
    service = TaskService(repository: repository);
    routes = TaskRoutes(service);
    repository.seedProject(
      id: 'proj-00000000-0000-4000-8000-000000000100',
      key: 'PROJ',
      ownerId: 'user-00000000-0000-4000-8000-000000000200',
      memberIds: <String>['user-00000000-0000-4000-8000-000000000201'],
    );
    repository.seedTaskType(
      id: 'type-00000000-0000-4000-8000-000000000300',
      projectId: 'proj-00000000-0000-4000-8000-000000000100',
      name: 'bug',
    );
    repository.seedStatus(
      id: 'status-00000000-0000-4000-8000-000000000400',
      projectId: 'proj-00000000-0000-4000-8000-000000000100',
      name: 'To Do',
      key: 'todo',
      position: 1,
      isDefault: true,
    );
  });

  const String ownerId = 'user-00000000-0000-4000-8000-000000000200';
  const String memberId = 'user-00000000-0000-4000-8000-000000000201';
  const String outsiderId = 'user-00000000-0000-4000-8000-000000000202';
  const String projectId = 'proj-00000000-0000-4000-8000-000000000100';
  const String typeId = 'type-00000000-0000-4000-8000-000000000300';
  const String statusId = 'status-00000000-0000-4000-8000-000000000400';

  User userFor(String id) => User(
    id: id,
    email: '$id@example.com',
    name: 'User',
    createdAt: DateTime.now().toUtc(),
    updatedAt: DateTime.now().toUtc(),
  );

  Future<User> addUser({required String email, String name = 'User'}) async {
    final record = await userRepository.create(
      email: email,
      name: name,
      passwordHash: 'hash',
    );
    return record.user;
  }

  String tokenFor(String userId) => JWT(
    <String, dynamic>{},
    subject: userId,
  ).sign(SecretKey(jwtSecret), algorithm: JWTAlgorithm.HS256);

  /// Sends a request through [handler].
  ///
  /// [user] is placed into the request context under
  /// [authenticatedUserContextKey]; [pathParams] is placed under the
  /// shelf_router context key `shelf_router/params`.
  Future<Response> send(
    Handler handler,
    String method,
    String path, {
    Object? body,
    Map<String, String>? headers,
    User? user,
    Map<String, String>? pathParams,
  }) async {
    final allHeaders = <String, String>{...?headers};
    if (body != null) {
      allHeaders.putIfAbsent('content-type', () => 'application/json');
    }
    final context = <String, Object>{};
    if (user != null) {
      context[authenticatedUserContextKey] = user;
    }
    if (pathParams != null) {
      context['shelf_router/params'] = pathParams;
    }
    return handler(
      Request(
        method,
        Uri.parse('http://localhost$path'),
        headers: allHeaders,
        body: body == null ? null : (body is String ? body : jsonEncode(body)),
        context: context,
      ),
    );
  }

  Future<Map<String, dynamic>> json(Response response) async {
    return jsonDecode(await response.readAsString()) as Map<String, dynamic>;
  }

  Future<List<dynamic>> jsonList(Response response) async {
    return jsonDecode(await response.readAsString()) as List<dynamic>;
  }

  Map<String, dynamic> errorOf(Map<String, dynamic> body) =>
      body['error'] as Map<String, dynamic>;

  const List<String> taskKeys = <String>[
    'id',
    'projectId',
    'number',
    'key',
    'kind',
    'typeId',
    'statusId',
    'title',
    'description',
    'priority',
    'assigneeId',
    'reporterId',
    'parentId',
    'dueDate',
    'createdAt',
    'updatedAt',
  ];

  Future<String> createTaskBody({
    String kind = 'epic',
    String? parentId,
  }) async {
    final body = <String, Object?>{
      'title': 'Task',
      'kind': kind,
      'typeId': typeId,
      'statusId': statusId,
      'priority': 'medium',
    };
    if (parentId != null) {
      body['parentId'] = parentId;
    }
    return jsonEncode(body);
  }

  group('authMiddleware integration', () {
    test('valid JWT → routes see the user via authenticatedUser', () async {
      final user = await addUser(email: 'ada@example.com');
      repository.seedProject(
        id: 'proj-00000000-0000-4000-8000-000000000101',
        key: 'M1',
        ownerId: user.id,
      );
      final handler = authMiddleware(
        jwtSecret: jwtSecret,
        repository: userRepository,
      )(routes.list);
      final response = await send(
        handler,
        'GET',
        '/api/v1/projects/${'proj-00000000-0000-4000-8000-000000000101'}/tasks',
        pathParams: <String, String>{
          'id': 'proj-00000000-0000-4000-8000-000000000101',
        },
        headers: <String, String>{
          'authorization': 'Bearer ${tokenFor(user.id)}',
        },
      );
      expect(response.statusCode, 200);
    });

    test('missing token → 401', () async {
      final handler = authMiddleware(
        jwtSecret: jwtSecret,
        repository: userRepository,
      )(routes.list);
      final response = await send(
        handler,
        'GET',
        '/api/v1/projects/$projectId/tasks',
      );
      expect(response.statusCode, 401);
      expect(errorOf(await json(response))['code'], 'unauthorized');
    });
  });

  group('POST /api/v1/projects/<id>/tasks (create)', () {
    test('creates an epic → 201 with full Task JSON', () async {
      final owner = userFor(ownerId);
      final response = await send(
        routes.create,
        'POST',
        '/api/v1/projects/$projectId/tasks',
        user: owner,
        pathParams: <String, String>{'id': projectId},
        body: await createTaskBody(kind: 'epic'),
      );
      expect(response.statusCode, 201);
      final task = await json(response);
      expect(task.keys, unorderedEquals(taskKeys));
      expect(task['number'], 1);
      expect(task['key'], 'PROJ-1');
      expect(task['kind'], 'epic');
      expect(task['title'], 'Task');
      expect(task['reporterId'], ownerId);
      expect(task['parentId'], isNull);
    });

    test('second task gets number 2 and key PROJ-2', () async {
      final owner = userFor(ownerId);
      await send(
        routes.create,
        'POST',
        '/api/v1/projects/$projectId/tasks',
        user: owner,
        pathParams: <String, String>{'id': projectId},
        body: await createTaskBody(kind: 'epic'),
      );
      final response = await send(
        routes.create,
        'POST',
        '/api/v1/projects/$projectId/tasks',
        user: owner,
        pathParams: <String, String>{'id': projectId},
        body: await createTaskBody(kind: 'task'),
      );
      expect(response.statusCode, 201);
      final task = await json(response);
      expect(task['number'], 2);
      expect(task['key'], 'PROJ-2');
    });

    test('task under an epic → 201', () async {
      final owner = userFor(ownerId);
      final epic = await send(
        routes.create,
        'POST',
        '/api/v1/projects/$projectId/tasks',
        user: owner,
        pathParams: <String, String>{'id': projectId},
        body: await createTaskBody(kind: 'epic'),
      );
      final epicId = (await json(epic))['id'] as String;
      final response = await send(
        routes.create,
        'POST',
        '/api/v1/projects/$projectId/tasks',
        user: owner,
        pathParams: <String, String>{'id': projectId},
        body: await createTaskBody(kind: 'task', parentId: epicId),
      );
      expect(response.statusCode, 201);
      expect((await json(response))['parentId'], epicId);
    });

    test('subtask under a task → 201', () async {
      final owner = userFor(ownerId);
      final epic = await send(
        routes.create,
        'POST',
        '/api/v1/projects/$projectId/tasks',
        user: owner,
        pathParams: <String, String>{'id': projectId},
        body: await createTaskBody(kind: 'epic'),
      );
      final epicId = (await json(epic))['id'] as String;
      final task = await send(
        routes.create,
        'POST',
        '/api/v1/projects/$projectId/tasks',
        user: owner,
        pathParams: <String, String>{'id': projectId},
        body: await createTaskBody(kind: 'task', parentId: epicId),
      );
      final taskId = (await json(task))['id'] as String;
      final response = await send(
        routes.create,
        'POST',
        '/api/v1/projects/$projectId/tasks',
        user: owner,
        pathParams: <String, String>{'id': projectId},
        body: await createTaskBody(kind: 'subtask', parentId: taskId),
      );
      expect(response.statusCode, 201);
      final subtask = await json(response);
      expect(subtask['kind'], 'subtask');
      expect(subtask['parentId'], taskId);
    });

    test('epic with a parent → 400 validation_error field=parentId', () async {
      final owner = userFor(ownerId);
      final epic = await send(
        routes.create,
        'POST',
        '/api/v1/projects/$projectId/tasks',
        user: owner,
        pathParams: <String, String>{'id': projectId},
        body: await createTaskBody(kind: 'epic'),
      );
      final epicId = (await json(epic))['id'] as String;
      final response = await send(
        routes.create,
        'POST',
        '/api/v1/projects/$projectId/tasks',
        user: owner,
        pathParams: <String, String>{'id': projectId},
        body: await createTaskBody(kind: 'epic', parentId: epicId),
      );
      expect(response.statusCode, 400);
      final error = errorOf(await json(response));
      expect(error['code'], 'validation_error');
      expect(error['details'], <String, Object?>{'field': 'parentId'});
    });

    test(
      'subtask without a parent → 400 validation_error field=parentId',
      () async {
        final owner = userFor(ownerId);
        final response = await send(
          routes.create,
          'POST',
          '/api/v1/projects/$projectId/tasks',
          user: owner,
          pathParams: <String, String>{'id': projectId},
          body: await createTaskBody(kind: 'subtask'),
        );
        expect(response.statusCode, 400);
        expect(errorOf(await json(response))['details'], <String, Object?>{
          'field': 'parentId',
        });
      },
    );

    test(
      'subtask under an epic → 400 validation_error field=parentId',
      () async {
        final owner = userFor(ownerId);
        final epic = await send(
          routes.create,
          'POST',
          '/api/v1/projects/$projectId/tasks',
          user: owner,
          pathParams: <String, String>{'id': projectId},
          body: await createTaskBody(kind: 'epic'),
        );
        final epicId = (await json(epic))['id'] as String;
        final response = await send(
          routes.create,
          'POST',
          '/api/v1/projects/$projectId/tasks',
          user: owner,
          pathParams: <String, String>{'id': projectId},
          body: await createTaskBody(kind: 'subtask', parentId: epicId),
        );
        expect(response.statusCode, 400);
        expect(errorOf(await json(response))['details'], <String, Object?>{
          'field': 'parentId',
        });
      },
    );

    test('invalid kind → 400 validation_error field=kind', () async {
      final owner = userFor(ownerId);
      final response = await send(
        routes.create,
        'POST',
        '/api/v1/projects/$projectId/tasks',
        user: owner,
        pathParams: <String, String>{'id': projectId},
        body: await createTaskBody(kind: 'work'),
      );
      expect(response.statusCode, 400);
      expect(errorOf(await json(response))['details'], <String, Object?>{
        'field': 'kind',
      });
    });

    test('invalid priority → 400 validation_error field=priority', () async {
      final owner = userFor(ownerId);
      final response = await send(
        routes.create,
        'POST',
        '/api/v1/projects/$projectId/tasks',
        user: owner,
        pathParams: <String, String>{'id': projectId},
        body:
            '{"title":"Task","kind":"task","typeId":"$typeId","statusId":"$statusId","priority":"urgent"}',
      );
      expect(response.statusCode, 400);
      expect(errorOf(await json(response))['details'], <String, Object?>{
        'field': 'priority',
      });
    });

    test('empty title → 400 validation_error field=title', () async {
      final owner = userFor(ownerId);
      final response = await send(
        routes.create,
        'POST',
        '/api/v1/projects/$projectId/tasks',
        user: owner,
        pathParams: <String, String>{'id': projectId},
        body:
            '{"title":"   ","kind":"task","typeId":"$typeId","statusId":"$statusId","priority":"low"}',
      );
      expect(response.statusCode, 400);
      expect(errorOf(await json(response))['details'], <String, Object?>{
        'field': 'title',
      });
    });

    test('type of another project → 400 validation_error field=typeId', () async {
      repository.seedProject(id: 'proj-other', key: 'OTHER', ownerId: ownerId);
      repository.seedTaskType(
        id: 'type-other',
        projectId: 'proj-other',
        name: 'bug',
      );
      final owner = userFor(ownerId);
      final response = await send(
        routes.create,
        'POST',
        '/api/v1/projects/$projectId/tasks',
        user: owner,
        pathParams: <String, String>{'id': projectId},
        body:
            '{"title":"Task","kind":"task","typeId":"type-other","statusId":"$statusId","priority":"low"}',
      );
      expect(response.statusCode, 400);
      expect(errorOf(await json(response))['details'], <String, Object?>{
        'field': 'typeId',
      });
    });

    test('dueDate in the past → 400 validation_error field=dueDate', () async {
      final owner = userFor(ownerId);
      final yesterday = DateTime.now()
          .toUtc()
          .subtract(const Duration(days: 1))
          .toIso8601String();
      final response = await send(
        routes.create,
        'POST',
        '/api/v1/projects/$projectId/tasks',
        user: owner,
        pathParams: <String, String>{'id': projectId},
        body:
            '{"title":"Task","kind":"task","typeId":"$typeId","statusId":"$statusId","priority":"low","dueDate":"$yesterday"}',
      );
      expect(response.statusCode, 400);
      expect(errorOf(await json(response))['details'], <String, Object?>{
        'field': 'dueDate',
      });
    });

    test('invalid dueDate → 400 validation_error field=dueDate', () async {
      final owner = userFor(ownerId);
      final response = await send(
        routes.create,
        'POST',
        '/api/v1/projects/$projectId/tasks',
        user: owner,
        pathParams: <String, String>{'id': projectId},
        body:
            '{"title":"Task","kind":"task","typeId":"$typeId","statusId":"$statusId","priority":"low","dueDate":"not-a-date"}',
      );
      expect(response.statusCode, 400);
      expect(errorOf(await json(response))['details'], <String, Object?>{
        'field': 'dueDate',
      });
    });

    test('unknown project → 404 project_not_found', () async {
      final owner = userFor(ownerId);
      final response = await send(
        routes.create,
        'POST',
        '/api/v1/projects/$unknownProjectId/tasks',
        user: owner,
        pathParams: <String, String>{'id': unknownProjectId},
        body: await createTaskBody(kind: 'epic'),
      );
      expect(response.statusCode, 404);
      final error = errorOf(await json(response));
      expect(error['code'], 'project_not_found');
      expect(error['details'], <String, Object?>{
        'resource': 'project',
        'id': unknownProjectId,
      });
    });

    test('non-member → 403 forbidden', () async {
      final outsider = userFor(outsiderId);
      final response = await send(
        routes.create,
        'POST',
        '/api/v1/projects/$projectId/tasks',
        user: outsider,
        pathParams: <String, String>{'id': projectId},
        body: await createTaskBody(kind: 'epic'),
      );
      expect(response.statusCode, 403);
      expect(errorOf(await json(response))['code'], 'forbidden');
    });

    test('no user in context → 401', () async {
      final response = await send(
        routes.create,
        'POST',
        '/api/v1/projects/$projectId/tasks',
        pathParams: <String, String>{'id': projectId},
        body: await createTaskBody(kind: 'epic'),
      );
      expect(response.statusCode, 401);
      expect(errorOf(await json(response))['code'], 'unauthorized');
    });

    test('invalid JSON body → 400 validation_error', () async {
      final owner = userFor(ownerId);
      final response = await send(
        routes.create,
        'POST',
        '/api/v1/projects/$projectId/tasks',
        user: owner,
        pathParams: <String, String>{'id': projectId},
        body: '{not json',
      );
      expect(response.statusCode, 400);
      expect(errorOf(await json(response))['code'], 'validation_error');
    });

    test('numbering race → 409 task_number_race', () async {
      final raceRepository = FakeTaskRepository(throwNumberRaceOnCreate: true)
        ..seedProject(
          id: projectId,
          key: 'PROJ',
          ownerId: ownerId,
          memberIds: <String>[memberId],
        )
        ..seedTaskType(id: typeId, projectId: projectId, name: 'bug')
        ..seedStatus(
          id: statusId,
          projectId: projectId,
          name: 'To Do',
          key: 'todo',
          position: 1,
          isDefault: true,
        );
      final raceService = TaskService(repository: raceRepository);
      final raceRoutes = TaskRoutes(raceService);
      final owner = userFor(ownerId);
      final response = await send(
        raceRoutes.create,
        'POST',
        '/api/v1/projects/$projectId/tasks',
        user: owner,
        pathParams: <String, String>{'id': projectId},
        body: await createTaskBody(kind: 'epic'),
      );
      expect(response.statusCode, 409);
      final error = errorOf(await json(response));
      expect(error['code'], 'task_number_race');
      expect(error['details'], <String, Object?>{'projectId': projectId});
    });
  });

  group('GET /api/v1/tasks/<id> (getById)', () {
    test('owner → 200 task', () async {
      final owner = userFor(ownerId);
      final created = await send(
        routes.create,
        'POST',
        '/api/v1/projects/$projectId/tasks',
        user: owner,
        pathParams: <String, String>{'id': projectId},
        body: await createTaskBody(kind: 'epic'),
      );
      final taskId = (await json(created))['id'] as String;
      final response = await send(
        routes.getById,
        'GET',
        '/api/v1/tasks/$taskId',
        user: owner,
        pathParams: <String, String>{'id': taskId},
      );
      expect(response.statusCode, 200);
      final task = await json(response);
      expect(task.keys, unorderedEquals(taskKeys));
      expect(task['id'], taskId);
      expect(task['number'], 1);
      expect(task['key'], 'PROJ-1');
    });

    test('member → 200 task', () async {
      final owner = userFor(ownerId);
      final member = userFor(memberId);
      final created = await send(
        routes.create,
        'POST',
        '/api/v1/projects/$projectId/tasks',
        user: owner,
        pathParams: <String, String>{'id': projectId},
        body: await createTaskBody(kind: 'epic'),
      );
      final taskId = (await json(created))['id'] as String;
      final response = await send(
        routes.getById,
        'GET',
        '/api/v1/tasks/$taskId',
        user: member,
        pathParams: <String, String>{'id': taskId},
      );
      expect(response.statusCode, 200);
    });

    test('non-member → 403 forbidden', () async {
      final owner = userFor(ownerId);
      final outsider = userFor(outsiderId);
      final created = await send(
        routes.create,
        'POST',
        '/api/v1/projects/$projectId/tasks',
        user: owner,
        pathParams: <String, String>{'id': projectId},
        body: await createTaskBody(kind: 'epic'),
      );
      final taskId = (await json(created))['id'] as String;
      final response = await send(
        routes.getById,
        'GET',
        '/api/v1/tasks/$taskId',
        user: outsider,
        pathParams: <String, String>{'id': taskId},
      );
      expect(response.statusCode, 403);
      expect(errorOf(await json(response))['code'], 'forbidden');
    });

    test('unknown id → 404 task_not_found', () async {
      final owner = userFor(ownerId);
      final response = await send(
        routes.getById,
        'GET',
        '/api/v1/tasks/$unknownTaskId',
        user: owner,
        pathParams: <String, String>{'id': unknownTaskId},
      );
      expect(response.statusCode, 404);
      final error = errorOf(await json(response));
      expect(error['code'], 'task_not_found');
      expect(error['details'], <String, Object?>{
        'resource': 'task',
        'id': unknownTaskId,
      });
    });

    test('no user in context → 401', () async {
      final response = await send(
        routes.getById,
        'GET',
        '/api/v1/tasks/$unknownTaskId',
        pathParams: <String, String>{'id': unknownTaskId},
      );
      expect(response.statusCode, 401);
    });
  });

  group('PATCH /api/v1/tasks/<id> (update)', () {
    test('owner updates the title → 200 updated task', () async {
      final owner = userFor(ownerId);
      final created = await send(
        routes.create,
        'POST',
        '/api/v1/projects/$projectId/tasks',
        user: owner,
        pathParams: <String, String>{'id': projectId},
        body: await createTaskBody(kind: 'epic'),
      );
      final taskId = (await json(created))['id'] as String;
      final response = await send(
        routes.update,
        'PATCH',
        '/api/v1/tasks/$taskId',
        user: owner,
        pathParams: <String, String>{'id': taskId},
        body: const <String, Object?>{'title': 'New title'},
      );
      expect(response.statusCode, 200);
      final updated = await json(response);
      expect(updated['title'], 'New title');
      expect(updated['number'], 1);
    });

    test('member updates the task → 200', () async {
      final owner = userFor(ownerId);
      final member = userFor(memberId);
      final created = await send(
        routes.create,
        'POST',
        '/api/v1/projects/$projectId/tasks',
        user: owner,
        pathParams: <String, String>{'id': projectId},
        body: await createTaskBody(kind: 'epic'),
      );
      final taskId = (await json(created))['id'] as String;
      final response = await send(
        routes.update,
        'PATCH',
        '/api/v1/tasks/$taskId',
        user: member,
        pathParams: <String, String>{'id': taskId},
        body: const <String, Object?>{'priority': 'high'},
      );
      expect(response.statusCode, 200);
      expect((await json(response))['priority'], 'high');
    });

    test('non-member → 403 forbidden', () async {
      final owner = userFor(ownerId);
      final outsider = userFor(outsiderId);
      final created = await send(
        routes.create,
        'POST',
        '/api/v1/projects/$projectId/tasks',
        user: owner,
        pathParams: <String, String>{'id': projectId},
        body: await createTaskBody(kind: 'epic'),
      );
      final taskId = (await json(created))['id'] as String;
      final response = await send(
        routes.update,
        'PATCH',
        '/api/v1/tasks/$taskId',
        user: outsider,
        pathParams: <String, String>{'id': taskId},
        body: const <String, Object?>{'title': 'X'},
      );
      expect(response.statusCode, 403);
      expect(errorOf(await json(response))['code'], 'forbidden');
    });

    test('unknown id → 404 task_not_found', () async {
      final owner = userFor(ownerId);
      final response = await send(
        routes.update,
        'PATCH',
        '/api/v1/tasks/$unknownTaskId',
        user: owner,
        pathParams: <String, String>{'id': unknownTaskId},
        body: const <String, Object?>{'title': 'X'},
      );
      expect(response.statusCode, 404);
      expect(errorOf(await json(response))['code'], 'task_not_found');
    });

    test('empty patch {} → 400 validation_error', () async {
      final owner = userFor(ownerId);
      final created = await send(
        routes.create,
        'POST',
        '/api/v1/projects/$projectId/tasks',
        user: owner,
        pathParams: <String, String>{'id': projectId},
        body: await createTaskBody(kind: 'epic'),
      );
      final taskId = (await json(created))['id'] as String;
      final response = await send(
        routes.update,
        'PATCH',
        '/api/v1/tasks/$taskId',
        user: owner,
        pathParams: <String, String>{'id': taskId},
        body: const <String, Object?>{},
      );
      expect(response.statusCode, 400);
      expect(errorOf(await json(response))['code'], 'validation_error');
    });

    test('epic with parent → 400 validation_error field=parentId', () async {
      final owner = userFor(ownerId);
      final epic = await send(
        routes.create,
        'POST',
        '/api/v1/projects/$projectId/tasks',
        user: owner,
        pathParams: <String, String>{'id': projectId},
        body: await createTaskBody(kind: 'epic'),
      );
      final epicId = (await json(epic))['id'] as String;
      final task = await send(
        routes.create,
        'POST',
        '/api/v1/projects/$projectId/tasks',
        user: owner,
        pathParams: <String, String>{'id': projectId},
        body: await createTaskBody(kind: 'task', parentId: epicId),
      );
      final taskId = (await json(task))['id'] as String;
      final response = await send(
        routes.update,
        'PATCH',
        '/api/v1/tasks/$taskId',
        user: owner,
        pathParams: <String, String>{'id': taskId},
        body: const <String, Object?>{'kind': 'epic'},
      );
      expect(response.statusCode, 400);
      expect(errorOf(await json(response))['details'], <String, Object?>{
        'field': 'parentId',
      });
    });

    test(
      'subtask parent cleared → 400 validation_error field=parentId',
      () async {
        final owner = userFor(ownerId);
        final epic = await send(
          routes.create,
          'POST',
          '/api/v1/projects/$projectId/tasks',
          user: owner,
          pathParams: <String, String>{'id': projectId},
          body: await createTaskBody(kind: 'epic'),
        );
        final epicId = (await json(epic))['id'] as String;
        final task = await send(
          routes.create,
          'POST',
          '/api/v1/projects/$projectId/tasks',
          user: owner,
          pathParams: <String, String>{'id': projectId},
          body: await createTaskBody(kind: 'task', parentId: epicId),
        );
        final taskId = (await json(task))['id'] as String;
        final subtask = await send(
          routes.create,
          'POST',
          '/api/v1/projects/$projectId/tasks',
          user: owner,
          pathParams: <String, String>{'id': projectId},
          body: await createTaskBody(kind: 'subtask', parentId: taskId),
        );
        final subtaskId = (await json(subtask))['id'] as String;
        final response = await send(
          routes.update,
          'PATCH',
          '/api/v1/tasks/$subtaskId',
          user: owner,
          pathParams: <String, String>{'id': subtaskId},
          body: const <String, Object?>{'parentId': null},
        );
        expect(response.statusCode, 400);
        expect(errorOf(await json(response))['details'], <String, Object?>{
          'field': 'parentId',
        });
      },
    );

    test('dueDate in the past → 400 validation_error field=dueDate', () async {
      final owner = userFor(ownerId);
      final created = await send(
        routes.create,
        'POST',
        '/api/v1/projects/$projectId/tasks',
        user: owner,
        pathParams: <String, String>{'id': projectId},
        body: await createTaskBody(kind: 'task'),
      );
      final taskId = (await json(created))['id'] as String;
      final response = await send(
        routes.update,
        'PATCH',
        '/api/v1/tasks/$taskId',
        user: owner,
        pathParams: <String, String>{'id': taskId},
        body: '{"dueDate":"2000-01-01T00:00:00.000Z"}',
      );
      expect(response.statusCode, 400);
      expect(errorOf(await json(response))['details'], <String, Object?>{
        'field': 'dueDate',
      });
    });
  });

  group('DELETE /api/v1/tasks/<id> (delete)', () {
    test('owner → 204 and the task is gone', () async {
      final owner = userFor(ownerId);
      final created = await send(
        routes.create,
        'POST',
        '/api/v1/projects/$projectId/tasks',
        user: owner,
        pathParams: <String, String>{'id': projectId},
        body: await createTaskBody(kind: 'epic'),
      );
      final taskId = (await json(created))['id'] as String;
      final response = await send(
        routes.delete,
        'DELETE',
        '/api/v1/tasks/$taskId',
        user: owner,
        pathParams: <String, String>{'id': taskId},
      );
      expect(response.statusCode, 204);
      expect(await repository.findTaskById(taskId), isNull);
    });

    test('member → 204 and the task is gone', () async {
      final owner = userFor(ownerId);
      final member = userFor(memberId);
      final created = await send(
        routes.create,
        'POST',
        '/api/v1/projects/$projectId/tasks',
        user: owner,
        pathParams: <String, String>{'id': projectId},
        body: await createTaskBody(kind: 'epic'),
      );
      final taskId = (await json(created))['id'] as String;
      final response = await send(
        routes.delete,
        'DELETE',
        '/api/v1/tasks/$taskId',
        user: member,
        pathParams: <String, String>{'id': taskId},
      );
      expect(response.statusCode, 204);
      expect(await repository.findTaskById(taskId), isNull);
    });

    test('non-member → 403 forbidden', () async {
      final owner = userFor(ownerId);
      final outsider = userFor(outsiderId);
      final created = await send(
        routes.create,
        'POST',
        '/api/v1/projects/$projectId/tasks',
        user: owner,
        pathParams: <String, String>{'id': projectId},
        body: await createTaskBody(kind: 'epic'),
      );
      final taskId = (await json(created))['id'] as String;
      final response = await send(
        routes.delete,
        'DELETE',
        '/api/v1/tasks/$taskId',
        user: outsider,
        pathParams: <String, String>{'id': taskId},
      );
      expect(response.statusCode, 403);
      expect(errorOf(await json(response))['code'], 'forbidden');
    });

    test('unknown id → 404 task_not_found', () async {
      final owner = userFor(ownerId);
      final response = await send(
        routes.delete,
        'DELETE',
        '/api/v1/tasks/$unknownTaskId',
        user: owner,
        pathParams: <String, String>{'id': unknownTaskId},
      );
      expect(response.statusCode, 404);
      expect(errorOf(await json(response))['code'], 'task_not_found');
    });
  });

  group('GET /api/v1/projects/<id>/tasks (list)', () {
    test('returns tasks ordered by number with full JSON', () async {
      final owner = userFor(ownerId);
      final epic = await send(
        routes.create,
        'POST',
        '/api/v1/projects/$projectId/tasks',
        user: owner,
        pathParams: <String, String>{'id': projectId},
        body: await createTaskBody(kind: 'epic'),
      );
      final epicId = (await json(epic))['id'] as String;
      await send(
        routes.create,
        'POST',
        '/api/v1/projects/$projectId/tasks',
        user: owner,
        pathParams: <String, String>{'id': projectId},
        body: await createTaskBody(kind: 'task', parentId: epicId),
      );
      final response = await send(
        routes.list,
        'GET',
        '/api/v1/projects/$projectId/tasks',
        user: owner,
        pathParams: <String, String>{'id': projectId},
      );
      expect(response.statusCode, 200);
      final List<dynamic> body = await jsonList(response);
      expect(body, hasLength(2));
      expect((body.first as Map)['number'], 1);
      expect((body.last as Map)['number'], 2);
      expect((body.first as Map).keys, unorderedEquals(taskKeys));
    });

    test('filters by kind via query parameter', () async {
      final owner = userFor(ownerId);
      final epic = await send(
        routes.create,
        'POST',
        '/api/v1/projects/$projectId/tasks',
        user: owner,
        pathParams: <String, String>{'id': projectId},
        body: await createTaskBody(kind: 'epic'),
      );
      final epicId = (await json(epic))['id'] as String;
      await send(
        routes.create,
        'POST',
        '/api/v1/projects/$projectId/tasks',
        user: owner,
        pathParams: <String, String>{'id': projectId},
        body: await createTaskBody(kind: 'task', parentId: epicId),
      );
      final response = await send(
        routes.list,
        'GET',
        '/api/v1/projects/$projectId/tasks?kind=epic',
        user: owner,
        pathParams: <String, String>{'id': projectId},
      );
      expect(response.statusCode, 200);
      final List<dynamic> body = await jsonList(response);
      expect(body, hasLength(1));
      expect((body.first as Map)['kind'], 'epic');
    });

    test('filters by status, assignee and priority', () async {
      final owner = userFor(ownerId);
      final created = await send(
        routes.create,
        'POST',
        '/api/v1/projects/$projectId/tasks',
        user: owner,
        pathParams: <String, String>{'id': projectId},
        body: await createTaskBody(kind: 'task'),
      );
      final taskId = (await json(created))['id'] as String;
      await service.updateTask(
        userId: ownerId,
        taskId: taskId,
        fields: <String, Object?>{
          'statusId': statusId,
          'assigneeId': memberId,
          'priority': 'high',
        },
      );
      final byStatus = await send(
        routes.list,
        'GET',
        '/api/v1/projects/$projectId/tasks?status=$statusId',
        user: owner,
        pathParams: <String, String>{'id': projectId},
      );
      expect(await jsonList(byStatus), hasLength(1));
      final byAssignee = await send(
        routes.list,
        'GET',
        '/api/v1/projects/$projectId/tasks?assignee=$memberId',
        user: owner,
        pathParams: <String, String>{'id': projectId},
      );
      expect(await jsonList(byAssignee), hasLength(1));
      final byPriority = await send(
        routes.list,
        'GET',
        '/api/v1/projects/$projectId/tasks?priority=high',
        user: owner,
        pathParams: <String, String>{'id': projectId},
      );
      expect(await jsonList(byPriority), hasLength(1));
    });

    test('tasks of another project are not visible', () async {
      final owner = userFor(ownerId);
      repository.seedProject(id: 'proj-other', key: 'OTHER', ownerId: ownerId);
      repository.seedTaskType(
        id: 'type-other',
        projectId: 'proj-other',
        name: 'bug',
      );
      repository.seedStatus(
        id: 'status-other',
        projectId: 'proj-other',
        name: 'To Do',
        key: 'todo',
        position: 1,
        isDefault: true,
      );
      await service.createTask(
        userId: ownerId,
        projectId: 'proj-other',
        title: 'Other',
        kind: 'epic',
        typeId: 'type-other',
        statusId: 'status-other',
        priority: 'low',
      );
      final response = await send(
        routes.list,
        'GET',
        '/api/v1/projects/$projectId/tasks',
        user: owner,
        pathParams: <String, String>{'id': projectId},
      );
      expect(await jsonList(response), isEmpty);
    });

    test('non-member → 403 forbidden', () async {
      final outsider = userFor(outsiderId);
      final response = await send(
        routes.list,
        'GET',
        '/api/v1/projects/$projectId/tasks',
        user: outsider,
        pathParams: <String, String>{'id': projectId},
      );
      expect(response.statusCode, 403);
      expect(errorOf(await json(response))['code'], 'forbidden');
    });

    test('unknown project → 404 project_not_found', () async {
      final owner = userFor(ownerId);
      final response = await send(
        routes.list,
        'GET',
        '/api/v1/projects/$unknownProjectId/tasks',
        user: owner,
        pathParams: <String, String>{'id': unknownProjectId},
      );
      expect(response.statusCode, 404);
      expect(errorOf(await json(response))['code'], 'project_not_found');
    });

    test('no user in context → 401', () async {
      final response = await send(
        routes.list,
        'GET',
        '/api/v1/projects/$projectId/tasks',
      );
      expect(response.statusCode, 401);
    });
  });

  group('GET /api/v1/projects/<id>/task-types (listTypes)', () {
    test('returns task types of the project', () async {
      final owner = userFor(ownerId);
      final response = await send(
        routes.listTypes,
        'GET',
        '/api/v1/projects/$projectId/task-types',
        user: owner,
        pathParams: <String, String>{'id': projectId},
      );
      expect(response.statusCode, 200);
      final List<dynamic> body = await jsonList(response);
      expect(body, hasLength(1));
      expect((body.first as Map)['name'], 'bug');
      expect(
        (body.first as Map).keys,
        unorderedEquals(<String>['id', 'projectId', 'name']),
      );
    });

    test('non-member → 403 forbidden', () async {
      final outsider = userFor(outsiderId);
      final response = await send(
        routes.listTypes,
        'GET',
        '/api/v1/projects/$projectId/task-types',
        user: outsider,
        pathParams: <String, String>{'id': projectId},
      );
      expect(response.statusCode, 403);
    });

    test('unknown project → 404 project_not_found', () async {
      final owner = userFor(ownerId);
      final response = await send(
        routes.listTypes,
        'GET',
        '/api/v1/projects/$unknownProjectId/task-types',
        user: owner,
        pathParams: <String, String>{'id': unknownProjectId},
      );
      expect(response.statusCode, 404);
      expect(errorOf(await json(response))['code'], 'project_not_found');
    });
  });

  group('GET /api/v1/projects/<id>/statuses (listStatuses)', () {
    test('returns statuses of the project ordered by position', () async {
      final owner = userFor(ownerId);
      final response = await send(
        routes.listStatuses,
        'GET',
        '/api/v1/projects/$projectId/statuses',
        user: owner,
        pathParams: <String, String>{'id': projectId},
      );
      expect(response.statusCode, 200);
      final List<dynamic> body = await jsonList(response);
      expect(body, hasLength(1));
      final status = body.first as Map<String, dynamic>;
      expect(status['key'], 'todo');
      expect(status['isDefault'], isTrue);
      expect(
        status.keys,
        unorderedEquals(<String>[
          'id',
          'projectId',
          'name',
          'key',
          'position',
          'isDefault',
        ]),
      );
    });

    test('non-member → 403 forbidden', () async {
      final outsider = userFor(outsiderId);
      final response = await send(
        routes.listStatuses,
        'GET',
        '/api/v1/projects/$projectId/statuses',
        user: outsider,
        pathParams: <String, String>{'id': projectId},
      );
      expect(response.statusCode, 403);
    });

    test('unknown project → 404 project_not_found', () async {
      final owner = userFor(ownerId);
      final response = await send(
        routes.listStatuses,
        'GET',
        '/api/v1/projects/$unknownProjectId/statuses',
        user: owner,
        pathParams: <String, String>{'id': unknownProjectId},
      );
      expect(response.statusCode, 404);
      expect(errorOf(await json(response))['code'], 'project_not_found');
    });
  });
}
