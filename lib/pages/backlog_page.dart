import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_error.dart';
import '../models/project.dart';
import '../models/project_member.dart';
import '../models/status.dart';
import '../models/task.dart';
import '../models/task_create.dart';
import '../models/task_filters.dart';
import '../models/task_type.dart';
import '../state/tasks_providers.dart';
import 'kanban_page.dart';

/// Экран Backlog проекта: список задач с фильтрами, сортировкой,
/// созданием, редактированием и удалением.
class BacklogPage extends ConsumerStatefulWidget {
  const BacklogPage({super.key, required this.project});

  final Project project;

  @override
  ConsumerState<BacklogPage> createState() => _BacklogPageState();
}

class _BacklogPageState extends ConsumerState<BacklogPage> {
  @override
  Widget build(BuildContext context) {
    final projectId = widget.project.id;

    final tasksState = ref.watch(tasksProvider(projectId));
    final tasks = ref.watch(filteredTasksProvider(projectId));
    final statuses =
        ref.watch(taskStatusesProvider(projectId)).value ?? const <Status>[];
    final members = ref.watch(projectMembersProvider(projectId)).value ??
        const <ProjectMember>[];

    final statusById = <String, Status>{
      for (final status in statuses) status.id: status,
    };
    final memberById = <String, ProjectMember>{
      for (final member in members) member.userId: member,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text('Backlog — ${widget.project.key}'),
        actions: [
          IconButton(
            tooltip: 'Kanban',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => KanbanPage(project: widget.project),
              ),
            ),
            icon: const Icon(Icons.view_kanban_outlined),
          ),
          IconButton(
            tooltip: 'Обновить',
            onPressed: () =>
                ref.read(tasksProvider(projectId).notifier).refresh(),
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openTaskForm(),
        icon: const Icon(Icons.add),
        label: const Text('Задача'),
      ),
      body: Column(
        children: [
          _FilterBar(projectId: projectId),
          Expanded(
              child: _buildBody(
                  context, tasksState, tasks, statusById, memberById)),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AsyncValue<List<Task>> tasksState,
    List<Task> tasks,
    Map<String, Status> statusById,
    Map<String, ProjectMember> memberById,
  ) {
    if (tasksState.isLoading && tasksState.value == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (tasksState.hasError && tasksState.value == null) {
      return _ErrorCard(
        message: _errorTextOf(tasksState.error),
        onRetry: () =>
            ref.read(tasksProvider(widget.project.id).notifier).refresh(),
      );
    }

    if (tasks.isEmpty) {
      return _EmptyState(
        hasTasks: (tasksState.value ?? const <Task>[]).isNotEmpty,
        onCreate: () => _openTaskForm(),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return _TaskTile(
          task: task,
          statusName: statusById[task.statusId]?.name ?? task.statusId,
          assigneeName: _assigneeName(task.assigneeId, memberById),
          onEdit: () => _openTaskForm(task: task),
          onDelete: () => _confirmDelete(task),
        );
      },
    );
  }

  String _assigneeName(
    String? assigneeId,
    Map<String, ProjectMember> memberById,
  ) {
    if (assigneeId == null) return '—';
    return memberById[assigneeId]?.name ?? assigneeId;
  }

  Future<void> _openTaskForm({Task? task}) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => TaskFormDialog(project: widget.project, task: task),
    );
    if (changed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(task == null ? 'Задача создана' : 'Задача обновлена'),
        ),
      );
    }
  }

  Future<void> _confirmDelete(Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить задачу?'),
        content: Text('«${task.title}» (${task.key}) будет удалена.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref.read(tasksProvider(widget.project.id).notifier).deleteTask(
            task.id,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${task.key} удалена')),
      );
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorTextOf(error))),
      );
    }
  }
}

/// Панель поиска, фильтров и сортировки.
class _FilterBar extends ConsumerStatefulWidget {
  const _FilterBar({required this.projectId});

  final String projectId;

  @override
  ConsumerState<_FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends ConsumerState<_FilterBar> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _update(TaskFilters next) {
    ref.read(taskFiltersProvider(widget.projectId).notifier).state = next;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filters = ref.watch(taskFiltersProvider(widget.projectId));
    final statuses = ref.watch(taskStatusesProvider(widget.projectId)).value ??
        const <Status>[];
    final types = ref.watch(taskTypesProvider(widget.projectId)).value ??
        const <TaskType>[];
    final members = ref.watch(projectMembersProvider(widget.projectId)).value ??
        const <ProjectMember>[];

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Поиск по номеру или названию',
                prefixIcon: Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => _update(filters.copyWith(search: value)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 170,
                  child: DropdownButton<TaskSortField>(
                    key: const Key('sort-field'),
                    value: filters.sortField,
                    isExpanded: true,
                    items: [
                      for (final field in TaskSortField.values)
                        DropdownMenuItem(
                          value: field,
                          child: Text(field.label),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        _update(filters.copyWith(sortField: value));
                      }
                    },
                  ),
                ),
                IconButton(
                  tooltip:
                      filters.sortAscending ? 'По возрастанию' : 'По убыванию',
                  onPressed: () => _update(
                    filters.copyWith(sortAscending: !filters.sortAscending),
                  ),
                  icon: Icon(
                    filters.sortAscending
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: DropdownButton<String?>(
                    key: const Key('status-filter'),
                    value: filters.statusId,
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Все статусы'),
                      ),
                      for (final status in statuses)
                        DropdownMenuItem<String?>(
                          value: status.id,
                          child: Text(status.name),
                        ),
                    ],
                    onChanged: (value) =>
                        _update(filters.copyWith(statusId: value)),
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: DropdownButton<TaskKind?>(
                    key: const Key('kind-filter'),
                    value: filters.kind,
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<TaskKind?>(
                        value: null,
                        child: Text('Все виды'),
                      ),
                      for (final kind in TaskKind.values)
                        DropdownMenuItem<TaskKind?>(
                          value: kind,
                          child: Text(kind.label),
                        ),
                    ],
                    onChanged: (value) =>
                        _update(filters.copyWith(kind: value)),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: DropdownButton<TaskPriority?>(
                    key: const Key('priority-filter'),
                    value: filters.priority,
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<TaskPriority?>(
                        value: null,
                        child: Text('Любой приоритет'),
                      ),
                      for (final priority in TaskPriority.values)
                        DropdownMenuItem<TaskPriority?>(
                          value: priority,
                          child: Text(priority.label),
                        ),
                    ],
                    onChanged: (value) =>
                        _update(filters.copyWith(priority: value)),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: DropdownButton<String?>(
                    key: const Key('assignee-filter'),
                    value: filters.assigneeId,
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Все исполнители'),
                      ),
                      for (final member in members)
                        DropdownMenuItem<String?>(
                          value: member.userId,
                          child: Text(member.name),
                        ),
                    ],
                    onChanged: (value) =>
                        _update(filters.copyWith(assigneeId: value)),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: DropdownButton<String?>(
                    key: const Key('type-filter'),
                    value: filters.typeId,
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Все типы'),
                      ),
                      for (final type in types)
                        DropdownMenuItem<String?>(
                          value: type.id,
                          child: Text(type.name),
                        ),
                    ],
                    onChanged: (value) =>
                        _update(filters.copyWith(typeId: value)),
                  ),
                ),
                if (!filters.isEmpty)
                  IconButton(
                    tooltip: 'Сбросить фильтры',
                    onPressed: () {
                      _searchController.clear();
                      _update(filters.cleared());
                    },
                    icon: const Icon(Icons.filter_alt_off_outlined),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.statusName,
    required this.assigneeName,
    required this.onEdit,
    required this.onDelete,
  });

  final Task task;
  final String statusName;
  final String assigneeName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 84,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.key,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      task.kind.label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task.title, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _Chip(
                          icon: Icons.flag_outlined,
                          label: statusName,
                        ),
                        _Chip(
                          icon: Icons.person_outline,
                          label: assigneeName,
                        ),
                        _Chip(
                          icon: Icons.priority_high,
                          label: task.priority.label,
                        ),
                        _Chip(
                          icon: Icons.event_outlined,
                          label: formatDueDate(task.dueDate),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Редактировать',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Удалить',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasTasks, required this.onCreate});

  /// true, если задачи есть, но не прошли фильтр.
  final bool hasTasks;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasTasks ? Icons.filter_alt_off_outlined : Icons.checklist,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            hasTasks ? 'Ничего не найдено' : 'Задач пока нет',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            hasTasks
                ? 'Попробуйте изменить фильтры или поисковый запрос.'
                : 'Создайте первую задачу — номер и статус назначит сервер.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (!hasTasks) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Создать задачу'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Форма создания/редактирования задачи.
class TaskFormDialog extends ConsumerStatefulWidget {
  const TaskFormDialog({super.key, required this.project, this.task});

  final Project project;

  /// null — создание; иначе редактирование.
  final Task? task;

  @override
  ConsumerState<TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends ConsumerState<TaskFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  late TaskKind _kind;
  String? _typeId;
  String? _statusId;
  TaskPriority _priority = TaskPriority.medium;
  String? _assigneeId;
  DateTime? _dueDate;
  String? _parentId;
  String? _errorText;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _titleController.text = task?.title ?? '';
    _descriptionController.text = task?.description ?? '';
    _kind = task?.kind ?? TaskKind.task;
    _priority = task?.priority ?? TaskPriority.medium;
    _assigneeId = task?.assigneeId;
    _dueDate = task?.dueDate;
    _parentId = task?.parentId;
    _statusId = task?.statusId;
    _typeId = task?.typeId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  List<Task> get _eligibleParents {
    final tasks =
        ref.read(tasksProvider(widget.project.id)).value ?? const <Task>[];
    switch (_kind) {
      case TaskKind.epic:
        return const <Task>[];
      case TaskKind.task:
        return tasks.where((task) => task.kind == TaskKind.epic).toList();
      case TaskKind.subtask:
        return tasks.where((task) => task.kind == TaskKind.task).toList();
    }
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      helpText: 'Выберите дедлайн',
    );
    if (picked != null) {
      // Дата без времени означала бы полночь — сервер счёл бы сегодняшний
      // дедлайн уже просроченным. Используем конец выбранного дня.
      setState(
        () => _dueDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          23,
          59,
          59,
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final types = ref.read(taskTypesProvider(widget.project.id)).value ??
        const <TaskType>[];
    final statuses = ref.read(taskStatusesProvider(widget.project.id)).value ??
        const <Status>[];
    final typeId = types.any((type) => type.id == _typeId)
        ? _typeId
        : (types.isNotEmpty ? types.first.id : null);
    final statusId = statuses.any((status) => status.id == _statusId)
        ? _statusId
        : (statuses.isNotEmpty ? statuses.first.id : null);

    if (typeId == null) {
      setState(() => _errorText = 'Выберите тип задачи');
      return;
    }
    if (_kind == TaskKind.subtask &&
        (_parentId == null || _parentId!.isEmpty)) {
      setState(() => _errorText = 'Подзадача должна иметь родительскую задачу');
      return;
    }

    setState(() {
      _errorText = null;
      _submitting = true;
    });

    try {
      final notifier = ref.read(
        tasksProvider(widget.project.id).notifier,
      );
      if (widget.task == null) {
        await notifier.createTask(
          TaskCreate(
            kind: _kind,
            typeId: typeId,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            priority: _priority,
            assigneeId: _assigneeId,
            dueDate: _dueDate,
            parentId: _parentId,
          ),
        );
      } else {
        await notifier.updateTask(
          widget.task!.id,
          TaskUpdate(
            kind: _kind,
            typeId: typeId,
            statusId: statusId,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            priority: _priority,
            assigneeId: _assigneeId,
            clearAssignee: _assigneeId == null,
            dueDate: _dueDate,
            clearDueDate: _dueDate == null,
            parentId: _parentId,
          ),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = _errorTextOf(error);
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final projectId = widget.project.id;

    final typesAsync = ref.watch(taskTypesProvider(projectId));
    final statusesAsync = ref.watch(taskStatusesProvider(projectId));
    final members = ref.watch(projectMembersProvider(projectId)).value ??
        const <ProjectMember>[];

    if (typesAsync.isLoading || statusesAsync.isLoading) {
      return const AlertDialog(
        content: SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (typesAsync.hasError) {
      return AlertDialog(
        title: const Text('Ошибка загрузки типов'),
        content: Text(_errorTextOf(typesAsync.error)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Закрыть'),
          ),
        ],
      );
    }

    final types = typesAsync.value ?? const <TaskType>[];
    final statuses = statusesAsync.value ?? const <Status>[];
    final effectiveTypeId = types.any((type) => type.id == _typeId)
        ? _typeId
        : (types.isNotEmpty ? types.first.id : null);
    final effectiveStatusId = statuses.any((status) => status.id == _statusId)
        ? _statusId
        : (statuses.isNotEmpty ? statuses.first.id : null);
    final effectiveAssigneeId =
        members.any((member) => member.userId == _assigneeId)
            ? _assigneeId
            : null;
    final eligibleParents = _eligibleParents;
    final effectiveParentId =
        eligibleParents.any((task) => task.id == _parentId) ? _parentId : null;

    return AlertDialog(
      title:
          Text(widget.task == null ? 'Новая задача' : 'Редактировать задачу'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButton<TaskKind>(
                  key: const Key('task-kind'),
                  value: _kind,
                  isExpanded: true,
                  items: [
                    for (final kind in TaskKind.values)
                      DropdownMenuItem(value: kind, child: Text(kind.label)),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _kind = value;
                      _parentId = null;
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButton<String>(
                  key: const Key('task-type'),
                  value: effectiveTypeId,
                  isExpanded: true,
                  hint: const Text('Тип задачи'),
                  items: [
                    for (final type in types)
                      DropdownMenuItem(value: type.id, child: Text(type.name)),
                  ],
                  onChanged: (value) => setState(() => _typeId = value),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _titleController,
                  textInputAction: TextInputAction.next,
                  validator: _validateTitle,
                  decoration: const InputDecoration(
                    labelText: 'Название',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  textInputAction: TextInputAction.newline,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Описание',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButton<TaskPriority>(
                        key: const Key('task-priority'),
                        value: _priority,
                        isExpanded: true,
                        items: [
                          for (final priority in TaskPriority.values)
                            DropdownMenuItem(
                              value: priority,
                              child: Text(priority.label),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _priority = value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: _pickDueDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Дедлайн',
                            border: OutlineInputBorder(),
                          ),
                          child: Text(formatDueDate(_dueDate)),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Очистить дедлайн',
                      onPressed: _dueDate == null
                          ? null
                          : () => setState(() => _dueDate = null),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButton<String?>(
                  key: const Key('task-assignee'),
                  value: effectiveAssigneeId,
                  isExpanded: true,
                  hint: const Text('Не назначена'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Не назначена'),
                    ),
                    for (final member in members)
                      DropdownMenuItem<String?>(
                        value: member.userId,
                        child: Text(member.name),
                      ),
                  ],
                  onChanged: (value) => setState(() => _assigneeId = value),
                ),
                if (widget.task != null) ...[
                  const SizedBox(height: 12),
                  DropdownButton<String>(
                    key: const Key('task-status'),
                    value: effectiveStatusId,
                    isExpanded: true,
                    items: [
                      for (final status in statuses)
                        DropdownMenuItem(
                          value: status.id,
                          child: Text(status.name),
                        ),
                    ],
                    onChanged: (value) => setState(() => _statusId = value),
                  ),
                ],
                if (_kind != TaskKind.epic) ...[
                  const SizedBox(height: 12),
                  DropdownButton<String?>(
                    key: const Key('task-parent'),
                    value: effectiveParentId,
                    isExpanded: true,
                    hint: Text(
                      _kind == TaskKind.subtask
                          ? 'Родительская задача (обязательно)'
                          : 'Родительский эпик (необязательно)',
                    ),
                    items: [
                      if (_kind == TaskKind.task)
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Без родителя'),
                        ),
                      for (final parent in eligibleParents)
                        DropdownMenuItem<String?>(
                          value: parent.id,
                          child: Text('${parent.key} — ${parent.title}'),
                        ),
                    ],
                    onChanged: (value) => setState(() => _parentId = value),
                  ),
                ],
                if (_errorText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _errorText!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: const Text('Сохранить'),
        ),
      ],
    );
  }

  String? _validateTitle(String? value) {
    final title = value?.trim() ?? '';
    if (title.isEmpty) return 'Введите название';
    if (title.length > 200) return 'Максимум 200 символов';
    return null;
  }
}

/// `dd.MM.yyyy` для дедлайна; `—`, если дедлайна нет.
String formatDueDate(DateTime? date) {
  if (date == null) return '—';
  final local = date.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day.$month.${local.year}';
}

String _errorTextOf(Object? error) {
  if (error is ApiException) {
    return error.message;
  }
  return 'Ошибка. Проверьте данные и сеть.';
}
