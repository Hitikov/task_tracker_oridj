import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/board_column.dart';
import '../models/project_member.dart';
import '../models/status.dart';
import '../models/task.dart';
import '../models/task_create.dart';
import '../models/task_filters.dart';
import '../models/task_type.dart';
import '../repositories/task_repository.dart';
import 'auth_providers.dart';

/// Репозиторий задач (инъекция зависимостей).
final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository(api: ref.read(apiClientProvider));
});

/// Типы задач проекта: `GET /api/v1/projects/{id}/task-types`.
final taskTypesProvider =
    FutureProvider.family<List<TaskType>, String>((ref, projectId) {
  return ref.read(taskRepositoryProvider).listTaskTypes(projectId);
});

/// Статусы проекта: `GET /api/v1/projects/{id}/statuses`.
final taskStatusesProvider =
    FutureProvider.family<List<Status>, String>((ref, projectId) {
  return ref.read(taskRepositoryProvider).listStatuses(projectId);
});

/// Участники проекта (для отображения исполнителя).
final projectMembersProvider =
    FutureProvider.family<List<ProjectMember>, String>((ref, projectId) {
  return ref.read(taskRepositoryProvider).listMembers(projectId);
});

/// Фильтры и сортировка бэклога (по проекту).
final taskFiltersProvider =
    StateProvider.family<TaskFilters, String>((ref, projectId) {
  return const TaskFilters();
});

/// Список задач проекта: `AsyncValue<List<Task>>` — loading/error/data.
///
/// Оптимистичные операции [TasksNotifier.updateTask] и
/// [TasksNotifier.deleteTask] откатывают состояние при ошибке.
class TasksNotifier extends AsyncNotifier<List<Task>> {
  TasksNotifier(this.projectId);

  final String projectId;

  @override
  Future<List<Task>> build() async {
    final repository = ref.read(taskRepositoryProvider);
    return repository.listTasks(projectId);
  }

  List<Task> get tasks => state.value ?? const <Task>[];

  /// Перечитать список с сервера.
  Future<void> refresh() async {
    state = const AsyncValue<List<Task>>.loading();
    try {
      final repository = ref.read(taskRepositoryProvider);
      state = AsyncValue.data(await repository.listTasks(projectId));
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Создать задачу и добавить её в список.
  Future<Task> createTask(TaskCreate create) async {
    final repository = ref.read(taskRepositoryProvider);
    final task = await repository.createTask(projectId, create);
    final current = tasks;
    if (!current.any((item) => item.id == task.id)) {
      state = AsyncValue.data([...current, task]);
    }
    return task;
  }

  /// Частично обновить задачу.
  ///
  /// Сначала применяется оптимистично, затем приходит ответ сервера;
  /// при ошибке список откатывается к прежнему состоянию.
  Future<Task> updateTask(String taskId, TaskUpdate update) async {
    final repository = ref.read(taskRepositoryProvider);
    final current = tasks;
    final previous = List<Task>.of(current);
    final index = current.indexWhere((item) => item.id == taskId);

    if (index != -1) {
      final optimistic = List<Task>.of(current);
      optimistic[index] = current[index].applyUpdate(update);
      state = AsyncValue.data(optimistic);
    }

    try {
      final updated = await repository.updateTask(taskId, update);
      final list = state.value ?? const <Task>[];
      state = AsyncValue.data(<Task>[
        for (final item in list)
          if (item.id == updated.id) updated else item,
      ]);
      return updated;
    } catch (_) {
      state = AsyncValue.data(previous);
      rethrow;
    }
  }

  /// Удалить задачу с оптимистичным удалением и откатом при ошибке.
  Future<void> deleteTask(String taskId) async {
    final repository = ref.read(taskRepositoryProvider);
    final current = tasks;
    final previous = List<Task>.of(current);

    state = AsyncValue.data(<Task>[
      for (final item in current)
        if (item.id != taskId) item,
    ]);

    try {
      await repository.deleteTask(taskId);
    } catch (_) {
      state = AsyncValue.data(previous);
      rethrow;
    }
  }

  /// Синхронизирует задачу, полученную из другого источника (например, Kanban).
  ///
  /// Если задача уже есть в списке — заменяет её; если нет и список загружен —
  /// добавляет. Это позволяет Backlog видеть актуальный статус после переноса
  /// на доске без повторного запроса.
  void syncTask(Task task) {
    final current = state.value;
    if (current == null) return;
    final index = current.indexWhere((item) => item.id == task.id);
    if (index == -1) {
      state = AsyncValue.data(<Task>[...current, task]);
      return;
    }
    state = AsyncValue.data(<Task>[
      for (final item in current)
        if (item.id == task.id) task else item,
    ]);
  }
}

final tasksProvider =
    AsyncNotifierProvider.family<TasksNotifier, List<Task>, String>(
  TasksNotifier.new,
);

/// Отфильтрованный и отсортированный список задач для экрана Backlog.
final filteredTasksProvider =
    Provider.family<List<Task>, String>((ref, projectId) {
  final tasks = ref.watch(tasksProvider(projectId)).value ?? const <Task>[];
  final filters = ref.watch(taskFiltersProvider(projectId));
  final statuses =
      ref.watch(taskStatusesProvider(projectId)).value ?? const <Status>[];
  final members = ref.watch(projectMembersProvider(projectId)).value ??
      const <ProjectMember>[];
  return filters.apply(tasks, statuses: statuses, members: members);
});

/// Контроллер Kanban-доски: загрузка колонок и оптимистичное перемещение.
///
/// При перемещении задача сразу переносится в целевую колонку, а запрос
/// `PATCH /api/v1/tasks/{id}/status` выполняется в фоне. При ошибке состояние
/// доски откатывается, ошибка пробрасывается в UI.
class BoardController extends AsyncNotifier<List<BoardColumn>> {
  BoardController(this.projectId);

  final String projectId;

  @override
  Future<List<BoardColumn>> build() async {
    return ref.read(taskRepositoryProvider).getBoard(projectId);
  }

  List<BoardColumn> get columns => state.value ?? const <BoardColumn>[];

  Future<void> refresh() async {
    state = const AsyncValue<List<BoardColumn>>.loading();
    try {
      final board = await ref.read(taskRepositoryProvider).getBoard(projectId);
      state = AsyncValue.data(board);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Оптимистично переносит задачу в колонку [toStatusId].
  ///
  /// При ошибке откатывает доску к состоянию до переноса и пробрасывает
  /// исключение, чтобы UI мог показать индикацию ошибки.
  Future<Task> moveTask({
    required String taskId,
    required String toStatusId,
  }) async {
    final current = columns;
    final previous = _cloneColumns(current);
    final located = _locateTask(current, taskId);
    if (located == null) {
      throw StateError('Task $taskId not found on board');
    }
    final (fromIndex, taskIndex, task) = located;
    final toIndex = current.indexWhere((c) => c.status.id == toStatusId);
    if (toIndex == -1) {
      throw StateError('Status $toStatusId not found on board');
    }
    if (fromIndex == toIndex) return task;

    final optimisticTask = task.applyUpdate(TaskUpdate(statusId: toStatusId));
    final next = _cloneColumns(current);
    next[fromIndex] = next[fromIndex].copyWith(
      tasks: <Task>[
        for (final item in next[fromIndex].tasks)
          if (item.id != taskId) item,
      ],
    );
    final targetTasks = List<Task>.of(next[toIndex].tasks)..add(optimisticTask);
    next[toIndex] = next[toIndex].copyWith(tasks: targetTasks);
    state = AsyncValue.data(next);

    try {
      final updated = await ref
          .read(taskRepositoryProvider)
          .updateTaskStatus(taskId, toStatusId);
      _replaceTask(updated);
      ref.read(tasksProvider(projectId).notifier).syncTask(updated);
      return updated;
    } catch (_) {
      state = AsyncValue.data(previous);
      rethrow;
    }
  }

  void _replaceTask(Task updated) {
    final current = columns;
    if (current.isEmpty) return;
    final next = <BoardColumn>[];
    var found = false;
    for (final column in current) {
      final without = <Task>[
        for (final task in column.tasks)
          if (task.id != updated.id) task,
      ];
      if (without.length != column.tasks.length) {
        found = true;
      }
      if (column.status.id == updated.statusId) {
        final hasInTarget = without.any((t) => t.id == updated.id);
        next.add(
          column.copyWith(
            tasks: hasInTarget ? without : <Task>[...without, updated],
          ),
        );
      } else {
        next.add(column.copyWith(tasks: without));
      }
    }
    if (found) {
      // Normal case: task was moved out of old column and inserted into new.
    }
    state = AsyncValue.data(next);
  }

  (int, int, Task)? _locateTask(List<BoardColumn> columns, String taskId) {
    for (var i = 0; i < columns.length; i++) {
      final tasks = columns[i].tasks;
      for (var j = 0; j < tasks.length; j++) {
        if (tasks[j].id == taskId) return (i, j, tasks[j]);
      }
    }
    return null;
  }

  List<BoardColumn> _cloneColumns(List<BoardColumn> columns) {
    return <BoardColumn>[
      for (final column in columns)
        column.copyWith(tasks: List<Task>.of(column.tasks)),
    ];
  }
}

final boardProvider =
    AsyncNotifierProvider.family<BoardController, List<BoardColumn>, String>(
  BoardController.new,
);
