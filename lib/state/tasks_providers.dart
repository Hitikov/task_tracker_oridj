import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

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
