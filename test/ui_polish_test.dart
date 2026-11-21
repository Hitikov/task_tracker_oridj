import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:task_tracker_oridj/api/api_error.dart';
import 'package:task_tracker_oridj/app/arij_app.dart';
import 'package:task_tracker_oridj/models/project.dart';
import 'package:task_tracker_oridj/models/task.dart';
import 'package:task_tracker_oridj/pages/backlog_page.dart';
import 'package:task_tracker_oridj/pages/home_page.dart';
import 'package:task_tracker_oridj/pages/kanban_page.dart';
import 'package:task_tracker_oridj/pages/projects_page.dart';
import 'package:task_tracker_oridj/repositories/task_repository.dart';
import 'package:task_tracker_oridj/state/auth_providers.dart';
import 'package:task_tracker_oridj/state/projects_providers.dart';
import 'package:task_tracker_oridj/state/tasks_providers.dart';
import 'package:task_tracker_oridj/database/app_database.dart';
import 'package:task_tracker_oridj/repositories/person_repository.dart';
import 'package:task_tracker_oridj/api/person_controller.dart';
import 'package:drift/native.dart';

import 'fakes.dart';

final _project = Project(
  id: 'project-ARIJ',
  key: 'ARIJ',
  name: 'Arij MVP',
  description: 'Demo',
  ownerId: 'user-1',
  createdAt: DateTime.utc(2026, 11, 15, 12),
  updatedAt: DateTime.utc(2026, 11, 15, 12),
);

final _fixedDate = DateTime.utc(2026, 11, 15, 12);

Project _projectItem(String key, String name) => Project(
      id: 'project-$key',
      key: key,
      name: name,
      description: null,
      ownerId: 'user-1',
      createdAt: _fixedDate,
      updatedAt: _fixedDate,
    );

class _LoadingProjectsNotifier extends ProjectsNotifier {
  @override
  Future<List<Project>> build() => Completer<List<Project>>().future;
}

class _ErrorProjectsNotifier extends ProjectsNotifier {
  @override
  Future<List<Project>> build() async {
    throw ApiException(
      code: 'internal_error',
      message: 'Ошибка сервера',
      details: null,
    );
  }
}

class _EmptyProjectsNotifier extends ProjectsNotifier {
  @override
  Future<List<Project>> build() async => const <Project>[];
}

class _DataProjectsNotifier extends ProjectsNotifier {
  _DataProjectsNotifier(this.items);
  final List<Project> items;
  @override
  Future<List<Project>> build() async => items;
}

void _set1500x800(WidgetTester tester) {
  tester.view.physicalSize = const Size(1500, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('1500x800 overflow', () {
    late AppDatabase db;
    late PersonController personController;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      personController = PersonController(PersonRepository(db));
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('экран входа без overflow', (tester) async {
      _set1500x800(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionProvider.overrideWith(() => FakeAuthSession()),
          ],
          child: ArijApp(personController: personController),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Вход в Arij'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('экран проектов без overflow', (tester) async {
      _set1500x800(tester);
      final projects = [
        _projectItem('ARIJ', 'Arij MVP'),
        _projectItem('DEMO', 'Демо проект с длинным названием для проверки'),
      ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionProvider.overrideWith(
              () =>
                  FakeAuthSession(loginResponder: (e, p) async => fakeUser(e)),
            ),
            projectsProvider
                .overrideWith(() => _DataProjectsNotifier(projects)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: const ProjectsPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Arij MVP'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Backlog без overflow', (tester) async {
      _set1500x800(tester);
      final api = FakeApiClient(
        tasks: [
          fakeTask(
            id: 't1',
            number: 1,
            title: 'Первая задача',
            statusId: 's1',
            typeId: 'type-task',
          ).toJson(),
          fakeTask(
            id: 't2',
            number: 2,
            title: 'Вторая задача с очень длинным названием для проверки',
            statusId: 's2',
            typeId: 'type-task',
            priority: TaskPriority.high,
            assigneeId: 'u1',
          ).toJson(),
        ],
        statuses: [
          fakeStatus(id: 's1', name: 'To Do', position: 0).toJson(),
          fakeStatus(id: 's2', name: 'In Progress', position: 1).toJson(),
        ],
        taskTypes: [fakeTaskType().toJson()],
        members: [fakeMember(userId: 'u1', name: 'Ada Lovelace').toJson()],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskRepositoryProvider.overrideWithValue(TaskRepository(api: api)),
          ],
          child: MaterialApp(
            home: BacklogPage(project: _project),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Первая задача'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Kanban без overflow', (tester) async {
      _set1500x800(tester);
      final api = FakeApiClient(
        statuses: [
          fakeStatus(
            id: 's1',
            projectId: 'project-ARIJ',
            name: 'To Do',
            position: 0,
          ).toJson(),
          fakeStatus(
            id: 's2',
            projectId: 'project-ARIJ',
            name: 'In Progress',
            position: 1,
          ).toJson(),
          fakeStatus(
            id: 's3',
            projectId: 'project-ARIJ',
            name: 'Done',
            position: 2,
            isDone: true,
          ).toJson(),
        ],
        tasks: [
          fakeTask(
            id: 't1',
            projectId: 'project-ARIJ',
            number: 1,
            title: 'Задача на доске',
            statusId: 's1',
          ).toJson(),
          fakeTask(
            id: 't2',
            projectId: 'project-ARIJ',
            number: 2,
            title: 'Задача в работе',
            statusId: 's2',
            assigneeId: 'u1',
          ).toJson(),
        ],
        members: [fakeMember(userId: 'u1', name: 'Ada').toJson()],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskRepositoryProvider.overrideWithValue(TaskRepository(api: api)),
          ],
          child: MaterialApp(
            home: KanbanPage(project: _project),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('To Do'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Состояния проектов', () {
    testWidgets('loading показывает индикатор', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            projectsProvider.overrideWith(() => _LoadingProjectsNotifier()),
          ],
          child: const MaterialApp(home: Scaffold(body: ProjectsPage())),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Загрузка проектов…'), findsOneWidget);
    });

    testWidgets('error показывает сообщение и retry', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            projectsProvider.overrideWith(() => _ErrorProjectsNotifier()),
          ],
          child: const MaterialApp(home: Scaffold(body: ProjectsPage())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ошибка сервера'), findsOneWidget);
      expect(find.text('Повторить'), findsOneWidget);
    });

    testWidgets('empty показывает CTA', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            projectsProvider.overrideWith(() => _EmptyProjectsNotifier()),
          ],
          child: const MaterialApp(home: Scaffold(body: ProjectsPage())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Проектов пока нет'), findsOneWidget);
      expect(find.text('Создать проект'), findsWidgets);
    });

    testWidgets('поиск по названию и ключу фильтрует список', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            projectsProvider.overrideWith(
              () => _DataProjectsNotifier([
                _projectItem('ARIJ', 'Arij MVP'),
                _projectItem('DEMO', 'Demo Project'),
              ]),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: ProjectsPage())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Arij MVP'), findsOneWidget);
      expect(find.text('Demo Project'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'demo');
      await tester.pumpAndSettle();

      expect(find.text('Arij MVP'), findsNothing);
      expect(find.text('Demo Project'), findsOneWidget);

      await tester.tap(find.byTooltip('Очистить поиск'));
      await tester.pumpAndSettle();

      expect(find.text('Arij MVP'), findsOneWidget);
    });
  });

  group('Состояния Backlog', () {
    testWidgets('loading показывает индикатор', (tester) async {
      final api = _HangingTasksApiClient();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskRepositoryProvider.overrideWithValue(TaskRepository(api: api)),
          ],
          child: MaterialApp(home: BacklogPage(project: _project)),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('error показывает сообщение и retry', (tester) async {
      final api = _ThrowingTasksApiClient();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskRepositoryProvider.overrideWithValue(TaskRepository(api: api)),
          ],
          child: MaterialApp(home: BacklogPage(project: _project)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ошибка загрузки задач'), findsOneWidget);
      expect(find.text('Повторить'), findsOneWidget);
    });

    testWidgets('empty показывает CTA создания', (tester) async {
      final api = FakeApiClient(
        statuses: [fakeStatus().toJson()],
        taskTypes: [fakeTaskType().toJson()],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskRepositoryProvider.overrideWithValue(TaskRepository(api: api)),
          ],
          child: MaterialApp(home: BacklogPage(project: _project)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Задач пока нет'), findsOneWidget);
      expect(find.text('Создать задачу'), findsOneWidget);
    });
  });

  group('Состояния Kanban', () {
    testWidgets('error показывает retry', (tester) async {
      final api = _ThrowingBoardApiClient();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskRepositoryProvider.overrideWithValue(TaskRepository(api: api)),
          ],
          child: MaterialApp(home: KanbanPage(project: _project)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ошибка доски'), findsOneWidget);
      expect(find.text('Повторить'), findsOneWidget);
    });
  });

  group('адаптивная вёрстка', () {
    late AppDatabase db;
    late PersonController personController;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      personController = PersonController(PersonRepository(db));
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('ширину бокового меню можно менять перетаскиванием',
        (tester) async {
      _set1500x800(tester);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: HomePage(
              login: 'user@example.com',
              personController: personController,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final panel = find.byKey(const Key('sidebar-panel'));
      final handle = find.byKey(const Key('sidebar-resize-handle'));
      expect(panel, findsOneWidget);
      expect(handle, findsOneWidget);

      final before = tester.widget<SizedBox>(panel).width;
      await tester.drag(handle, const Offset(80, 0));
      await tester.pumpAndSettle();
      final after = tester.widget<SizedBox>(panel).width;

      expect(after, greaterThan(before!));
      expect(tester.takeException(), isNull);
    });

    testWidgets('узкий экран 400x800 без overflow', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionProvider.overrideWith(() => FakeAuthSession()),
          ],
          child: ArijApp(personController: personController),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Вход в Arij'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

class _ThrowingBoardApiClient extends FakeApiClient {
  @override
  Future<List<Map<String, dynamic>>> getList(String path) async {
    if (path.contains('/board')) {
      throw ApiException(
        code: 'internal_error',
        message: 'Ошибка доски',
        details: null,
      );
    }
    return super.getList(path);
  }
}

class _HangingTasksApiClient extends FakeApiClient {
  @override
  Future<List<Map<String, dynamic>>> getList(String path) async {
    if (RegExp(r'^/api/v1/projects/[^/]+/tasks').hasMatch(path)) {
      return Completer<List<Map<String, dynamic>>>().future;
    }
    return super.getList(path);
  }
}

class _ThrowingTasksApiClient extends FakeApiClient {
  @override
  Future<List<Map<String, dynamic>>> getList(String path) async {
    if (RegExp(r'^/api/v1/projects/[^/]+/tasks').hasMatch(path)) {
      throw ApiException(
        code: 'internal_error',
        message: 'Ошибка загрузки задач',
        details: null,
      );
    }
    return super.getList(path);
  }
}
