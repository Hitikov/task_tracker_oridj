import 'package:arij_server/src/models/task.dart';
import 'package:arij_server/src/services/project_service.dart'
    show ForbiddenException, NotFoundException, ValidationException;
import 'package:arij_server/src/services/task_service.dart';
import 'package:test/test.dart';

import 'fake_task_repository.dart';

void main() {
  const unknownProjectId = '00000000-0000-4000-8000-000000000000';
  const unknownTaskId = '00000000-0000-4000-8000-000000000001';

  late FakeTaskRepository repository;
  late TaskService service;

  setUp(() {
    repository = FakeTaskRepository();
    service = TaskService(repository: repository);
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
    repository.seedTaskType(
      id: 'type-00000000-0000-4000-8000-000000000301',
      projectId: 'proj-00000000-0000-4000-8000-000000000100',
      name: 'feature',
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

  Future<Task> create({
    required String userId,
    required String kind,
    String? parentId,
    String project = projectId,
    String type = typeId,
    String status = statusId,
  }) async {
    return service.createTask(
      userId: userId,
      projectId: project,
      title: 'Task',
      kind: kind,
      typeId: type,
      statusId: status,
      priority: 'medium',
      parentId: parentId,
    );
  }

  group('createTask', () {
    test('creates an epic with number 1 and key PROJ-1', () async {
      final task = await create(userId: ownerId, kind: 'epic');
      expect(task.id, isNotEmpty);
      expect(task.projectId, projectId);
      expect(task.number, 1);
      expect(task.key, 'PROJ-1');
      expect(task.kind, 'epic');
      expect(task.parentId, isNull);
      expect(task.title, 'Task');
      expect(task.typeId, typeId);
      expect(task.statusId, statusId);
      expect(task.priority, 'medium');
      expect(task.assigneeId, isNull);
      expect(task.reporterId, ownerId);
      expect(task.dueDate, isNull);
      expect(task.createdAt, isA<DateTime>());
      expect(task.updatedAt, isA<DateTime>());
    });

    test('creates a task under an epic', () async {
      final epic = await create(userId: ownerId, kind: 'epic');
      final task = await create(
        userId: ownerId,
        kind: 'task',
        parentId: epic.id,
      );
      expect(task.number, 2);
      expect(task.key, 'PROJ-2');
      expect(task.kind, 'task');
      expect(task.parentId, epic.id);
    });

    test('creates a subtask under a task', () async {
      final epic = await create(userId: ownerId, kind: 'epic');
      final task = await create(
        userId: ownerId,
        kind: 'task',
        parentId: epic.id,
      );
      final subtask = await create(
        userId: ownerId,
        kind: 'subtask',
        parentId: task.id,
      );
      expect(subtask.number, 3);
      expect(subtask.kind, 'subtask');
      expect(subtask.parentId, task.id);
    });

    test('numbering is independent between projects', () async {
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
      await create(userId: ownerId, kind: 'epic');
      final other = await service.createTask(
        userId: ownerId,
        projectId: 'proj-other',
        title: 'Other',
        kind: 'epic',
        typeId: 'type-other',
        statusId: 'status-other',
        priority: 'low',
      );
      expect(other.number, 1);
      expect(other.key, 'OTHER-1');
    });

    test('task without a parent is allowed', () async {
      final task = await create(userId: ownerId, kind: 'task', parentId: null);
      expect(task.parentId, isNull);
    });

    test('assignee, description, priority and dueDate are stored', () async {
      final dueDate = DateTime.now().toUtc().add(const Duration(days: 7));
      final task = await service.createTask(
        userId: ownerId,
        projectId: projectId,
        title: '  T  ',
        kind: 'task',
        typeId: typeId,
        statusId: statusId,
        priority: 'critical',
        description: '  d  ',
        assigneeId: memberId,
        parentId: null,
        dueDate: dueDate,
      );
      expect(task.title, 'T');
      expect(task.description, 'd');
      expect(task.priority, 'critical');
      expect(task.assigneeId, memberId);
      expect(task.dueDate, dueDate);
    });

    test('epic with a parent → 400 validation_error field=parentId', () async {
      final epic = await create(userId: ownerId, kind: 'epic');
      await expectLater(
        create(userId: ownerId, kind: 'epic', parentId: epic.id),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.field,
            'field',
            'parentId',
          ),
        ),
      );
    });

    test(
      'subtask without a parent → 400 validation_error field=parentId',
      () async {
        await expectLater(
          create(userId: ownerId, kind: 'subtask', parentId: null),
          throwsA(
            isA<ValidationException>().having(
              (e) => e.field,
              'field',
              'parentId',
            ),
          ),
        );
      },
    );

    test(
      'subtask under an epic → 400 validation_error field=parentId',
      () async {
        final epic = await create(userId: ownerId, kind: 'epic');
        await expectLater(
          create(userId: ownerId, kind: 'subtask', parentId: epic.id),
          throwsA(
            isA<ValidationException>().having(
              (e) => e.field,
              'field',
              'parentId',
            ),
          ),
        );
      },
    );

    test(
      'task under a subtask → 400 validation_error field=parentId',
      () async {
        final epic = await create(userId: ownerId, kind: 'epic');
        final task = await create(
          userId: ownerId,
          kind: 'task',
          parentId: epic.id,
        );
        final subtask = await create(
          userId: ownerId,
          kind: 'subtask',
          parentId: task.id,
        );
        await expectLater(
          create(userId: ownerId, kind: 'task', parentId: subtask.id),
          throwsA(
            isA<ValidationException>().having(
              (e) => e.field,
              'field',
              'parentId',
            ),
          ),
        );
      },
    );

    test(
      'parent in another project → 400 validation_error field=parentId',
      () async {
        repository.seedProject(
          id: 'proj-other',
          key: 'OTHER',
          ownerId: ownerId,
        );
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
        final otherEpic = await service.createTask(
          userId: ownerId,
          projectId: 'proj-other',
          title: 'Other',
          kind: 'epic',
          typeId: 'type-other',
          statusId: 'status-other',
          priority: 'low',
        );
        await expectLater(
          create(userId: ownerId, kind: 'task', parentId: otherEpic.id),
          throwsA(
            isA<ValidationException>().having(
              (e) => e.field,
              'field',
              'parentId',
            ),
          ),
        );
      },
    );

    test('unknown parent → 404 task_not_found', () async {
      await expectLater(
        create(userId: ownerId, kind: 'task', parentId: unknownTaskId),
        throwsA(
          isA<NotFoundException>().having(
            (e) => e.code,
            'code',
            'task_not_found',
          ),
        ),
      );
    });

    test('invalid kind → 400 validation_error field=kind', () async {
      await expectLater(
        service.createTask(
          userId: ownerId,
          projectId: projectId,
          title: 'T',
          kind: 'work',
          typeId: typeId,
          statusId: statusId,
          priority: 'low',
        ),
        throwsA(
          isA<ValidationException>().having((e) => e.field, 'field', 'kind'),
        ),
      );
    });

    test('invalid priority → 400 validation_error field=priority', () async {
      await expectLater(
        service.createTask(
          userId: ownerId,
          projectId: projectId,
          title: 'T',
          kind: 'task',
          typeId: typeId,
          statusId: statusId,
          priority: 'urgent',
        ),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.field,
            'field',
            'priority',
          ),
        ),
      );
    });

    test('empty title → 400 validation_error field=title', () async {
      await expectLater(
        service.createTask(
          userId: ownerId,
          projectId: projectId,
          title: '   ',
          kind: 'task',
          typeId: typeId,
          statusId: statusId,
          priority: 'low',
        ),
        throwsA(
          isA<ValidationException>().having((e) => e.field, 'field', 'title'),
        ),
      );
    });

    test('too long title → 400 validation_error field=title', () async {
      await expectLater(
        service.createTask(
          userId: ownerId,
          projectId: projectId,
          title: 'A' * 256,
          kind: 'task',
          typeId: typeId,
          statusId: statusId,
          priority: 'low',
        ),
        throwsA(
          isA<ValidationException>().having((e) => e.field, 'field', 'title'),
        ),
      );
    });

    test('empty typeId → 400 validation_error field=typeId', () async {
      await expectLater(
        service.createTask(
          userId: ownerId,
          projectId: projectId,
          title: 'T',
          kind: 'task',
          typeId: '',
          statusId: statusId,
          priority: 'low',
        ),
        throwsA(
          isA<ValidationException>().having((e) => e.field, 'field', 'typeId'),
        ),
      );
    });

    test(
      'type of another project → 400 validation_error field=typeId',
      () async {
        repository.seedProject(
          id: 'proj-other',
          key: 'OTHER',
          ownerId: ownerId,
        );
        repository.seedTaskType(
          id: 'type-other',
          projectId: 'proj-other',
          name: 'bug',
        );
        await expectLater(
          service.createTask(
            userId: ownerId,
            projectId: projectId,
            title: 'T',
            kind: 'task',
            typeId: 'type-other',
            statusId: statusId,
            priority: 'low',
          ),
          throwsA(
            isA<ValidationException>().having(
              (e) => e.field,
              'field',
              'typeId',
            ),
          ),
        );
      },
    );

    test('empty statusId uses the project default status', () async {
      // OpenAPI TaskCreate.statusId is optional: the server picks the
      // project's default column instead of rejecting the request.
      final task = await service.createTask(
        userId: ownerId,
        projectId: projectId,
        title: 'T',
        kind: 'task',
        typeId: typeId,
        statusId: '',
        priority: 'low',
      );
      expect(task.statusId, 'status-00000000-0000-4000-8000-000000000400');
    });

    test('dueDate in the past → 400 validation_error field=dueDate', () async {
      await expectLater(
        service.createTask(
          userId: ownerId,
          projectId: projectId,
          title: 'T',
          kind: 'task',
          typeId: typeId,
          statusId: statusId,
          priority: 'low',
          dueDate: DateTime.now().toUtc().subtract(const Duration(days: 1)),
        ),
        throwsA(
          isA<ValidationException>().having((e) => e.field, 'field', 'dueDate'),
        ),
      );
    });

    test('dueDate in the future is allowed', () async {
      final task = await service.createTask(
        userId: ownerId,
        projectId: projectId,
        title: 'T',
        kind: 'task',
        typeId: typeId,
        statusId: statusId,
        priority: 'low',
        dueDate: DateTime.now().toUtc().add(const Duration(days: 7)),
      );
      expect(task.dueDate, isNotNull);
    });

    test('unknown project → 404 project_not_found', () async {
      await expectLater(
        create(userId: ownerId, kind: 'epic', project: unknownProjectId),
        throwsA(
          isA<NotFoundException>().having(
            (e) => e.code,
            'code',
            'project_not_found',
          ),
        ),
      );
    });

    test('non-member → 403 forbidden', () async {
      await expectLater(
        create(userId: outsiderId, kind: 'epic'),
        throwsA(isA<ForbiddenException>()),
      );
    });
  });

  group('getTask', () {
    test('owner sees the task', () async {
      final task = await create(userId: ownerId, kind: 'epic');
      expect(
        (await service.getTask(userId: ownerId, taskId: task.id)).id,
        task.id,
      );
    });

    test('member sees the task', () async {
      final task = await create(userId: ownerId, kind: 'epic');
      expect(
        (await service.getTask(userId: memberId, taskId: task.id)).id,
        task.id,
      );
    });

    test('non-member → 403 forbidden', () async {
      final task = await create(userId: ownerId, kind: 'epic');
      await expectLater(
        service.getTask(userId: outsiderId, taskId: task.id),
        throwsA(isA<ForbiddenException>()),
      );
    });

    test('unknown id → 404 task_not_found', () async {
      await expectLater(
        service.getTask(userId: ownerId, taskId: unknownTaskId),
        throwsA(
          isA<NotFoundException>().having(
            (e) => e.code,
            'code',
            'task_not_found',
          ),
        ),
      );
    });
  });

  group('updateTask', () {
    test('owner updates the title', () async {
      final task = await create(userId: ownerId, kind: 'epic');
      final updated = await service.updateTask(
        userId: ownerId,
        taskId: task.id,
        fields: <String, Object?>{'title': 'New title'},
      );
      expect(updated.title, 'New title');
      expect(updated.number, task.number);
      expect(updated.key, task.key);
    });

    test('member updates the task', () async {
      final task = await create(userId: ownerId, kind: 'epic');
      final updated = await service.updateTask(
        userId: memberId,
        taskId: task.id,
        fields: <String, Object?>{'priority': 'high'},
      );
      expect(updated.priority, 'high');
    });

    test('subtask reparented to another task is allowed', () async {
      final epic = await create(userId: ownerId, kind: 'epic');
      final t1 = await create(userId: ownerId, kind: 'task', parentId: epic.id);
      final t2 = await create(userId: ownerId, kind: 'task', parentId: epic.id);
      final subtask = await create(
        userId: ownerId,
        kind: 'subtask',
        parentId: t1.id,
      );
      final updated = await service.updateTask(
        userId: ownerId,
        taskId: subtask.id,
        fields: <String, Object?>{'parentId': t2.id},
      );
      expect(updated.kind, 'subtask');
      expect(updated.parentId, t2.id);
    });

    test(
      'task → subtask with no parent → 400 validation_error field=parentId',
      () async {
        final task = await create(userId: ownerId, kind: 'task');
        await expectLater(
          service.updateTask(
            userId: ownerId,
            taskId: task.id,
            fields: <String, Object?>{'kind': 'subtask'},
          ),
          throwsA(
            isA<ValidationException>().having(
              (e) => e.field,
              'field',
              'parentId',
            ),
          ),
        );
      },
    );

    test('epic → with parent → 400 validation_error field=parentId', () async {
      final epic = await create(userId: ownerId, kind: 'epic');
      final child = await create(
        userId: ownerId,
        kind: 'task',
        parentId: epic.id,
      );
      await expectLater(
        service.updateTask(
          userId: ownerId,
          taskId: epic.id,
          fields: <String, Object?>{'kind': 'task', 'parentId': child.id},
        ),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.field,
            'field',
            'parentId',
          ),
        ),
      );
    });

    test(
      'subtask parent cleared → 400 validation_error field=parentId',
      () async {
        final epic = await create(userId: ownerId, kind: 'epic');
        final task = await create(
          userId: ownerId,
          kind: 'task',
          parentId: epic.id,
        );
        final subtask = await create(
          userId: ownerId,
          kind: 'subtask',
          parentId: task.id,
        );
        await expectLater(
          service.updateTask(
            userId: ownerId,
            taskId: subtask.id,
            fields: <String, Object?>{'parentId': null},
          ),
          throwsA(
            isA<ValidationException>().having(
              (e) => e.field,
              'field',
              'parentId',
            ),
          ),
        );
      },
    );

    test(
      'task reparented to a subtask → 400 validation_error field=parentId',
      () async {
        final epic = await create(userId: ownerId, kind: 'epic');
        final task = await create(
          userId: ownerId,
          kind: 'task',
          parentId: epic.id,
        );
        final subtask = await create(
          userId: ownerId,
          kind: 'subtask',
          parentId: task.id,
        );
        await expectLater(
          service.updateTask(
            userId: ownerId,
            taskId: task.id,
            fields: <String, Object?>{'parentId': subtask.id},
          ),
          throwsA(
            isA<ValidationException>().having(
              (e) => e.field,
              'field',
              'parentId',
            ),
          ),
        );
      },
    );

    test('invalid kind → 400 validation_error field=kind', () async {
      final task = await create(userId: ownerId, kind: 'epic');
      await expectLater(
        service.updateTask(
          userId: ownerId,
          taskId: task.id,
          fields: <String, Object?>{'kind': 'work'},
        ),
        throwsA(
          isA<ValidationException>().having((e) => e.field, 'field', 'kind'),
        ),
      );
    });

    test(
      'type of another project → 400 validation_error field=typeId',
      () async {
        repository.seedProject(
          id: 'proj-other',
          key: 'OTHER',
          ownerId: ownerId,
        );
        repository.seedTaskType(
          id: 'type-other',
          projectId: 'proj-other',
          name: 'bug',
        );
        final task = await create(userId: ownerId, kind: 'task');
        await expectLater(
          service.updateTask(
            userId: ownerId,
            taskId: task.id,
            fields: <String, Object?>{'typeId': 'type-other'},
          ),
          throwsA(
            isA<ValidationException>().having(
              (e) => e.field,
              'field',
              'typeId',
            ),
          ),
        );
      },
    );

    test('empty title → 400 validation_error field=title', () async {
      final task = await create(userId: ownerId, kind: 'epic');
      await expectLater(
        service.updateTask(
          userId: ownerId,
          taskId: task.id,
          fields: <String, Object?>{'title': '   '},
        ),
        throwsA(
          isA<ValidationException>().having((e) => e.field, 'field', 'title'),
        ),
      );
    });

    test('dueDate in the past → 400 validation_error field=dueDate', () async {
      final task = await create(userId: ownerId, kind: 'task');
      await expectLater(
        service.updateTask(
          userId: ownerId,
          taskId: task.id,
          fields: <String, Object?>{
            'dueDate': DateTime.now().toUtc().subtract(const Duration(days: 1)),
          },
        ),
        throwsA(
          isA<ValidationException>().having((e) => e.field, 'field', 'dueDate'),
        ),
      );
    });

    test('unknown id → 404 task_not_found', () async {
      await expectLater(
        service.updateTask(
          userId: ownerId,
          taskId: unknownTaskId,
          fields: <String, Object?>{'title': 'X'},
        ),
        throwsA(
          isA<NotFoundException>().having(
            (e) => e.code,
            'code',
            'task_not_found',
          ),
        ),
      );
    });

    test('non-member → 403 forbidden', () async {
      final task = await create(userId: ownerId, kind: 'epic');
      await expectLater(
        service.updateTask(
          userId: outsiderId,
          taskId: task.id,
          fields: <String, Object?>{'title': 'X'},
        ),
        throwsA(isA<ForbiddenException>()),
      );
    });

    test('empty fields → 400 validation_error', () async {
      final task = await create(userId: ownerId, kind: 'epic');
      await expectLater(
        service.updateTask(
          userId: ownerId,
          taskId: task.id,
          fields: const <String, Object?>{},
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('unknown field → 400 validation_error', () async {
      final task = await create(userId: ownerId, kind: 'epic');
      await expectLater(
        service.updateTask(
          userId: ownerId,
          taskId: task.id,
          fields: const <String, Object?>{'unknown': 1},
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('deleteTask', () {
    test('member deletes the task and it is gone', () async {
      final task = await create(userId: ownerId, kind: 'epic');
      await service.deleteTask(userId: memberId, taskId: task.id);
      expect(await repository.findTaskById(task.id), isNull);
    });

    test('non-member → 403 forbidden', () async {
      final task = await create(userId: ownerId, kind: 'epic');
      await expectLater(
        service.deleteTask(userId: outsiderId, taskId: task.id),
        throwsA(isA<ForbiddenException>()),
      );
    });

    test('unknown id → 404 task_not_found', () async {
      await expectLater(
        service.deleteTask(userId: ownerId, taskId: unknownTaskId),
        throwsA(
          isA<NotFoundException>().having(
            (e) => e.code,
            'code',
            'task_not_found',
          ),
        ),
      );
    });
  });

  group('listTasks', () {
    test('returns the project tasks ordered by number', () async {
      final epic = await create(userId: ownerId, kind: 'epic');
      final task = await create(
        userId: ownerId,
        kind: 'task',
        parentId: epic.id,
      );
      final subtask = await create(
        userId: ownerId,
        kind: 'subtask',
        parentId: task.id,
      );
      final tasks = await service.listTasks(
        userId: ownerId,
        projectId: projectId,
      );
      expect(tasks.map((t) => t.id), <String>[epic.id, task.id, subtask.id]);
      expect(tasks.map((t) => t.number), <int>[1, 2, 3]);
    });

    test('filters by kind', () async {
      await create(userId: ownerId, kind: 'epic');
      await create(userId: ownerId, kind: 'task');
      final epics = await service.listTasks(
        userId: ownerId,
        projectId: projectId,
        kind: 'epic',
      );
      expect(epics, hasLength(1));
      expect(epics.single.kind, 'epic');
    });

    test('filters by status, priority and assignee', () async {
      final epic = await create(userId: ownerId, kind: 'epic');
      await service.updateTask(
        userId: ownerId,
        taskId: epic.id,
        fields: <String, Object?>{'statusId': statusId, 'assigneeId': memberId},
      );
      final byStatus = await service.listTasks(
        userId: ownerId,
        projectId: projectId,
        status: statusId,
      );
      expect(byStatus, hasLength(1));
      final byAssignee = await service.listTasks(
        userId: ownerId,
        projectId: projectId,
        assignee: memberId,
      );
      expect(byAssignee, hasLength(1));
    });

    test('tasks of another project are not visible', () async {
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
      await create(
        userId: ownerId,
        kind: 'epic',
        project: 'proj-other',
        type: 'type-other',
        status: 'status-other',
      );
      final tasks = await service.listTasks(
        userId: ownerId,
        projectId: projectId,
      );
      expect(tasks, isEmpty);
    });

    test('non-member → 403 forbidden', () async {
      await expectLater(
        service.listTasks(userId: outsiderId, projectId: projectId),
        throwsA(isA<ForbiddenException>()),
      );
    });

    test('unknown project → 404 project_not_found', () async {
      await expectLater(
        service.listTasks(userId: ownerId, projectId: unknownProjectId),
        throwsA(
          isA<NotFoundException>().having(
            (e) => e.code,
            'code',
            'project_not_found',
          ),
        ),
      );
    });
  });

  group('listTaskTypes', () {
    test('returns the project types', () async {
      final types = await service.listTaskTypes(
        userId: ownerId,
        projectId: projectId,
      );
      expect(types.map((t) => t.name).toSet(), <String>{'bug', 'feature'});
    });

    test('non-member → 403 forbidden', () async {
      await expectLater(
        service.listTaskTypes(userId: outsiderId, projectId: projectId),
        throwsA(isA<ForbiddenException>()),
      );
    });

    test('unknown project → 404 project_not_found', () async {
      await expectLater(
        service.listTaskTypes(userId: ownerId, projectId: unknownProjectId),
        throwsA(
          isA<NotFoundException>().having(
            (e) => e.code,
            'code',
            'project_not_found',
          ),
        ),
      );
    });
  });

  group('listStatuses', () {
    test('returns the project statuses ordered by position', () async {
      final statuses = await service.listStatuses(
        userId: ownerId,
        projectId: projectId,
      );
      expect(statuses, hasLength(1));
      expect(statuses.single.key, 'todo');
      expect(statuses.single.isDefault, isTrue);
    });

    test('non-member → 403 forbidden', () async {
      await expectLater(
        service.listStatuses(userId: outsiderId, projectId: projectId),
        throwsA(isA<ForbiddenException>()),
      );
    });

    test('unknown project → 404 project_not_found', () async {
      await expectLater(
        service.listStatuses(userId: ownerId, projectId: unknownProjectId),
        throwsA(
          isA<NotFoundException>().having(
            (e) => e.code,
            'code',
            'project_not_found',
          ),
        ),
      );
    });
  });
}
