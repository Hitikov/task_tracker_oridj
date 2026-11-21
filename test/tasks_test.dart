import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:task_tracker_oridj/api/api_error.dart';
import 'package:task_tracker_oridj/models/project_member.dart';
import 'package:task_tracker_oridj/models/status.dart';
import 'package:task_tracker_oridj/models/task.dart';
import 'package:task_tracker_oridj/models/task_create.dart';
import 'package:task_tracker_oridj/models/task_filters.dart';
import 'package:task_tracker_oridj/repositories/task_repository.dart';
import 'package:task_tracker_oridj/state/tasks_providers.dart';

import 'fakes.dart';

const _projectId = 'project-ARIJ';

Task _task({
  String id = 'task-1',
  int number = 1,
  String? key,
  TaskKind kind = TaskKind.task,
  String typeId = 'type-task',
  String statusId = 'status-todo',
  String title = 'Task 1',
  TaskPriority priority = TaskPriority.medium,
  String? assigneeId,
  String? parentId,
  DateTime? dueDate,
}) {
  return fakeTask(
    id: id,
    number: number,
    key: key,
    kind: kind,
    typeId: typeId,
    statusId: statusId,
    title: title,
    priority: priority,
    assigneeId: assigneeId,
    parentId: parentId,
    dueDate: dueDate,
  );
}

ProviderContainer _container(FakeApiClient api) {
  return ProviderContainer(
    overrides: [
      taskRepositoryProvider.overrideWithValue(TaskRepository(api: api)),
    ],
  );
}

void main() {
  group('Task model', () {
    test('fromJson/toJson roundtrip keeps contract fields', () {
      final json = <String, dynamic>{
        'id': 'task-1',
        'projectId': _projectId,
        'number': 7,
        'key': 'ARIJ-7',
        'kind': 'epic',
        'typeId': 'type-feature',
        'statusId': 'status-doing',
        'title': 'Epic title',
        'description': 'Desc',
        'priority': 'high',
        'assigneeId': 'user-2',
        'reporterId': 'user-1',
        'parentId': null,
        'dueDate': '2026-12-01T00:00:00.000Z',
        'createdAt': '2026-11-15T12:00:00.000Z',
        'updatedAt': '2026-11-16T12:00:00.000Z',
      };

      final task = Task.fromJson(json);

      expect(task.id, 'task-1');
      expect(task.projectId, _projectId);
      expect(task.number, 7);
      expect(task.key, 'ARIJ-7');
      expect(task.kind, TaskKind.epic);
      expect(task.typeId, 'type-feature');
      expect(task.statusId, 'status-doing');
      expect(task.priority, TaskPriority.high);
      expect(task.assigneeId, 'user-2');
      expect(task.toJson()['key'], 'ARIJ-7');
      expect(task.toJson()['kind'], 'epic');
      expect(task.toJson()['typeId'], 'type-feature');
    });

    test('TaskUpdate.toJson includes only explicit fields and clears', () {
      const update = TaskUpdate(
        title: 'New',
        statusId: 'status-done',
        clearAssignee: true,
        clearDueDate: true,
      );

      expect(update.toJson(), {
        'statusId': 'status-done',
        'title': 'New',
        'assigneeId': null,
        'dueDate': null,
      });
    });
  });

  group('TaskRepository', () {
    test('listTasks maps tasks from API', () async {
      final api = FakeApiClient(
        tasks: [
          _task(id: 't1', number: 1, title: 'First').toJson(),
          _task(id: 't2', number: 2, title: 'Second').toJson(),
        ],
      );
      final repo = TaskRepository(api: api);

      final tasks = await repo.listTasks(_projectId);

      expect(tasks, hasLength(2));
      expect(tasks.first.key, 'ARIJ-1');
      expect(tasks.last.title, 'Second');
      expect(
        api.calls.any((c) => c.path.contains('/projects/$_projectId/tasks')),
        isTrue,
      );
    });

    test('createTask sends TaskCreate body and returns created task', () async {
      final api = FakeApiClient(
        statuses: [fakeStatus().toJson()],
        taskTypes: [fakeTaskType().toJson()],
      );
      final repo = TaskRepository(api: api);

      final created = await repo.createTask(
        _projectId,
        const TaskCreate(
          kind: TaskKind.task,
          typeId: 'type-task',
          title: 'New task',
          priority: TaskPriority.high,
        ),
      );

      expect(created.title, 'New task');
      expect(created.kind, TaskKind.task);
      expect(created.typeId, 'type-task');
      expect(created.priority, TaskPriority.high);
      expect(created.statusId, 'status-todo');
      final call = api.calls.last;
      expect(call.path, '/api/v1/projects/$_projectId/tasks');
      expect(call.body?['title'], 'New task');
      expect(call.body?['kind'], 'task');
      expect(call.body?['typeId'], 'type-task');
    });

    test('updateTask patches task and returns server response', () async {
      final existing =
          _task(id: 'task-1', title: 'Old', statusId: 'status-todo');
      final api = FakeApiClient(tasks: [existing.toJson()]);
      final repo = TaskRepository(api: api);

      final updated = await repo.updateTask(
        'task-1',
        const TaskUpdate(title: 'New', statusId: 'status-done'),
      );

      expect(updated.title, 'New');
      expect(updated.statusId, 'status-done');
      expect(api.calls.last.path, '/api/v1/tasks/task-1');
      expect(api.calls.last.body?['title'], 'New');
    });

    test('deleteTask calls delete endpoint', () async {
      final api = FakeApiClient(tasks: [_task(id: 'task-1').toJson()]);
      final repo = TaskRepository(api: api);

      await repo.deleteTask('task-1');

      expect(api.calls.last.path, '/api/v1/tasks/task-1');
      expect(api.calls.last.body, isNull);
    });
  });

  group('TasksNotifier', () {
    test('loads task list', () async {
      final api = FakeApiClient(
        tasks: [
          _task(id: 't1', number: 1, title: 'A').toJson(),
          _task(id: 't2', number: 2, title: 'B').toJson(),
        ],
      );
      final container = _container(api);
      addTearDown(container.dispose);

      final tasks = await container.read(tasksProvider(_projectId).future);

      expect(tasks.map((t) => t.id), ['t1', 't2']);
    });

    test('createTask adds task to state', () async {
      final api = FakeApiClient(
        tasks: [_task(id: 't1', number: 1, title: 'Existing').toJson()],
        statuses: [fakeStatus().toJson()],
      );
      final container = _container(api);
      addTearDown(container.dispose);

      await container.read(tasksProvider(_projectId).future);
      await container.read(tasksProvider(_projectId).notifier).createTask(
            const TaskCreate(
              kind: TaskKind.task,
              typeId: 'type-task',
              title: 'Created',
            ),
          );

      final tasks = container.read(tasksProvider(_projectId)).value!;
      expect(tasks, hasLength(2));
      expect(tasks.last.title, 'Created');
    });

    test('updateTask is optimistic and rolls back on error', () async {
      final api = FakeApiClient(
        tasks: [
          _task(id: 't1', title: 'Old', statusId: 'status-todo').toJson()
        ],
        throwOnPatch: true,
      );
      final container = _container(api);
      addTearDown(container.dispose);

      await container.read(tasksProvider(_projectId).future);
      final notifier = container.read(tasksProvider(_projectId).notifier);

      await expectLater(
        notifier.updateTask(
          't1',
          const TaskUpdate(title: 'New', statusId: 'status-done'),
        ),
        throwsA(isA<ApiException>()),
      );

      final tasks = container.read(tasksProvider(_projectId)).value!;
      expect(tasks.single.title, 'Old');
      expect(tasks.single.statusId, 'status-todo');
    });

    test('updateTask applies server response on success', () async {
      final api = FakeApiClient(
        tasks: [
          _task(id: 't1', title: 'Old', statusId: 'status-todo').toJson()
        ],
      );
      final container = _container(api);
      addTearDown(container.dispose);

      await container.read(tasksProvider(_projectId).future);
      final notifier = container.read(tasksProvider(_projectId).notifier);

      final updated = await notifier.updateTask(
        't1',
        const TaskUpdate(title: 'New', statusId: 'status-done'),
      );

      expect(updated.title, 'New');
      final tasks = container.read(tasksProvider(_projectId)).value!;
      expect(tasks.single.title, 'New');
      expect(tasks.single.statusId, 'status-done');
    });

    test('deleteTask is optimistic and rolls back on error', () async {
      final api = FakeApiClient(
        tasks: [
          _task(id: 't1', number: 1, title: 'A').toJson(),
          _task(id: 't2', number: 2, title: 'B').toJson(),
        ],
        throwOnDelete: true,
      );
      final container = _container(api);
      addTearDown(container.dispose);

      await container.read(tasksProvider(_projectId).future);
      final notifier = container.read(tasksProvider(_projectId).notifier);

      await expectLater(
        notifier.deleteTask('t1'),
        throwsA(isA<ApiException>()),
      );

      final tasks = container.read(tasksProvider(_projectId)).value!;
      expect(tasks.map((t) => t.id), ['t1', 't2']);
    });

    test('deleteTask removes task on success', () async {
      final api = FakeApiClient(
        tasks: [
          _task(id: 't1', number: 1, title: 'A').toJson(),
          _task(id: 't2', number: 2, title: 'B').toJson(),
        ],
      );
      final container = _container(api);
      addTearDown(container.dispose);

      await container.read(tasksProvider(_projectId).future);
      await container.read(tasksProvider(_projectId).notifier).deleteTask('t1');

      final tasks = container.read(tasksProvider(_projectId)).value!;
      expect(tasks.map((t) => t.id), ['t2']);
    });
  });

  group('TaskFilters', () {
    final statuses = <Status>[
      fakeStatus(id: 's1', name: 'Todo', position: 0),
      fakeStatus(id: 's2', name: 'Done', position: 1, isDone: true),
    ];
    final members = <ProjectMember>[
      fakeMember(userId: 'u1', name: 'Ada'),
      fakeMember(userId: 'u2', name: 'Bob'),
    ];
    final tasks = <Task>[
      _task(
        id: 't1',
        number: 2,
        key: 'ARIJ-2',
        title: 'Beta',
        kind: TaskKind.task,
        typeId: 'type-bug',
        statusId: 's2',
        assigneeId: 'u2',
        priority: TaskPriority.low,
        dueDate: DateTime.utc(2026, 12, 2),
      ),
      _task(
        id: 't2',
        number: 1,
        key: 'ARIJ-1',
        title: 'Alpha',
        kind: TaskKind.epic,
        typeId: 'type-feature',
        statusId: 's1',
        assigneeId: 'u1',
        priority: TaskPriority.high,
        dueDate: DateTime.utc(2026, 12, 1),
      ),
      _task(
        id: 't3',
        number: 3,
        key: 'ARIJ-3',
        title: 'Gamma',
        kind: TaskKind.subtask,
        typeId: 'type-task',
        statusId: 's1',
        assigneeId: null,
        priority: TaskPriority.medium,
        dueDate: null,
      ),
    ];

    test('filters by search, kind, type, status, assignee, priority', () {
      expect(
        const TaskFilters(search: 'ariJ-1')
            .apply(tasks)
            .map((t) => t.id)
            .toList(),
        ['t2'],
      );
      expect(
        const TaskFilters(kind: TaskKind.epic).apply(tasks).single.id,
        't2',
      );
      expect(
        const TaskFilters(typeId: 'type-bug').apply(tasks).single.id,
        't1',
      );
      expect(
        const TaskFilters(statusId: 's2').apply(tasks).single.id,
        't1',
      );
      expect(
        const TaskFilters(assigneeId: 'u1').apply(tasks).single.id,
        't2',
      );
      expect(
        const TaskFilters(priority: TaskPriority.medium).apply(tasks).single.id,
        't3',
      );
    });

    test('sorts by number, title, status, assignee, priority, dueDate', () {
      expect(
        const TaskFilters(sortField: TaskSortField.number, sortAscending: true)
            .apply(tasks)
            .map((t) => t.id)
            .toList(),
        ['t2', 't1', 't3'],
      );
      expect(
        const TaskFilters(sortField: TaskSortField.title, sortAscending: true)
            .apply(tasks)
            .map((t) => t.id)
            .toList(),
        ['t2', 't1', 't3'],
      );
      expect(
        const TaskFilters(sortField: TaskSortField.status, sortAscending: true)
            .apply(tasks, statuses: statuses)
            .map((t) => t.id)
            .toList(),
        ['t1', 't2', 't3'],
      );
      expect(
        const TaskFilters(
          sortField: TaskSortField.assignee,
          sortAscending: true,
        ).apply(tasks, members: members).map((t) => t.id).toList(),
        ['t3', 't2', 't1'],
      );
      expect(
        const TaskFilters(
          sortField: TaskSortField.priority,
          sortAscending: true,
        ).apply(tasks).map((t) => t.id).toList(),
        ['t1', 't3', 't2'],
      );
      expect(
        const TaskFilters(
          sortField: TaskSortField.dueDate,
          sortAscending: true,
        ).apply(tasks).map((t) => t.id).toList(),
        ['t2', 't1', 't3'],
      );
    });

    test('copyWith can clear nullable filters and cleared keeps sort', () {
      const filters = TaskFilters(
        search: 'a',
        kind: TaskKind.task,
        typeId: 'type-task',
        statusId: 's1',
        assigneeId: 'u1',
        priority: TaskPriority.high,
        sortField: TaskSortField.title,
        sortAscending: false,
      );

      final cleared = filters.cleared();
      expect(cleared.isEmpty, isTrue);
      expect(cleared.sortField, TaskSortField.title);
      expect(cleared.sortAscending, isFalse);

      final reset = filters.copyWith(kind: null, priority: null);
      expect(reset.kind, isNull);
      expect(reset.priority, isNull);
      expect(reset.search, 'a');
    });
  });

  group('TaskFilters query', () {
    test('toQuery includes active filters and sort', () {
      const filters = TaskFilters(
        search: 'bug',
        kind: TaskKind.task,
        statusId: 's1',
        sortField: TaskSortField.priority,
        sortAscending: false,
      );

      expect(filters.toQuery(), {
        'search': 'bug',
        'kind': 'task',
        'statusId': 's1',
        'sort': 'priority',
        'order': 'desc',
      });
    });
  });
}
