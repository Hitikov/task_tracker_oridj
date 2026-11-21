import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:task_tracker_oridj/auth/auth_repository.dart';
import 'package:task_tracker_oridj/models/project_create.dart';
import 'package:task_tracker_oridj/state/auth_providers.dart';
import 'package:task_tracker_oridj/state/projects_providers.dart';

import 'fakes.dart';

ProviderContainer _container({
  AuthRepository? repository,
  ProjectsNotifier? projectsNotifier,
}) {
  return ProviderContainer(
    overrides: [
      if (repository != null)
        authRepositoryProvider.overrideWith((ref) => repository),
      if (projectsNotifier != null)
        projectsProvider.overrideWith(() => projectsNotifier),
    ],
  );
}

void main() {
  group('AuthSession', () {
    test('build возвращает null без токена', () async {
      final tokens = FakeTokenStore();
      final repository = AuthRepository(api: FakeApiClient(), tokens: tokens);
      final container = _container(repository: repository);
      addTearDown(container.dispose);

      final notifier = container.read(authSessionProvider.notifier);

      expect(await notifier.build(), isNull);
      expect(notifier.user, isNull);
    });

    test('build читает текущего пользователя из токена', () async {
      final tokens = FakeTokenStore()..storedToken = 'token-ada@example.com';
      final api = FakeApiClient(token: 'token-ada@example.com');
      final repository = AuthRepository(api: api, tokens: tokens);
      final container = _container(repository: repository);
      addTearDown(container.dispose);

      final notifier = container.read(authSessionProvider.notifier);
      final user = await notifier.build();

      expect(user?.email, 'ada@example.com');
      expect(notifier.user, isNotNull);
    });

    test('login открывает сессию и сохраняет токен', () async {
      final tokens = FakeTokenStore();
      final api = FakeApiClient();
      final repository = AuthRepository(api: api, tokens: tokens);
      final container = _container(repository: repository);
      addTearDown(container.dispose);

      final notifier = container.read(authSessionProvider.notifier);
      final user = await notifier.login(
        email: 'ada@example.com',
        password: 'secret123',
      );

      expect(user, isNotNull);
      expect(notifier.user, user);
      expect(notifier.user!.email, 'ada@example.com');
      expect(await tokens.read(), isNotEmpty);
    });

    test('logout сбрасывает сессию', () async {
      final tokens = FakeTokenStore();
      final repository = AuthRepository(api: FakeApiClient(), tokens: tokens);
      final container = _container(repository: repository);
      addTearDown(container.dispose);

      final notifier = container.read(authSessionProvider.notifier);
      await notifier.login(email: 'ada@example.com', password: 'secret123');
      expect(notifier.user, isNotNull);

      await notifier.logout();

      expect(notifier.user, isNull);
      expect(await tokens.read(), isNull);
    });
  });

  group('ProjectsNotifier', () {
    test('build возвращает список проектов', () async {
      final container = _container(
        projectsNotifier: FakeProjectsNotifier(initialProjects: [
          fakeProject('ARIJ'),
        ]),
      );
      addTearDown(container.dispose);

      final notifier = container.read(projectsProvider.notifier);
      final projects = await notifier.build();

      expect(projects, hasLength(1));
      expect(projects.single.key, 'ARIJ');
    });

    test('createProject добавляет проект в список', () async {
      final notifier = FakeProjectsNotifier();
      final container = _container(projectsNotifier: notifier);
      addTearDown(container.dispose);

      final providerNotifier = container.read(projectsProvider.notifier);
      // Инициализируем notifier через провайдер, чтобы состояние было готово.
      await providerNotifier.build();

      final project = await providerNotifier.createProject(
        ProjectCreate(key: 'ARIJ', name: 'Arij MVP'),
      );

      expect(project.key, 'ARIJ');
      expect(notifier.projects, hasLength(1));
      expect(notifier.projects.single.key, 'ARIJ');
      expect(notifier.createdProjects.single.name, 'Arij MVP');
    });
  });
}
