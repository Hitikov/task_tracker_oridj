import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_error.dart';
import '../models/board_column.dart';
import '../models/project.dart';
import '../models/project_member.dart';
import '../models/task.dart';
import '../state/tasks_providers.dart';
import 'backlog_page.dart';

/// Kanban-доска проекта: колонки по статусам и перенос задач drag & drop.
class KanbanPage extends ConsumerWidget {
  const KanbanPage({super.key, required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectId = project.id;
    final board = ref.watch(boardProvider(projectId));
    final members = ref.watch(projectMembersProvider(projectId)).value ??
        const <ProjectMember>[];
    final memberById = <String, ProjectMember>{
      for (final member in members) member.userId: member,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text('Kanban — ${project.key}'),
        actions: [
          IconButton(
            tooltip: 'Backlog',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => BacklogPage(project: project),
              ),
            ),
            icon: const Icon(Icons.view_list_outlined),
          ),
          IconButton(
            tooltip: 'Обновить',
            onPressed: () =>
                ref.read(boardProvider(projectId).notifier).refresh(),
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(context, ref, board, memberById),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<BoardColumn>> board,
    Map<String, ProjectMember> memberById,
  ) {
    if (board.isLoading && board.value == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (board.hasError && board.value == null) {
      return _ErrorState(
        message: _errorTextOf(board.error),
        onRetry: () => ref.read(boardProvider(project.id).notifier).refresh(),
      );
    }
    final columns = board.value ?? const <BoardColumn>[];
    if (columns.isEmpty) {
      return const _EmptyBoard();
    }
    return _BoardView(
      project: project,
      columns: columns,
      memberById: memberById,
    );
  }
}

class _BoardView extends ConsumerWidget {
  const _BoardView({
    required this.project,
    required this.columns,
    required this.memberById,
  });

  final Project project;
  final List<BoardColumn> columns;
  final Map<String, ProjectMember> memberById;

  Future<void> _moveTask(
    BuildContext context,
    WidgetRef ref,
    String taskId,
    String toStatusId,
  ) async {
    try {
      await ref.read(boardProvider(project.id).notifier).moveTask(
            taskId: taskId,
            toStatusId: toStatusId,
          );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorTextOf(error)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnWidth = constraints.maxWidth < 720
            // На телефоне колонка занимает почти всю ширину экрана —
            // горизонтальная прокрутка остаётся только между статусами.
            ? (constraints.maxWidth - 24).clamp(240.0, 420.0).toDouble()
            : (constraints.maxWidth / columns.length)
                .clamp(280.0, 360.0)
                .toDouble();
        final boardHeight =
            constraints.maxHeight.isFinite && constraints.maxHeight > 24
                ? constraints.maxHeight - 24
                : 560.0;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final column in columns)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: SizedBox(
                    width: columnWidth,
                    height: boardHeight,
                    child: _StatusColumn(
                      column: column,
                      memberById: memberById,
                      onAcceptTask: (taskId) => _moveTask(
                        context,
                        ref,
                        taskId,
                        column.status.id,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusColumn extends StatelessWidget {
  const _StatusColumn({
    required this.column,
    required this.memberById,
    required this.onAcceptTask,
  });

  final BoardColumn column;
  final Map<String, ProjectMember> memberById;
  final Future<void> Function(String taskId) onAcceptTask;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = column.status;
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) =>
          !column.tasks.any((task) => task.id == details.data),
      onAcceptWithDetails: (details) => onAcceptTask(details.data),
      builder: (context, candidateData, rejectedData) {
        final isActive = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: isActive
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
                : theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        status.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${column.tasks.length}',
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: column.tasks.isEmpty
                    ? _EmptyColumn(isActive: isActive)
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: column.tasks.length,
                        itemBuilder: (context, index) {
                          final task = column.tasks[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _TaskCard(
                              task: task,
                              assigneeName:
                                  _assigneeName(task.assigneeId, memberById),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task, required this.assigneeName});

  final Task task;
  final String assigneeName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final card = Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
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
              task.title,
              style: theme.textTheme.bodyMedium,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _InfoChip(
                    icon: Icons.category_outlined, label: task.kind.label),
                _InfoChip(icon: Icons.person_outline, label: assigneeName),
                _InfoChip(
                  icon: Icons.priority_high,
                  label: task.priority.label,
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return Draggable<String>(
      data: task.id,
      feedback: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Opacity(opacity: 0.95, child: card),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: card),
      child: card,
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

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
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyColumn extends StatelessWidget {
  const _EmptyColumn({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          isActive ? 'Отпустите, чтобы перенести' : 'Нет задач',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _EmptyBoard extends StatelessWidget {
  const _EmptyBoard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.view_kanban_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text('Колонки не найдены', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Настройте статусы проекта, чтобы начать работу на доске.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

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
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
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

String _assigneeName(
    String? assigneeId, Map<String, ProjectMember> memberById) {
  if (assigneeId == null) return 'Не назначен';
  return memberById[assigneeId]?.name ?? assigneeId;
}

String _errorTextOf(Object? error) {
  if (error is ApiException) return error.message;
  return 'Ошибка. Проверьте данные и сеть.';
}
