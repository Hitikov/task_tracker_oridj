import 'status.dart';
import 'task.dart';

/// Колонка Kanban-доски: статус проекта и задачи в этом статусе.
///
/// Контракт: `GET /api/v1/projects/{id}/board`
/// → `[{status: Status, tasks: Task[]}]`.
class BoardColumn {
  const BoardColumn({required this.status, required this.tasks});

  factory BoardColumn.fromJson(Map<String, dynamic> json) {
    final statusJson = json['status'] as Map<String, dynamic>? ?? const {};
    final tasksJson = json['tasks'] as List<dynamic>? ?? const [];
    return BoardColumn(
      status: Status.fromJson(statusJson),
      tasks: [
        for (final entry in tasksJson)
          Task.fromJson(entry as Map<String, dynamic>),
      ],
    );
  }

  final Status status;
  final List<Task> tasks;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'status': status.toJson(),
        'tasks': [for (final task in tasks) task.toJson()],
      };

  BoardColumn copyWith({Status? status, List<Task>? tasks}) {
    return BoardColumn(
      status: status ?? this.status,
      tasks: tasks ?? this.tasks,
    );
  }

  @override
  String toString() => 'BoardColumn(${status.name}, ${tasks.length} tasks)';
}
