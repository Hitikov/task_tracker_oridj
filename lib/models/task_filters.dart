import '../models/project_member.dart';
import '../models/status.dart';
import '../models/task.dart';

/// Поле сортировки бэклога.
enum TaskSortField {
  number('Номер'),
  title('Название'),
  status('Статус'),
  assignee('Исполнитель'),
  priority('Приоритет'),
  dueDate('Дедлайн');

  const TaskSortField(this.label);

  final String label;
}

/// Фильтры и сортировка списка задач.
///
/// Применяется локально к загруженному списку, а также может быть
/// преобразовано в query-параметры для серверной фильтрации.
class TaskFilters {
  const TaskFilters({
    this.search = '',
    this.kind,
    this.typeId,
    this.statusId,
    this.assigneeId,
    this.priority,
    this.sortField = TaskSortField.number,
    this.sortAscending = true,
  });

  final String search;
  final TaskKind? kind;
  final String? typeId;
  final String? statusId;
  final String? assigneeId;
  final TaskPriority? priority;
  final TaskSortField sortField;
  final bool sortAscending;

  /// true, если ни один фильтр не задан (сортировка не считается).
  bool get isEmpty =>
      search.trim().isEmpty &&
      kind == null &&
      typeId == null &&
      statusId == null &&
      assigneeId == null &&
      priority == null;

  /// Сентинел, означающий «аргумент не передан» (в отличие от `null`,
  /// который сбрасывает фильтр).
  static const Object _unset = Object();

  TaskFilters copyWith({
    Object? search = _unset,
    Object? kind = _unset,
    Object? typeId = _unset,
    Object? statusId = _unset,
    Object? assigneeId = _unset,
    Object? priority = _unset,
    TaskSortField? sortField,
    bool? sortAscending,
  }) {
    return TaskFilters(
      search: search == _unset ? this.search : search as String,
      kind: kind == _unset ? this.kind : kind as TaskKind?,
      typeId: typeId == _unset ? this.typeId : typeId as String?,
      statusId: statusId == _unset ? this.statusId : statusId as String?,
      assigneeId:
          assigneeId == _unset ? this.assigneeId : assigneeId as String?,
      priority: priority == _unset ? this.priority : priority as TaskPriority?,
      sortField: sortField ?? this.sortField,
      sortAscending: sortAscending ?? this.sortAscending,
    );
  }

  /// Сбрасывает фильтры, сохраняя сортировку.
  TaskFilters cleared() =>
      TaskFilters(sortField: sortField, sortAscending: sortAscending);

  /// Query-параметры для `GET /api/v1/projects/{id}/tasks`.
  Map<String, String> toQuery() => <String, String>{
        if (search.trim().isNotEmpty) 'search': search.trim(),
        if (kind != null) 'kind': kind!.wire,
        if (typeId != null) 'typeId': typeId!,
        if (statusId != null) 'statusId': statusId!,
        if (assigneeId != null) 'assigneeId': assigneeId!,
        if (priority != null) 'priority': priority!.wire,
        'sort': sortField.name,
        'order': sortAscending ? 'asc' : 'desc',
      };

  /// Фильтрует и сортирует список задач.
  ///
  /// [statuses] и [members] используются для сортировки по имени статуса и
  /// исполнителя; без них сортировка идёт по идентификаторам.
  List<Task> apply(
    List<Task> tasks, {
    List<Status> statuses = const <Status>[],
    List<ProjectMember> members = const <ProjectMember>[],
  }) {
    final query = search.trim().toLowerCase();
    final filtered = tasks.where((task) {
      if (query.isNotEmpty) {
        final inTitle = task.title.toLowerCase().contains(query);
        final inKey = task.key.toLowerCase().contains(query);
        if (!inTitle && !inKey) return false;
      }
      if (kind != null && task.kind != kind) return false;
      if (typeId != null && task.typeId != typeId) return false;
      if (statusId != null && task.statusId != statusId) return false;
      if (assigneeId != null && task.assigneeId != assigneeId) return false;
      if (priority != null && task.priority != priority) return false;
      return true;
    }).toList();

    final statusById = <String, Status>{for (final s in statuses) s.id: s};
    final memberById = <String, ProjectMember>{
      for (final m in members) m.userId: m,
    };

    int compare(Task a, Task b) {
      final result = switch (sortField) {
        TaskSortField.number => a.number.compareTo(b.number),
        TaskSortField.title => a.title.toLowerCase().compareTo(
              b.title.toLowerCase(),
            ),
        TaskSortField.status =>
          (statusById[a.statusId]?.name ?? a.statusId).toLowerCase().compareTo(
                (statusById[b.statusId]?.name ?? b.statusId).toLowerCase(),
              ),
        TaskSortField.assignee =>
          (memberById[a.assigneeId]?.name ?? a.assigneeId ?? '')
              .toLowerCase()
              .compareTo(
                (memberById[b.assigneeId]?.name ?? b.assigneeId ?? '')
                    .toLowerCase(),
              ),
        TaskSortField.priority => a.priority.index.compareTo(b.priority.index),
        TaskSortField.dueDate => _compareDueDate(a.dueDate, b.dueDate),
      };
      return sortAscending ? result : -result;
    }

    filtered.sort(compare);
    return filtered;
  }
}

int _compareDueDate(DateTime? a, DateTime? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return a.compareTo(b);
}
