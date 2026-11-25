import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:task_tracker_oridj/api/api_client.dart';
import 'package:task_tracker_oridj/api/api_error.dart';
import 'package:task_tracker_oridj/models/project.dart';
import 'package:task_tracker_oridj/models/task_status_change.dart';
import 'package:task_tracker_oridj/pages/backlog_page.dart';
import 'package:task_tracker_oridj/pages/kanban_page.dart';
import 'package:task_tracker_oridj/pages/task_history_page.dart';
import 'package:task_tracker_oridj/repositories/task_repository.dart';
import 'package:task_tracker_oridj/state/auth_providers.dart';
import 'package:task_tracker_oridj/state/task_history_providers.dart';
import 'package:task_tracker_oridj/state/tasks_providers.dart';

import 'fakes.dart';

const _projectId = 'project-ARIJ';

Project get _project => fakeProject('ARIJ');

final List<Map<String, dynamic>> _historyJson = <Map<String, dynamic>>[
  <String, dynamic>{
    'id': 'change-1',
    'taskId': 't1',
    'fromStatusId': null,
    'toStatusId': 's-todo',
    'changedBy': 'user-1',
    'changedAt': '2026-11-15T12:00:00.000Z',
  },
  <String, dynamic>{
    'id': 'change-2',
    'taskId': 't1',
    'fromStatusId': 's-todo',
    'toStatusId': 's-doing',
    'changedBy': 'user-2',
    'changedAt': '2026-11-16T09:30:00.000Z',
  },
];

List<Map<String, dynamic>> get _statusesJson => <Map<String, dynamic>>[
      fakeStatus(
        id: 's-todo',
        projectId: _projectId,
        name: 'Todo',
        position: 0,
      ).toJson(),
      fakeStatus(
        id: 's-doing',
        projectId: _projectId,
        name: 'В работе',
        position: 1,
      ).toJson(),
    ];

class _HistoryApiClient extends FakeApiClient {
  _HistoryApiClient({
    List<Map<String, dynamic>> history = const <Map<String, dynamic>>[],
    this.errorMessage,
    this.hang = false,
    this.failOnce = false,
    super.statuses = const <Map<String, dynamic>>[],
    super.tasks = const <Map<String, dynamic>>[],
    super.taskTypes = const <Map<String, dynamic>>[],
  })  : _history = history,
        fail = failOnce;

  final List<Map<String, dynamic>> _history;
  final String? errorMessage;
  final bool hang;
  final bool failOnce;
  bool fail = false;

  @override
  Future<List<Map<String, dynamic>>> getList(String path) async {
    calls.add((path: path, body: null));
    if (RegExp(r'^/api/v1/tasks/[^/]+/history$').hasMatch(path)) {
      if (hang) return Completer<List<Map<String, dynamic>>>().future;
      if (errorMessage != null && fail) {
        throw ApiException(
          code: 'not_found',
          message: errorMessage!,
          details: null,
        );
      }
      return _history;
    }
    return super.getList(path);
  }
}

ProviderContainer _container(ApiClient api) {
  return ProviderContainer(
    overrides: [apiClientProvider.overrideWithValue(api)],
  );
}

Widget _pumpable(Widget child, ApiClient api) {
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(api),
      taskRepositoryProvider.overrideWithValue(TaskRepository(api: api)),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  group('TaskStatusChange', () {
    test('fromJson разбирает запись и сохраняет null для первой смены', () {
      final first = TaskStatusChange.fromJson(_historyJson.first);
      expect(first.id, 'change-1');
      expect(first.taskId, 't1');
      expect(first.fromStatusId, isNull);
      expect(first.toStatusId, 's-todo');
      expect(first.changedBy, 'user-1');
      expect(first.changedAt, DateTime.utc(2026, 11, 15, 12));

      final second = TaskStatusChange.fromJson(_historyJson.last);
      expect(second.fromStatusId, 's-todo');
      expect(second.toStatusId, 's-doing');
      expect(second.toJson()['changedBy'], 'user-2');
      expect(second.toJson()['fromStatusId'], 's-todo');
    });
  });

  group('taskHistoryProvider', () {
    test('запрашивает историю задачи и мапит записи', () async {
      final api = _HistoryApiClient(history: _historyJson);
      final container = _container(api);
      addTearDown(container.dispose);

      final changes = await container.read(taskHistoryProvider('t1').future);

      expect(changes.map((change) => change.id), ['change-1', 'change-2']);
      expect(
        api.calls.map((call) => call.path),
        contains('/api/v1/tasks/t1/history'),
      );
    });

    test('пробрасывает ошибку API', () async {
      final api = _HistoryApiClient(
        errorMessage: 'История недоступна',
        failOnce: true,
      );
      final container = _container(api);
      addTearDown(container.dispose);

      container.read(taskHistoryProvider('t1'));
      await Future<void>.delayed(Duration.zero);
      final state = container.read(taskHistoryProvider('t1'));
      expect(state.hasError, isTrue);
      expect(state.error.toString(), contains('История недоступна'));
    });
  });

  group('TaskHistoryPage', () {
    testWidgets('показывает историю с именами статусов и датами',
        (tester) async {
      final api = _HistoryApiClient(
        history: _historyJson,
        statuses: _statusesJson,
      );
      await tester.pumpWidget(
        _pumpable(
          const TaskHistoryPage(
            taskId: 't1',
            projectId: _projectId,
            taskKey: 'ARIJ-1',
          ),
          api,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('История'), findsOneWidget);
      expect(find.byKey(const Key('task-history-item')), findsNWidgets(2));
      expect(find.text('— → Todo'), findsOneWidget);
      expect(find.text('Todo → В работе'), findsOneWidget);
      expect(
        find.text(
          'user-2 · ${formatChangedAt(DateTime.utc(2026, 11, 16, 9, 30))}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('показывает индикатор загрузки', (tester) async {
      final api = _HistoryApiClient(hang: true, statuses: _statusesJson);
      await tester.pumpWidget(
        _pumpable(
          const TaskHistoryPage(taskId: 't1', projectId: _projectId),
          api,
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('пустая история показывает понятное сообщение', (tester) async {
      final api = _HistoryApiClient(statuses: _statusesJson);
      await tester.pumpWidget(
        _pumpable(
          const TaskHistoryPage(taskId: 't1', projectId: _projectId),
          api,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('История пуста'), findsOneWidget);
      expect(find.byKey(const Key('task-history-item')), findsNothing);
    });

    testWidgets('ошибка показывает сообщение и повтор загрузки',
        (tester) async {
      final api = _HistoryApiClient(
        history: _historyJson,
        statuses: _statusesJson,
        errorMessage: 'История недоступна',
        failOnce: true,
      );
      await tester.pumpWidget(
        _pumpable(
          const TaskHistoryPage(taskId: 't1', projectId: _projectId),
          api,
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('История недоступна'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Повторить'), findsOneWidget);

      api.fail = false;
      await tester.tap(find.widgetWithText(FilledButton, 'Повторить'));
      await tester.pumpAndSettle();

      expect(find.text('Todo → В работе'), findsOneWidget);
    });
  });

  group('Переход к истории', () {
    testWidgets('кнопка истории на задаче Backlog открывает экран',
        (tester) async {
      final api = _HistoryApiClient(
        history: _historyJson,
        statuses: _statusesJson,
        tasks: [
          fakeTask(
            id: 't1',
            projectId: _projectId,
            number: 1,
            title: 'Задача с историей',
            statusId: 's-todo',
          ).toJson(),
        ],
        taskTypes: [fakeTaskType().toJson()],
      );
      await tester.pumpWidget(_pumpable(BacklogPage(project: _project), api));
      await tester.pumpAndSettle();

      expect(find.byTooltip('История'), findsOneWidget);
      await tester.tap(find.byTooltip('История'));
      await tester.pumpAndSettle();

      expect(find.byType(TaskHistoryPage), findsOneWidget);
      expect(find.text('Todo → В работе'), findsOneWidget);
    });

    testWidgets('кнопка истории на карточке Kanban открывает экран',
        (tester) async {
      final api = _HistoryApiClient(
        history: _historyJson,
        statuses: _statusesJson,
        tasks: [
          fakeTask(
            id: 't1',
            projectId: _projectId,
            number: 1,
            title: 'Карточка с историей',
            statusId: 's-todo',
          ).toJson(),
        ],
      );
      await tester.pumpWidget(_pumpable(KanbanPage(project: _project), api));
      await tester.pumpAndSettle();

      expect(find.byTooltip('История'), findsOneWidget);
      await tester.tap(find.byTooltip('История'));
      await tester.pumpAndSettle();

      expect(find.byType(TaskHistoryPage), findsOneWidget);
      expect(find.text('Todo → В работе'), findsOneWidget);
    });
  });
}
