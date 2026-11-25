import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:task_tracker_oridj/api/api_error.dart';
import 'package:task_tracker_oridj/models/project.dart';
import 'package:task_tracker_oridj/models/user.dart';
import 'package:task_tracker_oridj/pages/home_page.dart';
import 'package:task_tracker_oridj/pages/home_section.dart';
import 'package:task_tracker_oridj/pages/project_members_page.dart';
import 'package:task_tracker_oridj/state/auth_providers.dart';
import 'package:task_tracker_oridj/state/members_providers.dart';
import 'package:task_tracker_oridj/state/projects_providers.dart';
import 'package:task_tracker_oridj/widgets/app_sidebar.dart';

import 'fakes.dart';

const _projectId = 'project-ARIJ';
const _memberPath = '/api/v1/projects/$_projectId/members';

Project _project({String ownerId = 'user-1'}) {
  return Project(
    id: _projectId,
    key: 'ARIJ',
    name: 'Arij MVP',
    description: null,
    ownerId: ownerId,
    createdAt: DateTime.utc(2026, 11, 15, 12),
    updatedAt: DateTime.utc(2026, 11, 15, 12),
  );
}

User _user({String id = 'user-1', String email = 'owner@example.com'}) {
  return User(
    id: id,
    email: email,
    name: email,
    createdAt: DateTime.utc(2026, 11, 15, 12),
    updatedAt: DateTime.utc(2026, 11, 15, 12),
  );
}

Map<String, dynamic> _ownerJson() => fakeMember(
      userId: 'user-1',
      email: 'owner@example.com',
      name: 'Ada',
      role: 'owner',
    ).toJson();

Map<String, dynamic> _memberJson() => fakeMember(
      userId: 'user-2',
      email: 'bob@example.com',
      name: 'Bob',
      role: 'member',
    ).toJson();

class _MembersApiClient extends FakeApiClient {
  _MembersApiClient({
    List<Map<String, dynamic>> members = const <Map<String, dynamic>>[],
    this.throwOnAdd = false,
    this.throwOnRemove = false,
  }) : super(members: List<Map<String, dynamic>>.of(members));

  final bool throwOnAdd;
  final bool throwOnRemove;

  static final RegExp _addPath = RegExp(r'^/api/v1/projects/[^/]+/members$');
  static final RegExp _removePath =
      RegExp(r'^/api/v1/projects/[^/]+/members/[^/]+$');

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    calls.add((path: path, body: body));
    if (_addPath.hasMatch(path)) {
      if (throwOnAdd) {
        throw ApiException(
          code: 'forbidden',
          message: 'Недостаточно прав',
          details: null,
        );
      }
      final email = (body?['email'] as String?) ?? '';
      final added = <String, dynamic>{
        'userId': 'user-added-${members.length + 1}',
        'email': email,
        'name': email,
        'role': 'member',
        'joinedAt': '2026-11-25T12:00:00.000Z',
      };
      members.add(added);
      return added;
    }
    return super.post(path, body: body);
  }

  @override
  Future<Map<String, dynamic>> delete(String path) async {
    calls.add((path: path, body: null));
    if (_removePath.hasMatch(path)) {
      if (throwOnRemove) {
        throw ApiException(
          code: 'forbidden',
          message: 'Удаление недоступно',
          details: null,
        );
      }
      final userId = path.split('/').last;
      members.removeWhere((item) => item['userId'] == userId);
      return <String, dynamic>{'ok': true};
    }
    return super.delete(path);
  }
}

class _LoadingMembersApiClient extends _MembersApiClient {
  @override
  Future<List<Map<String, dynamic>>> getList(String path) {
    if (path.endsWith('/members')) {
      return Completer<List<Map<String, dynamic>>>().future;
    }
    return super.getList(path);
  }
}

class _FailingMembersApiClient extends _MembersApiClient {
  _FailingMembersApiClient({super.members}) : fail = true;

  bool fail;

  @override
  Future<List<Map<String, dynamic>>> getList(String path) async {
    if (fail && path.endsWith('/members')) {
      throw ApiException(
        code: 'internal_error',
        message: 'Сервер недоступен',
        details: null,
      );
    }
    return super.getList(path);
  }
}

class _Session extends FakeAuthSession {
  _Session(this.user);

  @override
  final User? user;

  @override
  Future<User?> build() async => user;
}

ProviderContainer _container(_MembersApiClient api) {
  final container = ProviderContainer(
    overrides: [
      membersRepositoryProvider.overrideWithValue(MembersRepository(api: api)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Widget _page({
  required _MembersApiClient api,
  required User? user,
  Project? project,
  List<Project>? projects,
}) {
  final activeProject = project ?? _project();
  return ProviderScope(
    overrides: [
      authSessionProvider.overrideWith(() => _Session(user)),
      membersRepositoryProvider.overrideWithValue(MembersRepository(api: api)),
      projectsProvider.overrideWith(
        () => FakeProjectsNotifier(
          initialProjects: projects ?? <Project>[activeProject],
        ),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(body: ProjectMembersPage(project: activeProject)),
    ),
  );
}

void main() {
  group('MembersNotifier', () {
    test('загружает участников с сервера', () async {
      final api = _MembersApiClient(
        members: [_ownerJson(), _memberJson()],
      );
      final container = _container(api);

      final members = await container.read(membersProvider(_projectId).future);

      expect(members.map((member) => member.email), [
        'owner@example.com',
        'bob@example.com',
      ]);
      expect(
        api.calls.any((call) => call.path == _memberPath),
        isTrue,
      );
    });

    test('добавление и удаление меняют состояние', () async {
      final api = _MembersApiClient(members: [_ownerJson()]);
      final container = _container(api);
      await container.read(membersProvider(_projectId).future);
      final notifier = container.read(membersProvider(_projectId).notifier);

      final added = await notifier.addMember(email: 'new@example.com');

      expect(added.email, 'new@example.com');
      expect(
        container.read(membersProvider(_projectId)).value!.map(
              (member) => member.email,
            ),
        ['owner@example.com', 'new@example.com'],
      );
      expect(api.calls.last.path, _memberPath);
      expect(api.calls.last.body?['email'], 'new@example.com');

      await notifier.removeMember(added.userId);

      expect(
        container.read(membersProvider(_projectId)).value!.map(
              (member) => member.email,
            ),
        ['owner@example.com'],
      );
      expect(api.calls.last.path, '$_memberPath/${added.userId}');
    });

    test('откатывает удаление при ошибке сервера', () async {
      final api = _MembersApiClient(
        members: [_ownerJson(), _memberJson()],
        throwOnRemove: true,
      );
      final container = _container(api);
      await container.read(membersProvider(_projectId).future);

      await expectLater(
        container.read(membersProvider(_projectId).notifier).removeMember(
              'user-2',
            ),
        throwsA(isA<ApiException>()),
      );

      expect(
        container.read(membersProvider(_projectId)).value!.map(
              (member) => member.email,
            ),
        ['owner@example.com', 'bob@example.com'],
      );
    });
  });

  group('ProjectMembersPage', () {
    testWidgets('owner видит список с ролями и кнопки управления',
        (tester) async {
      final api = _MembersApiClient(
        members: [_ownerJson(), _memberJson()],
      );

      await tester.pumpWidget(_page(api: api, user: _user()));
      await tester.pumpAndSettle();

      expect(find.text('Участники проекта ARIJ'), findsOneWidget);
      expect(find.text('Ada'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Владелец'), findsOneWidget);
      expect(find.text('Участник'), findsOneWidget);
      expect(find.text('Email нового участника'), findsOneWidget);
      expect(find.byTooltip('Удалить участника'), findsOneWidget);
    });

    testWidgets('owner добавляет участника по email', (tester) async {
      final api = _MembersApiClient(members: [_ownerJson()]);

      await tester.pumpWidget(_page(api: api, user: _user()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'new@example.com');
      await tester.tap(find.text('Добавить'));
      await tester.pumpAndSettle();

      expect(find.text('Участник добавлен'), findsOneWidget);
      expect(find.text('new@example.com'), findsWidgets);
      expect(api.calls.last.body?['email'], 'new@example.com');
    });

    testWidgets('owner удаляет участника', (tester) async {
      final api = _MembersApiClient(
        members: [_ownerJson(), _memberJson()],
      );

      await tester.pumpWidget(_page(api: api, user: _user()));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Удалить участника'));
      await tester.pumpAndSettle();

      expect(find.text('Участник удалён'), findsOneWidget);
      expect(find.text('bob@example.com'), findsNothing);
      expect(api.calls.last.path, '$_memberPath/user-2');
    });

    testWidgets('не-владелец видит список, но не видит кнопок управления',
        (tester) async {
      final api = _MembersApiClient(
        members: [_ownerJson(), _memberJson()],
      );

      await tester.pumpWidget(
        _page(api: api, user: _user(id: 'user-9', email: 'guest@example.com')),
      );
      await tester.pumpAndSettle();

      expect(find.text('bob@example.com'), findsOneWidget);
      expect(find.text('Владелец'), findsOneWidget);
      expect(find.text('Email нового участника'), findsNothing);
      expect(find.byTooltip('Удалить участника'), findsNothing);
    });

    testWidgets('ошибка добавления показывается в SnackBar', (tester) async {
      final api = _MembersApiClient(
        members: [_ownerJson()],
        throwOnAdd: true,
      );

      await tester.pumpWidget(_page(api: api, user: _user()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'new@example.com');
      await tester.tap(find.text('Добавить'));
      await tester.pumpAndSettle();

      expect(find.text('Недостаточно прав'), findsOneWidget);
      expect(find.text('owner@example.com'), findsWidgets);
    });

    testWidgets('показывает загрузку', (tester) async {
      await tester.pumpWidget(
        _page(api: _LoadingMembersApiClient(), user: _user()),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Загрузка участников…'), findsOneWidget);
    });

    testWidgets('ошибка загрузки показывает повтор', (tester) async {
      final api = _FailingMembersApiClient(members: [_memberJson()]);

      await tester.pumpWidget(_page(api: api, user: _user()));
      await tester.pumpAndSettle();

      expect(find.text('Сервер недоступен'), findsOneWidget);
      expect(find.text('Повторить'), findsOneWidget);

      api.fail = false;
      await tester.tap(find.text('Повторить'));
      await tester.pumpAndSettle();

      expect(find.text('bob@example.com'), findsOneWidget);
    });

    testWidgets('пустой список показывает сообщение', (tester) async {
      await tester.pumpWidget(_page(api: _MembersApiClient(), user: _user()));
      await tester.pumpAndSettle();

      expect(find.text('Участников пока нет'), findsOneWidget);
    });
  });

  group('Навигация', () {
    testWidgets('сайдбар содержит раздел Участники', (tester) async {
      HomeSection? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppSidebar(
              login: 'owner@example.com',
              selectedSection: HomeSection.dashboard,
              onSectionSelected: (section) => selected = section,
              onLogout: () {},
            ),
          ),
        ),
      );

      expect(find.text('Участники'), findsOneWidget);

      await tester.tap(find.text('Участники'));
      await tester.pump();

      expect(selected, HomeSection.members);
    });

    testWidgets('HomePage открывает участников выбранного проекта',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final project = _project();
      final api = _MembersApiClient(members: [_ownerJson(), _memberJson()]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionProvider.overrideWith(() => _Session(_user())),
            membersRepositoryProvider.overrideWithValue(
              MembersRepository(api: api),
            ),
            projectsProvider.overrideWith(
              () => FakeProjectsNotifier(initialProjects: [project]),
            ),
          ],
          child: MaterialApp(home: HomePage(login: 'owner@example.com')),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Участники'));
      await tester.pumpAndSettle();

      expect(find.text('Участники проекта ARIJ'), findsOneWidget);
      expect(find.text('Ada'), findsOneWidget);
    });
  });
}
