import 'dart:convert';

import 'package:arij_server/src/middleware/auth_middleware.dart';
import 'package:arij_server/src/models/user.dart';
import 'package:arij_server/src/routes/board_routes.dart';
import 'package:arij_server/src/services/board_service.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'fake_board_repository.dart';

void main() {
  const projectId = 'proj-1';
  const ownerId = 'user-owner';
  const memberId = 'user-member';
  const outsiderId = 'user-outsider';
  const todoId = 'status-todo';
  const progressId = 'status-progress';
  const doneId = 'status-done';
  const otherProjectId = 'proj-other';
  const otherStatusId = 'status-other';

  late FakeBoardRepository repository;
  late BoardRoutes routes;

  setUp(() {
    repository = FakeBoardRepository()
      ..seedProject(
        id: projectId,
        key: 'PROJ',
        ownerId: ownerId,
        memberIds: <String>[memberId],
      )
      ..seedStatus(
        id: todoId,
        projectId: projectId,
        name: 'To Do',
        key: 'todo',
        position: 0,
        isDefault: true,
      )
      ..seedStatus(
        id: progressId,
        projectId: projectId,
        name: 'In Progress',
        key: 'in_progress',
        position: 1,
        isDefault: false,
      )
      ..seedStatus(
        id: doneId,
        projectId: projectId,
        name: 'Done',
        key: 'done',
        position: 2,
        isDefault: false,
      );
    routes = BoardRoutes(BoardService(repository: repository));
  });

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

  User userFor(String id) => User(
    id: id,
    email: '$id@example.com',
    name: 'User',
    createdAt: DateTime.now().toUtc(),
    updatedAt: DateTime.now().toUtc(),
  );

  /// Sends [request] through [handler], placing [user] in the auth context
  /// and [pathParams] under the shelf_router params key.
  Future<Response> send(
    Handler handler,
    String method,
    String path, {
    Object? body,
    User? user,
    Map<String, String>? pathParams,
  }) async {
    final headers = <String, String>{};
    if (body != null) {
      headers['content-type'] = 'application/json';
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
        headers: headers,
        body: body == null ? null : (body is String ? body : jsonEncode(body)),
        context: context,
      ),
    );
  }

  Future<Map<String, dynamic>> json(Response response) async =>
      jsonDecode(await response.readAsString()) as Map<String, dynamic>;

  Future<List<dynamic>> jsonList(Response response) async =>
      jsonDecode(await response.readAsString()) as List<dynamic>;

  Map<String, dynamic> errorOf(Map<String, dynamic> body) =>
      body['error'] as Map<String, dynamic>;

  String addTask({
    required String id,
    required int number,
    required String statusId,
    String? assigneeId,
    String priority = 'medium',
  }) {
    final task = repository.addTask(
      id: id,
      projectId: projectId,
      number: number,
      statusId: statusId,
      assigneeId: assigneeId,
      priority: priority,
    );
    return task.id;
  }

  group('PATCH /api/v1/tasks/<id>/status (changeStatus)', () {
    test('owner → 200 with the updated task', () async {
      final taskId = addTask(id: 'task-1', number: 1, statusId: todoId);
      final response = await send(
        routes.changeStatus,
        'PATCH',
        '/api/v1/tasks/$taskId/status',
        user: userFor(ownerId),
        pathParams: <String, String>{'id': taskId},
        body: const <String, Object?>{'statusId': progressId},
      );
      expect(response.statusCode, 200);
      final task = await json(response);
      expect(task.keys, unorderedEquals(taskKeys));
      expect(task['id'], taskId);
      expect(task['statusId'], progressId);
      expect(task['key'], 'PROJ-1');
    });

    test('member → 200', () async {
      final taskId = addTask(id: 'task-1', number: 1, statusId: todoId);
      final response = await send(
        routes.changeStatus,
        'PATCH',
        '/api/v1/tasks/$taskId/status',
        user: userFor(memberId),
        pathParams: <String, String>{'id': taskId},
        body: const <String, Object?>{'statusId': doneId},
      );
      expect(response.statusCode, 200);
      expect((await json(response))['statusId'], doneId);
    });

    test(
      'status of another project → 400 validation_error field=statusId',
      () async {
        repository
          ..seedProject(id: otherProjectId, key: 'OTHER', ownerId: ownerId)
          ..seedStatus(
            id: otherStatusId,
            projectId: otherProjectId,
            name: 'To Do',
            key: 'todo',
            position: 0,
            isDefault: true,
          );
        final taskId = addTask(id: 'task-1', number: 1, statusId: todoId);
        final response = await send(
          routes.changeStatus,
          'PATCH',
          '/api/v1/tasks/$taskId/status',
          user: userFor(ownerId),
          pathParams: <String, String>{'id': taskId},
          body: const <String, Object?>{'statusId': otherStatusId},
        );
        expect(response.statusCode, 400);
        final error = errorOf(await json(response));
        expect(error['code'], 'validation_error');
        expect(error['details'], <String, Object?>{'field': 'statusId'});
        expect((await repository.findTaskById(taskId))!.statusId, todoId);
      },
    );

    test('missing statusId → 400 validation_error field=statusId', () async {
      final taskId = addTask(id: 'task-1', number: 1, statusId: todoId);
      final response = await send(
        routes.changeStatus,
        'PATCH',
        '/api/v1/tasks/$taskId/status',
        user: userFor(ownerId),
        pathParams: <String, String>{'id': taskId},
        body: const <String, Object?>{},
      );
      expect(response.statusCode, 400);
      expect(errorOf(await json(response))['details'], <String, Object?>{
        'field': 'statusId',
      });
    });

    test('invalid JSON body → 400 validation_error', () async {
      final taskId = addTask(id: 'task-1', number: 1, statusId: todoId);
      final response = await send(
        routes.changeStatus,
        'PATCH',
        '/api/v1/tasks/$taskId/status',
        user: userFor(ownerId),
        pathParams: <String, String>{'id': taskId},
        body: '{not json',
      );
      expect(response.statusCode, 400);
      expect(errorOf(await json(response))['code'], 'validation_error');
    });

    test('non-member → 403 forbidden', () async {
      final taskId = addTask(id: 'task-1', number: 1, statusId: todoId);
      final response = await send(
        routes.changeStatus,
        'PATCH',
        '/api/v1/tasks/$taskId/status',
        user: userFor(outsiderId),
        pathParams: <String, String>{'id': taskId},
        body: const <String, Object?>{'statusId': doneId},
      );
      expect(response.statusCode, 403);
      expect(errorOf(await json(response))['code'], 'forbidden');
    });

    test('unknown id → 404 task_not_found', () async {
      const taskId = 'missing-task';
      final response = await send(
        routes.changeStatus,
        'PATCH',
        '/api/v1/tasks/$taskId/status',
        user: userFor(ownerId),
        pathParams: <String, String>{'id': taskId},
        body: const <String, Object?>{'statusId': doneId},
      );
      expect(response.statusCode, 404);
      final error = errorOf(await json(response));
      expect(error['code'], 'task_not_found');
      expect(error['details'], <String, Object?>{
        'resource': 'task',
        'id': taskId,
      });
    });

    test('no user in context → 401', () async {
      final response = await send(
        routes.changeStatus,
        'PATCH',
        '/api/v1/tasks/missing-task/status',
        pathParams: <String, String>{'id': 'missing-task'},
        body: const <String, Object?>{'statusId': doneId},
      );
      expect(response.statusCode, 401);
      expect(errorOf(await json(response))['code'], 'unauthorized');
    });
  });

  group('GET /api/v1/projects/<id>/board (getBoard)', () {
    test('owner → 200 columns with grouped tasks', () async {
      addTask(id: 'task-1', number: 1, statusId: todoId, assigneeId: memberId);
      addTask(id: 'task-2', number: 2, statusId: progressId);
      addTask(id: 'task-3', number: 3, statusId: doneId);
      final response = await send(
        routes.getBoard,
        'GET',
        '/api/v1/projects/$projectId/board',
        user: userFor(ownerId),
        pathParams: <String, String>{'id': projectId},
      );
      expect(response.statusCode, 200);
      final List<dynamic> body = await jsonList(response);
      expect(body, hasLength(3));
      final columns = body.cast<Map<String, dynamic>>();
      expect(columns.map((column) => (column['status'] as Map)['id']), <String>[
        todoId,
        progressId,
        doneId,
      ]);
      expect(columns.first.keys, unorderedEquals(<String>['status', 'tasks']));
      expect(columns.first['tasks'], hasLength(1));
      expect(((columns.first['tasks'] as List).first as Map)['id'], 'task-1');
      expect(
        ((columns.first['tasks'] as List).first as Map).keys,
        unorderedEquals(taskKeys),
      );
      expect(columns.last['tasks'], hasLength(1));
    });

    test('member → 200 with empty columns kept', () async {
      final response = await send(
        routes.getBoard,
        'GET',
        '/api/v1/projects/$projectId/board',
        user: userFor(memberId),
        pathParams: <String, String>{'id': projectId},
      );
      expect(response.statusCode, 200);
      final List<dynamic> body = await jsonList(response);
      expect(body, hasLength(3));
      expect(
        body.every(
          (column) =>
              (column as Map)['tasks'] is List &&
              ((column['tasks'] as List).isEmpty),
        ),
        isTrue,
      );
    });

    test('assignee and priority query filters', () async {
      addTask(
        id: 'task-1',
        number: 1,
        statusId: todoId,
        assigneeId: memberId,
        priority: 'high',
      );
      addTask(
        id: 'task-2',
        number: 2,
        statusId: todoId,
        assigneeId: outsiderId,
        priority: 'low',
      );
      final byAssignee = await send(
        routes.getBoard,
        'GET',
        '/api/v1/projects/$projectId/board?assignee=$memberId',
        user: userFor(ownerId),
        pathParams: <String, String>{'id': projectId},
      );
      final assigneeColumns = (await jsonList(
        byAssignee,
      )).cast<Map<String, dynamic>>();
      expect(assigneeColumns.first['tasks'], hasLength(1));
      expect(
        ((assigneeColumns.first['tasks'] as List).first as Map)['id'],
        'task-1',
      );

      final byPriority = await send(
        routes.getBoard,
        'GET',
        '/api/v1/projects/$projectId/board?priority=low',
        user: userFor(ownerId),
        pathParams: <String, String>{'id': projectId},
      );
      final priorityColumns = (await jsonList(
        byPriority,
      )).cast<Map<String, dynamic>>();
      expect(
        ((priorityColumns.first['tasks'] as List).first as Map)['id'],
        'task-2',
      );
    });

    test('non-member → 403 forbidden', () async {
      final response = await send(
        routes.getBoard,
        'GET',
        '/api/v1/projects/$projectId/board',
        user: userFor(outsiderId),
        pathParams: <String, String>{'id': projectId},
      );
      expect(response.statusCode, 403);
      expect(errorOf(await json(response))['code'], 'forbidden');
    });

    test('unknown project → 404 project_not_found', () async {
      const missing = 'missing-project';
      final response = await send(
        routes.getBoard,
        'GET',
        '/api/v1/projects/$missing/board',
        user: userFor(ownerId),
        pathParams: <String, String>{'id': missing},
      );
      expect(response.statusCode, 404);
      final error = errorOf(await json(response));
      expect(error['code'], 'project_not_found');
      expect(error['details'], <String, Object?>{
        'resource': 'project',
        'id': missing,
      });
    });

    test('no user in context → 401', () async {
      final response = await send(
        routes.getBoard,
        'GET',
        '/api/v1/projects/$projectId/board',
        pathParams: <String, String>{'id': projectId},
      );
      expect(response.statusCode, 401);
      expect(errorOf(await json(response))['code'], 'unauthorized');
    });
  });
}
