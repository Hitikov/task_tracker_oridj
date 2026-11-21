import '../api/api_client.dart';
import '../models/board_column.dart';
import '../models/project_member.dart';
import '../models/status.dart';
import '../models/task.dart';
import '../models/task_create.dart';
import '../models/task_filters.dart';
import '../models/task_type.dart';

/// Репозиторий задач, типов, статусов и участников проекта.
///
/// Тонкий слой над [ApiClient]: только маршруты и маппинг схем.
/// В тестах подменяется [ApiClient] (например, [FakeApiClient]).
class TaskRepository {
  TaskRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  /// `GET /api/v1/projects/{projectId}/tasks` с опциональными фильтрами.
  Future<List<Task>> listTasks(
    String projectId, {
    TaskFilters? filters,
  }) async {
    final data = await _api.getProjectTasks(
      projectId,
      query: filters?.toQuery(),
    );
    return [for (final entry in data) Task.fromJson(entry)];
  }

  /// `POST /api/v1/projects/{projectId}/tasks`.
  ///
  /// Номер и статус возвращает сервер.
  Future<Task> createTask(String projectId, TaskCreate create) async {
    final data = await _api.createProjectTask(
      projectId,
      body: create.toJson(),
    );
    return Task.fromJson(data);
  }

  /// `GET /api/v1/tasks/{id}`.
  Future<Task> getTask(String id) async {
    return Task.fromJson(await _api.getTask(id));
  }

  /// `PATCH /api/v1/tasks/{id}`.
  Future<Task> updateTask(String id, TaskUpdate update) async {
    final data = await _api.patchTask(id, body: update.toJson());
    return Task.fromJson(data);
  }

  /// `DELETE /api/v1/tasks/{id}`.
  Future<void> deleteTask(String id) async {
    await _api.deleteTask(id);
  }

  /// `GET /api/v1/projects/{projectId}/task-types`.
  Future<List<TaskType>> listTaskTypes(String projectId) async {
    final data = await _api.getProjectTaskTypes(projectId);
    return [for (final entry in data) TaskType.fromJson(entry)];
  }

  /// `GET /api/v1/projects/{projectId}/statuses`.
  Future<List<Status>> listStatuses(String projectId) async {
    final data = await _api.getProjectStatuses(projectId);
    return [for (final entry in data) Status.fromJson(entry)];
  }

  /// `GET /api/v1/projects/{projectId}/members`.
  Future<List<ProjectMember>> listMembers(String projectId) async {
    final data = await _api.getProjectMembers(projectId);
    return [for (final entry in data) ProjectMember.fromJson(entry)];
  }

  /// `GET /api/v1/projects/{projectId}/board`.
  Future<List<BoardColumn>> getBoard(String projectId) async {
    final data = await _api.getBoard(projectId);
    return [for (final entry in data) BoardColumn.fromJson(entry)];
  }

  /// `PATCH /api/v1/tasks/{taskId}/status`.
  Future<Task> updateTaskStatus(String taskId, String statusId) async {
    final data = await _api.updateTaskStatus(taskId, statusId);
    return Task.fromJson(data);
  }
}
