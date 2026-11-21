import 'dart:convert';

import 'package:arij_server/src/middleware/auth_middleware.dart';
import 'package:arij_server/src/models/project.dart';
import 'package:arij_server/src/models/user.dart';
import 'package:arij_server/src/routes/project_routes.dart';
import 'package:arij_server/src/services/project_service.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../auth/fake_user_repository.dart';
import 'fake_project_repository.dart';

void main() {
  const jwtSecret = 'test-jwt-secret-0123456789abcdef';
  const unknownProjectId = '00000000-0000-4000-8000-000000000000';

  late FakeUserRepository userRepository;
  late FakeProjectRepository repository;
  late ProjectService service;
  late ProjectRoutes routes;

  setUp(() {
    userRepository = FakeUserRepository();
    repository = FakeProjectRepository(userRepository);
    service = ProjectService(repository: repository);
    routes = ProjectRoutes(service);
  });

  Future<User> addUser({required String email, String name = 'User'}) async {
    final record = await userRepository.create(
      email: email,
      name: name,
      passwordHash: 'hash',
    );
    return record.user;
  }

  Future<Project> createProjectForOwner(
    String ownerId, {
    required String key,
    String name = 'P',
  }) async {
    return service.createProject(userId: ownerId, key: key, name: name);
  }

  String tokenFor(String userId) => JWT(
    <String, dynamic>{},
    subject: userId,
  ).sign(SecretKey(jwtSecret), algorithm: JWTAlgorithm.HS256);

  /// Sends a request through [handler].
  ///
  /// [user] is placed into the request context under
  /// [authenticatedUserContextKey] (what [authMiddleware] does); [pathParams]
  /// is placed under the shelf_router context key `shelf_router/params`.
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

  group('authMiddleware integration', () {
    test('valid JWT → routes see the user via authenticatedUser', () async {
      final owner = await addUser(email: 'ada@example.com');
      final handler = authMiddleware(
        jwtSecret: jwtSecret,
        repository: userRepository,
      )(routes.list);
      final response = await send(
        handler,
        'GET',
        '/api/v1/projects',
        headers: <String, String>{
          'authorization': 'Bearer ${tokenFor(owner.id)}',
        },
      );
      expect(response.statusCode, 200);
    });

    test('missing token → 401', () async {
      final handler = authMiddleware(
        jwtSecret: jwtSecret,
        repository: userRepository,
      )(routes.list);
      final response = await send(handler, 'GET', '/api/v1/projects');
      expect(response.statusCode, 401);
      expect(errorOf(await json(response))['code'], 'unauthorized');
    });
  });

  group('GET /api/v1/projects (list)', () {
    test('owner/member see projects with member roles', () async {
      final owner = await addUser(email: 'ada@example.com');
      final member = await addUser(email: 'boris@example.com');
      final outsider = await addUser(email: 'carol@example.com');
      final project = await createProjectForOwner(
        owner.id,
        key: 'R1',
        name: 'P1',
      );
      await service.addMember(
        userId: owner.id,
        projectId: project.id,
        email: member.email,
      );

      final response = await send(
        routes.list,
        'GET',
        '/api/v1/projects',
        user: member,
      );
      expect(response.statusCode, 200);
      final body = await jsonList(response);
      expect(body, hasLength(1));
      final projectJson = body.single as Map<String, dynamic>;
      expect(projectJson['key'], 'R1');
      expect(projectJson['name'], 'P1');

      final outsiderResponse = await send(
        routes.list,
        'GET',
        '/api/v1/projects',
        user: outsider,
      );
      expect(outsiderResponse.statusCode, 200);
      expect(await jsonList(outsiderResponse), isEmpty);
    });

    test('no user in context → 401', () async {
      final response = await send(routes.list, 'GET', '/api/v1/projects');
      expect(response.statusCode, 401);
      expect(errorOf(await json(response))['code'], 'unauthorized');
    });
  });

  group('POST /api/v1/projects (create)', () {
    test('creates a project → 201 with Project JSON', () async {
      final owner = await addUser(email: 'ada@example.com');
      final response = await send(
        routes.create,
        'POST',
        '/api/v1/projects',
        user: owner,
        body: <String, Object?>{'key': 'R2', 'name': 'P2', 'description': 'd'},
      );
      expect(response.statusCode, 201);
      final project = await json(response);
      expect(
        project.keys,
        unorderedEquals(<String>[
          'id',
          'key',
          'name',
          'description',
          'ownerId',
          'createdAt',
          'updatedAt',
        ]),
      );
      expect(project['key'], 'R2');
      expect(project['name'], 'P2');
      expect(project['description'], 'd');
      expect(project['ownerId'], owner.id);
    });

    test('lowercase key is uppercased', () async {
      final owner = await addUser(email: 'ada@example.com');
      final response = await send(
        routes.create,
        'POST',
        '/api/v1/projects',
        user: owner,
        body: const <String, Object?>{'key': 'r2', 'name': 'P2'},
      );
      expect(response.statusCode, 201);
      expect((await json(response))['key'], 'R2');
    });

    test('missing key → 400 validation_error field=key', () async {
      final owner = await addUser(email: 'ada@example.com');
      final response = await send(
        routes.create,
        'POST',
        '/api/v1/projects',
        user: owner,
        body: const <String, Object?>{'name': 'P2'},
      );
      expect(response.statusCode, 400);
      final error = errorOf(await json(response));
      expect(error['code'], 'validation_error');
      expect(error['details'], <String, Object?>{'field': 'key'});
    });

    test('invalid key → 400 validation_error', () async {
      final owner = await addUser(email: 'ada@example.com');
      final response = await send(
        routes.create,
        'POST',
        '/api/v1/projects',
        user: owner,
        body: const <String, Object?>{'key': 'a', 'name': 'P2'},
      );
      expect(response.statusCode, 400);
      expect(errorOf(await json(response))['code'], 'validation_error');
    });

    test('duplicate key → 409 project_key_taken', () async {
      final owner = await addUser(email: 'ada@example.com');
      final first = await send(
        routes.create,
        'POST',
        '/api/v1/projects',
        user: owner,
        body: const <String, Object?>{'key': 'DUP', 'name': 'One'},
      );
      expect(first.statusCode, 201);
      final second = await send(
        routes.create,
        'POST',
        '/api/v1/projects',
        user: owner,
        body: const <String, Object?>{'key': 'dup', 'name': 'Two'},
      );
      expect(second.statusCode, 409);
      final error = errorOf(await json(second));
      expect(error['code'], 'project_key_taken');
      expect(error['details'], const <String, Object?>{'field': 'key'});
    });

    test('no user in context → 401', () async {
      final response = await send(
        routes.create,
        'POST',
        '/api/v1/projects',
        body: const <String, Object?>{'key': 'R2', 'name': 'P2'},
      );
      expect(response.statusCode, 401);
      expect(errorOf(await json(response))['code'], 'unauthorized');
    });
  });

  group('GET /api/v1/projects/{id} (getById)', () {
    test('owner → 200 project', () async {
      final owner = await addUser(email: 'ada@example.com');
      final project = await createProjectForOwner(
        owner.id,
        key: 'R3',
        name: 'P3',
      );
      final response = await send(
        routes.getById,
        'GET',
        '/api/v1/projects/${project.id}',
        user: owner,
        pathParams: <String, String>{'id': project.id},
      );
      expect(response.statusCode, 200);
      final body = await json(response);
      expect(body['id'], project.id);
      expect(body['key'], 'R3');
      expect(body['ownerId'], owner.id);
    });

    test('member → 200 project', () async {
      final owner = await addUser(email: 'ada@example.com');
      final member = await addUser(email: 'boris@example.com');
      final project = await createProjectForOwner(owner.id, key: 'R4');
      await service.addMember(
        userId: owner.id,
        projectId: project.id,
        email: member.email,
      );
      final response = await send(
        routes.getById,
        'GET',
        '/api/v1/projects/${project.id}',
        user: member,
        pathParams: <String, String>{'id': project.id},
      );
      expect(response.statusCode, 200);
    });

    test('non-member → 403', () async {
      final owner = await addUser(email: 'ada@example.com');
      final outsider = await addUser(email: 'boris@example.com');
      final project = await createProjectForOwner(owner.id, key: 'R5');
      final response = await send(
        routes.getById,
        'GET',
        '/api/v1/projects/${project.id}',
        user: outsider,
        pathParams: <String, String>{'id': project.id},
      );
      expect(response.statusCode, 403);
      final error = errorOf(await json(response));
      expect(error['code'], 'forbidden');
      expect(error['details'], const <String, Object?>{
        'requiredRole': 'owner',
      });
    });

    test('unknown id → 404 project_not_found', () async {
      final owner = await addUser(email: 'ada@example.com');
      final response = await send(
        routes.getById,
        'GET',
        '/api/v1/projects/$unknownProjectId',
        user: owner,
        pathParams: <String, String>{'id': unknownProjectId},
      );
      expect(response.statusCode, 404);
      final error = errorOf(await json(response));
      expect(error['code'], 'project_not_found');
      expect(error['details'], <String, Object?>{
        'resource': 'project',
        'id': unknownProjectId,
      });
    });
  });

  group('PATCH /api/v1/projects/{id} (update)', () {
    test('owner renames → 200 updated project', () async {
      final owner = await addUser(email: 'ada@example.com');
      final project = await createProjectForOwner(
        owner.id,
        key: 'R6',
        name: 'Old',
      );
      final response = await send(
        routes.update,
        'PATCH',
        '/api/v1/projects/${project.id}',
        user: owner,
        pathParams: <String, String>{'id': project.id},
        body: const <String, Object?>{'name': 'New Name'},
      );
      expect(response.statusCode, 200);
      expect((await json(response))['name'], 'New Name');
      expect((await repository.findById(project.id))?.name, 'New Name');
    });

    test('member → 403', () async {
      final owner = await addUser(email: 'ada@example.com');
      final member = await addUser(email: 'boris@example.com');
      final project = await createProjectForOwner(owner.id, key: 'R7');
      await service.addMember(
        userId: owner.id,
        projectId: project.id,
        email: member.email,
      );
      final response = await send(
        routes.update,
        'PATCH',
        '/api/v1/projects/${project.id}',
        user: member,
        pathParams: <String, String>{'id': project.id},
        body: const <String, Object?>{'name': 'X'},
      );
      expect(response.statusCode, 403);
      expect(errorOf(await json(response))['code'], 'forbidden');
    });

    test('unknown id → 404 project_not_found', () async {
      final owner = await addUser(email: 'ada@example.com');
      final response = await send(
        routes.update,
        'PATCH',
        '/api/v1/projects/$unknownProjectId',
        user: owner,
        pathParams: <String, String>{'id': unknownProjectId},
        body: const <String, Object?>{'name': 'X'},
      );
      expect(response.statusCode, 404);
      expect(errorOf(await json(response))['code'], 'project_not_found');
    });

    test('empty patch {} → 400 validation_error', () async {
      final owner = await addUser(email: 'ada@example.com');
      final project = await createProjectForOwner(owner.id, key: 'R8');
      final response = await send(
        routes.update,
        'PATCH',
        '/api/v1/projects/${project.id}',
        user: owner,
        pathParams: <String, String>{'id': project.id},
        body: const <String, Object?>{},
      );
      expect(response.statusCode, 400);
      expect(errorOf(await json(response))['code'], 'validation_error');
    });

    test('attempt to change key → 400 validation_error field=key', () async {
      final owner = await addUser(email: 'ada@example.com');
      final project = await createProjectForOwner(owner.id, key: 'R9');
      final response = await send(
        routes.update,
        'PATCH',
        '/api/v1/projects/${project.id}',
        user: owner,
        pathParams: <String, String>{'id': project.id},
        body: const <String, Object?>{'key': 'NEWKEY'},
      );
      expect(response.statusCode, 400);
      final error = errorOf(await json(response));
      expect(error['code'], 'validation_error');
      expect(error['details'], <String, Object?>{'field': 'key'});
    });

    test('invalid name → 400 validation_error field=name', () async {
      final owner = await addUser(email: 'ada@example.com');
      final project = await createProjectForOwner(owner.id, key: 'R10');
      final response = await send(
        routes.update,
        'PATCH',
        '/api/v1/projects/${project.id}',
        user: owner,
        pathParams: <String, String>{'id': project.id},
        body: const <String, Object?>{'name': ''},
      );
      expect(response.statusCode, 400);
      final error = errorOf(await json(response));
      expect(error['code'], 'validation_error');
      expect(error['details'], <String, Object?>{'field': 'name'});
    });
  });

  group('DELETE /api/v1/projects/{id} (delete)', () {
    test('owner → 204 and project is gone', () async {
      final owner = await addUser(email: 'ada@example.com');
      final project = await createProjectForOwner(owner.id, key: 'R11');
      final response = await send(
        routes.delete,
        'DELETE',
        '/api/v1/projects/${project.id}',
        user: owner,
        pathParams: <String, String>{'id': project.id},
      );
      expect(response.statusCode, 204);
      expect(await repository.findById(project.id), isNull);
    });

    test('member → 403', () async {
      final owner = await addUser(email: 'ada@example.com');
      final member = await addUser(email: 'boris@example.com');
      final project = await createProjectForOwner(owner.id, key: 'R12');
      await service.addMember(
        userId: owner.id,
        projectId: project.id,
        email: member.email,
      );
      final response = await send(
        routes.delete,
        'DELETE',
        '/api/v1/projects/${project.id}',
        user: member,
        pathParams: <String, String>{'id': project.id},
      );
      expect(response.statusCode, 403);
      expect(errorOf(await json(response))['code'], 'forbidden');
    });

    test('unknown id → 404 project_not_found', () async {
      final owner = await addUser(email: 'ada@example.com');
      final response = await send(
        routes.delete,
        'DELETE',
        '/api/v1/projects/$unknownProjectId',
        user: owner,
        pathParams: <String, String>{'id': unknownProjectId},
      );
      expect(response.statusCode, 404);
      expect(errorOf(await json(response))['code'], 'project_not_found');
    });
  });

  group('GET /api/v1/projects/{id}/members (listMembers)', () {
    test('owner/member see members with roles', () async {
      final owner = await addUser(email: 'ada@example.com');
      final member = await addUser(
        name: 'Иван Петров',
        email: 'boris@example.com',
      );
      final project = await createProjectForOwner(owner.id, key: 'R13');
      await service.addMember(
        userId: owner.id,
        projectId: project.id,
        email: member.email,
      );

      final response = await send(
        routes.listMembers,
        'GET',
        '/api/v1/projects/${project.id}/members',
        user: member,
        pathParams: <String, String>{'id': project.id},
      );
      expect(response.statusCode, 200);
      final List<dynamic> body = await jsonList(response);
      expect(body, hasLength(2));
      final List<String> roles = <String>[
        for (final m in body) (m as Map<String, dynamic>)['role'] as String,
      ];
      expect(roles.toSet(), <String>{'owner', 'member'});
      expect(
        (body.first as Map<String, dynamic>).keys,
        unorderedEquals(<String>[
          'userId',
          'email',
          'name',
          'role',
          'joinedAt',
        ]),
      );
    });

    test('non-member → 403', () async {
      final owner = await addUser(email: 'ada@example.com');
      final outsider = await addUser(email: 'boris@example.com');
      final project = await createProjectForOwner(owner.id, key: 'R14');
      final response = await send(
        routes.listMembers,
        'GET',
        '/api/v1/projects/${project.id}/members',
        user: outsider,
        pathParams: <String, String>{'id': project.id},
      );
      expect(response.statusCode, 403);
      expect(errorOf(await json(response))['code'], 'forbidden');
    });

    test('unknown id → 404 project_not_found', () async {
      final owner = await addUser(email: 'ada@example.com');
      final response = await send(
        routes.listMembers,
        'GET',
        '/api/v1/projects/$unknownProjectId/members',
        user: owner,
        pathParams: <String, String>{'id': unknownProjectId},
      );
      expect(response.statusCode, 404);
      expect(errorOf(await json(response))['code'], 'project_not_found');
    });
  });

  group('POST /api/v1/projects/{id}/members (addMember)', () {
    test('owner adds a member → 201 ProjectMember', () async {
      final owner = await addUser(email: 'ada@example.com');
      final member = await addUser(
        name: 'Иван Петров',
        email: 'boris@example.com',
      );
      final project = await createProjectForOwner(owner.id, key: 'R15');
      final response = await send(
        routes.addMember,
        'POST',
        '/api/v1/projects/${project.id}/members',
        user: owner,
        pathParams: <String, String>{'id': project.id},
        body: const <String, Object?>{'email': 'boris@example.com'},
      );
      expect(response.statusCode, 201);
      final added = await json(response);
      expect(added['userId'], member.id);
      expect(added['email'], 'boris@example.com');
      expect(added['name'], 'Иван Петров');
      expect(added['role'], 'member');
    });

    test('owner explicitly passes role=member → 201', () async {
      final owner = await addUser(email: 'ada@example.com');
      final member = await addUser(email: 'boris@example.com');
      final project = await createProjectForOwner(owner.id, key: 'R16');
      final response = await send(
        routes.addMember,
        'POST',
        '/api/v1/projects/${project.id}/members',
        user: owner,
        pathParams: <String, String>{'id': project.id},
        body: const <String, Object?>{
          'email': 'boris@example.com',
          'role': 'member',
        },
      );
      expect(response.statusCode, 201);
      expect((await json(response))['userId'], member.id);
    });

    test('member already in the project → 409 member_exists', () async {
      final owner = await addUser(email: 'ada@example.com');
      final member = await addUser(email: 'boris@example.com');
      final project = await createProjectForOwner(owner.id, key: 'R17');
      await service.addMember(
        userId: owner.id,
        projectId: project.id,
        email: member.email,
      );
      final response = await send(
        routes.addMember,
        'POST',
        '/api/v1/projects/${project.id}/members',
        user: owner,
        pathParams: <String, String>{'id': project.id},
        body: const <String, Object?>{'email': 'boris@example.com'},
      );
      expect(response.statusCode, 409);
      final error = errorOf(await json(response));
      expect(error['code'], 'member_exists');
      expect(error['details'], <String, Object?>{'userId': member.id});
    });

    test('unknown email → 404 user_not_found', () async {
      final owner = await addUser(email: 'ada@example.com');
      final project = await createProjectForOwner(owner.id, key: 'R18');
      final response = await send(
        routes.addMember,
        'POST',
        '/api/v1/projects/${project.id}/members',
        user: owner,
        pathParams: <String, String>{'id': project.id},
        body: const <String, Object?>{'email': 'ghost@example.com'},
      );
      expect(response.statusCode, 404);
      final error = errorOf(await json(response));
      expect(error['code'], 'user_not_found');
      expect(error['details'], <String, Object?>{
        'field': 'email',
        'email': 'ghost@example.com',
      });
    });

    test('role=owner → 400 validation_error field=role', () async {
      final owner = await addUser(email: 'ada@example.com');
      final project = await createProjectForOwner(owner.id, key: 'R19');
      final response = await send(
        routes.addMember,
        'POST',
        '/api/v1/projects/${project.id}/members',
        user: owner,
        pathParams: <String, String>{'id': project.id},
        body: const <String, Object?>{
          'email': 'second@example.com',
          'role': 'owner',
        },
      );
      expect(response.statusCode, 400);
      final error = errorOf(await json(response));
      expect(error['code'], 'validation_error');
      expect(error['details'], <String, Object?>{'field': 'role'});
    });

    test('member caller → 403', () async {
      final owner = await addUser(email: 'ada@example.com');
      final member = await addUser(email: 'boris@example.com');
      final project = await createProjectForOwner(owner.id, key: 'R20');
      await service.addMember(
        userId: owner.id,
        projectId: project.id,
        email: member.email,
      );
      final response = await send(
        routes.addMember,
        'POST',
        '/api/v1/projects/${project.id}/members',
        user: member,
        pathParams: <String, String>{'id': project.id},
        body: const <String, Object?>{'email': 'carol@example.com'},
      );
      expect(response.statusCode, 403);
      expect(errorOf(await json(response))['code'], 'forbidden');
    });

    test('unknown project → 404 project_not_found', () async {
      final owner = await addUser(email: 'ada@example.com');
      final response = await send(
        routes.addMember,
        'POST',
        '/api/v1/projects/$unknownProjectId/members',
        user: owner,
        pathParams: <String, String>{'id': unknownProjectId},
        body: const <String, Object?>{'email': 'x@example.com'},
      );
      expect(response.statusCode, 404);
      expect(errorOf(await json(response))['code'], 'project_not_found');
    });
  });

  group('DELETE /api/v1/projects/{id}/members/{userId} (removeMember)', () {
    test('owner removes a member → 204', () async {
      final owner = await addUser(email: 'ada@example.com');
      final member = await addUser(email: 'boris@example.com');
      final project = await createProjectForOwner(owner.id, key: 'R21');
      await service.addMember(
        userId: owner.id,
        projectId: project.id,
        email: member.email,
      );
      final response = await send(
        routes.removeMember,
        'DELETE',
        '/api/v1/projects/${project.id}/members/${member.id}',
        user: owner,
        pathParams: <String, String>{'id': project.id, 'userId': member.id},
      );
      expect(response.statusCode, 204);
      final List<String> memberIds = <String>[
        for (final m in await service.listMembers(
          userId: owner.id,
          projectId: project.id,
        ))
          m.userId,
      ];
      expect(memberIds, isNot(contains(member.id)));
    });

    test(
      'owner cannot remove the owner → 409 owner_removal_forbidden',
      () async {
        final owner = await addUser(email: 'ada@example.com');
        final project = await createProjectForOwner(owner.id, key: 'R22');
        final response = await send(
          routes.removeMember,
          'DELETE',
          '/api/v1/projects/${project.id}/members/${owner.id}',
          user: owner,
          pathParams: <String, String>{'id': project.id, 'userId': owner.id},
        );
        expect(response.statusCode, 409);
        expect(
          errorOf(await json(response))['code'],
          'owner_removal_forbidden',
        );
      },
    );

    test('unknown member → 404 member_not_found', () async {
      final owner = await addUser(email: 'ada@example.com');
      final stranger = await addUser(email: 'carol@example.com');
      final project = await createProjectForOwner(owner.id, key: 'R23');
      final response = await send(
        routes.removeMember,
        'DELETE',
        '/api/v1/projects/${project.id}/members/${stranger.id}',
        user: owner,
        pathParams: <String, String>{'id': project.id, 'userId': stranger.id},
      );
      expect(response.statusCode, 404);
      expect(errorOf(await json(response))['code'], 'member_not_found');
    });

    test('member caller → 403', () async {
      final owner = await addUser(email: 'ada@example.com');
      final member = await addUser(email: 'boris@example.com');
      final project = await createProjectForOwner(owner.id, key: 'R24');
      await service.addMember(
        userId: owner.id,
        projectId: project.id,
        email: member.email,
      );
      final response = await send(
        routes.removeMember,
        'DELETE',
        '/api/v1/projects/${project.id}/members/${member.id}',
        user: member,
        pathParams: <String, String>{'id': project.id, 'userId': member.id},
      );
      expect(response.statusCode, 403);
      expect(errorOf(await json(response))['code'], 'forbidden');
    });
  });
}
