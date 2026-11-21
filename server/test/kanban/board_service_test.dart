import 'package:arij_server/src/services/board_service.dart';
import 'package:arij_server/src/services/project_service.dart'
    show ForbiddenException, NotFoundException, ValidationException;
import 'package:test/test.dart';

import 'fake_board_repository.dart';

void main() {
  const projectId = 'proj-1';
  const otherProjectId = 'proj-other';
  const ownerId = 'user-owner';
  const memberId = 'user-member';
  const outsiderId = 'user-outsider';
  const todoId = 'status-todo';
  const progressId = 'status-progress';
  const doneId = 'status-done';
  const otherStatusId = 'status-other';

  late FakeBoardRepository repository;
  late BoardService service;

  setUp(() {
    repository = FakeBoardRepository()
      ..seedProject(
        id: projectId,
        key: 'PROJ',
        ownerId: ownerId,
        memberIds: <String>[memberId],
      )
      ..seedStatus(
        id: doneId,
        projectId: projectId,
        name: 'Done',
        key: 'done',
        position: 2,
        isDefault: false,
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
      );
    service = BoardService(repository: repository);
  });

  Future<String> addTask({
    required String id,
    required int number,
    required String statusId,
    String? assigneeId,
    String priority = 'medium',
  }) async {
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

  group('BoardService.changeStatus', () {
    test('owner moves a task to another status → updated task', () async {
      final taskId = await addTask(id: 'task-1', number: 1, statusId: todoId);
      final updated = await service.changeStatus(
        userId: ownerId,
        taskId: taskId,
        statusId: progressId,
      );
      expect(updated.statusId, progressId);
      expect(updated.id, taskId);
      expect(updated.number, 1);
      expect(updated.title, 'Task');
      expect((await repository.findTaskById(taskId))!.statusId, progressId);
    });

    test('member may also change the status', () async {
      final taskId = await addTask(id: 'task-1', number: 1, statusId: todoId);
      final updated = await service.changeStatus(
        userId: memberId,
        taskId: taskId,
        statusId: doneId,
      );
      expect(updated.statusId, doneId);
    });

    test('moving to the current status is a no-op success', () async {
      final taskId = await addTask(id: 'task-1', number: 1, statusId: todoId);
      final updated = await service.changeStatus(
        userId: ownerId,
        taskId: taskId,
        statusId: todoId,
      );
      expect(updated.statusId, todoId);
    });

    test(
      'status of another project → validation_error field=statusId',
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
        final taskId = await addTask(id: 'task-1', number: 1, statusId: todoId);
        expect(
          () => service.changeStatus(
            userId: ownerId,
            taskId: taskId,
            statusId: otherStatusId,
          ),
          throwsA(
            isA<ValidationException>().having(
              (error) => error.field,
              'field',
              'statusId',
            ),
          ),
        );
        expect((await repository.findTaskById(taskId))!.statusId, todoId);
      },
    );

    test('empty statusId → validation_error field=statusId', () async {
      final taskId = await addTask(id: 'task-1', number: 1, statusId: todoId);
      expect(
        () => service.changeStatus(
          userId: ownerId,
          taskId: taskId,
          statusId: '   ',
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('unknown task → task_not_found', () async {
      expect(
        () => service.changeStatus(
          userId: ownerId,
          taskId: 'missing-task',
          statusId: todoId,
        ),
        throwsA(
          isA<NotFoundException>().having(
            (error) => error.code,
            'code',
            'task_not_found',
          ),
        ),
      );
    });

    test('non-member → forbidden', () async {
      final taskId = await addTask(id: 'task-1', number: 1, statusId: todoId);
      expect(
        () => service.changeStatus(
          userId: outsiderId,
          taskId: taskId,
          statusId: doneId,
        ),
        throwsA(isA<ForbiddenException>()),
      );
      expect((await repository.findTaskById(taskId))!.statusId, todoId);
    });

    test('task of a missing project → project_not_found', () async {
      repository.addTask(
        id: 'orphan-task',
        projectId: 'proj-gone',
        number: 1,
        statusId: todoId,
      );
      expect(
        () => service.changeStatus(
          userId: ownerId,
          taskId: 'orphan-task',
          statusId: doneId,
        ),
        throwsA(
          isA<NotFoundException>().having(
            (error) => error.code,
            'code',
            'project_not_found',
          ),
        ),
      );
    });
  });

  group('BoardService.getBoard', () {
    test('columns follow status positions and group tasks by status', () async {
      await addTask(
        id: 'task-1',
        number: 1,
        statusId: todoId,
        assigneeId: memberId,
      );
      await addTask(id: 'task-2', number: 2, statusId: progressId);
      await addTask(id: 'task-3', number: 3, statusId: todoId);
      await addTask(id: 'task-4', number: 4, statusId: doneId);

      final columns = await service.getBoard(
        userId: ownerId,
        projectId: projectId,
      );
      expect(columns.map((column) => column.status.id), <String>[
        todoId,
        progressId,
        doneId,
      ]);
      expect(
        columns.map((column) => column.tasks.map((task) => task.id).toList()),
        <List<String>>[
          <String>['task-1', 'task-3'],
          <String>['task-2'],
          <String>['task-4'],
        ],
      );
      final json = columns.first.toJson();
      expect(json.keys, unorderedEquals(<String>['status', 'tasks']));
      expect((json['status'] as Map)['id'], todoId);
      expect(json['tasks'], hasLength(2));
    });

    test('columns without tasks are still returned', () async {
      final columns = await service.getBoard(
        userId: memberId,
        projectId: projectId,
      );
      expect(columns, hasLength(3));
      expect(columns.every((column) => column.tasks.isEmpty), isTrue);
    });

    test('assignee and priority filters apply before grouping', () async {
      await addTask(
        id: 'task-1',
        number: 1,
        statusId: todoId,
        assigneeId: memberId,
        priority: 'high',
      );
      await addTask(
        id: 'task-2',
        number: 2,
        statusId: todoId,
        assigneeId: outsiderId,
        priority: 'low',
      );

      final byAssignee = await service.getBoard(
        userId: ownerId,
        projectId: projectId,
        assignee: memberId,
      );
      expect(byAssignee.first.tasks.map((task) => task.id), <String>['task-1']);

      final byPriority = await service.getBoard(
        userId: ownerId,
        projectId: projectId,
        priority: 'low',
      );
      expect(byPriority.first.tasks.map((task) => task.id), <String>['task-2']);
    });

    test('non-member → forbidden', () async {
      expect(
        () => service.getBoard(userId: outsiderId, projectId: projectId),
        throwsA(isA<ForbiddenException>()),
      );
    });

    test('unknown project → project_not_found', () async {
      expect(
        () => service.getBoard(userId: ownerId, projectId: 'missing-project'),
        throwsA(
          isA<NotFoundException>().having(
            (error) => error.code,
            'code',
            'project_not_found',
          ),
        ),
      );
    });
  });
}
