import 'package:arij_server/src/repositories/board_repository.dart';
import 'package:test/test.dart';

import '../tasks/fake_task_repository.dart';

void main() {
  const projectId = 'proj-1';
  const ownerId = 'user-owner';
  const todoId = 'status-todo';
  const doneId = 'status-done';

  late FakeTaskRepository tasks;
  late TaskBackedBoardRepository board;

  setUp(() {
    tasks = FakeTaskRepository()
      ..seedProject(id: projectId, key: 'PROJ', ownerId: ownerId)
      ..seedTaskType(id: 'type-1', projectId: projectId, name: 'bug')
      ..seedStatus(
        id: todoId,
        projectId: projectId,
        name: 'To Do',
        key: 'todo',
        position: 0,
        isDefault: true,
      )
      ..seedStatus(
        id: doneId,
        projectId: projectId,
        name: 'Done',
        key: 'done',
        position: 1,
        isDefault: false,
      );
    board = TaskBackedBoardRepository(tasks);
  });

  test('delegates task, project, role and status lookups', () async {
    final task = await tasks.createTask(
      projectId: projectId,
      kind: 'task',
      typeId: 'type-1',
      statusId: todoId,
      title: 'Task',
      priority: 'medium',
      reporterId: ownerId,
    );
    expect((await board.findTaskById(task.id))?.id, task.id);
    expect((await board.findProject(projectId))?.key, 'PROJ');
    expect(await board.findProjectRole(projectId, ownerId), 'owner');
    expect((await board.findStatus(projectId, todoId))?.id, todoId);
    expect(await board.findStatus(projectId, 'missing-status'), isNull);
    expect((await board.listStatuses(projectId)).map((s) => s.id), <String>[
      todoId,
      doneId,
    ]);
    expect(
      (await board.findTasks(projectId: projectId)).map((t) => t.id),
      <String>[task.id],
    );
  });

  test('updateTaskStatus reuses the task update path', () async {
    final task = await tasks.createTask(
      projectId: projectId,
      kind: 'task',
      typeId: 'type-1',
      statusId: todoId,
      title: 'Task',
      priority: 'medium',
      reporterId: ownerId,
    );
    final updated = await board.updateTaskStatus(task.id, doneId);
    expect(updated?.statusId, doneId);
    expect(updated?.key, 'PROJ-1');
    expect(updated?.title, task.title);
    expect((await board.findTaskById(task.id))?.statusId, doneId);
    expect(await board.updateTaskStatus('missing-task', doneId), isNull);
  });
}
