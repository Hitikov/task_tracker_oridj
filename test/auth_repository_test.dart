import 'package:flutter_test/flutter_test.dart';

import 'package:task_tracker_oridj/api/api_error.dart';
import 'package:task_tracker_oridj/auth/auth_repository.dart';
import 'package:task_tracker_oridj/models/project_create.dart';

import 'fakes.dart';

void main() {
  late FakeTokenStore tokens;
  late FakeApiClient api;
  late AuthRepository repository;

  setUp(() {
    tokens = FakeTokenStore();
    api = FakeApiClient();
    repository = AuthRepository(api: api, tokens: tokens);
  });

  group('AuthRepository', () {
    test('login сохраняет токен и возвращает пользователя', () async {
      final response = await repository.login(
        email: 'ada@example.com',
        password: 'secret123',
      );

      expect(response.user.email, 'ada@example.com');
      expect(response.tokenType, 'Bearer');
      expect(response.expiresIn, 86400);
      expect(api.calls.last.path, '/api/v1/auth/login');
      expect(api.calls.last.body, {
        'email': 'ada@example.com',
        'password': 'secret123',
      });
      expect(await tokens.read(), 'token-ada@example.com');
    });

    test('register сохраняет токен', () async {
      final response = await repository.register(
        email: 'ada@example.com',
        password: 'secret123',
        name: 'Ада',
      );

      expect(response.user.name, 'Ада');
      expect(api.calls.first.path, '/api/v1/auth/register');
      expect(api.calls.first.body, {
        'email': 'ada@example.com',
        'password': 'secret123',
        'name': 'Ада',
      });
      expect(await tokens.read(), 'token-ada@example.com');
    });

    test('login пробрасывает ошибку API и не сохраняет токен', () async {
      final api = FakeApiClient(throwOnPost: true);
      final repository = AuthRepository(api: api, tokens: tokens);

      await expectLater(
        repository.login(email: 'ada@example.com', password: 'secret123'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.details,
            'details',
            {'field': 'email'},
          ),
        ),
      );
      expect(await tokens.read(), isNull);
    });

    test('currentUser возвращает null без токена', () async {
      expect(await repository.currentUser(), isNull);
      expect(api.calls, isEmpty);
    });

    test('currentUser возвращает пользователя по токену', () async {
      tokens.storedToken = 'token-ada@example.com';

      final me = await repository.currentUser();

      expect(me, isNotNull);
      expect(me!.email, 'ada@example.com');
      expect(me.id, 'user-1');
      expect(me.createdAt, DateTime.utc(2026, 11, 15, 12));
      expect(api.calls.single.path, '/api/v1/auth/me');
    });

    test('logout удаляет токен', () async {
      tokens.storedToken = 'token-ada@example.com';

      await repository.logout();

      expect(await tokens.read(), isNull);
    });

    test('listProjects разбирает список проектов', () async {
      api = FakeApiClient(projectsList: fakeProjectsList);
      repository = AuthRepository(api: api, tokens: tokens);

      final projects = await repository.listProjects();

      expect(projects, hasLength(2));
      expect(projects[0].key, 'ARIJ');
      expect(projects[0].name, 'Arij MVP');
      expect(projects[0].description, 'Трекер задач');
      expect(projects[0].ownerId, 'user-1');
      expect(projects[0].createdAt, DateTime.utc(2026, 11, 15, 12));
      expect(projects[1].key, 'DEMO');
      expect(projects[1].description, isNull);
      expect(api.calls.single.path, '/api/v1/projects');
    });

    test('createProject отправляет тело и возвращает проект', () async {
      api = FakeApiClient(projectsList: fakeProjectsList);
      repository = AuthRepository(api: api, tokens: tokens);

      final project = await repository.createProject(
        ProjectCreate(key: 'ARIJ', name: 'Arij MVP', description: 'Описание'),
      );

      expect(project.id, 'project-ARIJ');
      expect(project.key, 'ARIJ');
      expect(project.description, 'Описание');
      expect(api.calls.last.path, '/api/v1/projects');
      expect(api.calls.last.body, {
        'key': 'ARIJ',
        'name': 'Arij MVP',
        'description': 'Описание',
      });
    });
  });
}
