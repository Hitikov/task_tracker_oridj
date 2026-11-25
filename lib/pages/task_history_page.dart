import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_error.dart';
import '../models/status.dart';
import '../models/task_status_change.dart';
import '../state/task_history_providers.dart';
import '../state/tasks_providers.dart';

/// Экран истории смены статусов задачи.
///
/// Загружает записи через [taskHistoryProvider] и показывает состояния
/// загрузки, ошибки и пустого списка. Названия статусов берутся из
/// провайдера статусов проекта; для неизвестных id показывается сам id.
class TaskHistoryPage extends ConsumerWidget {
  const TaskHistoryPage({
    super.key,
    required this.taskId,
    required this.projectId,
    this.taskKey,
    this.taskTitle,
  });

  final String taskId;
  final String projectId;
  final String? taskKey;
  final String? taskTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(taskHistoryProvider(taskId));
    final statuses =
        ref.watch(taskStatusesProvider(projectId)).value ?? const <Status>[];
    final statusNames = <String, String>{
      for (final status in statuses) status.id: status.name,
    };
    final subtitle = <String>[
      if (taskKey != null && taskKey!.isNotEmpty) taskKey!,
      if (taskTitle != null && taskTitle!.isNotEmpty) taskTitle!,
    ].join(' — ');

    return Scaffold(
      appBar: AppBar(
        title: const Text('История'),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: () => ref.invalidate(taskHistoryProvider(taskId)),
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (subtitle.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                subtitle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          Expanded(child: _buildBody(context, ref, history, statusNames)),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<TaskStatusChange>> history,
    Map<String, String> statusNames,
  ) {
    if (history.isLoading && !history.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }
    if (history.hasError && !history.hasValue) {
      return _StateView(
        icon: Icons.error_outline,
        title: _errorTextOf(history.error),
        actionLabel: 'Повторить',
        actionIcon: Icons.refresh,
        onAction: () => ref.invalidate(taskHistoryProvider(taskId)),
      );
    }

    final entries = history.value ?? const <TaskStatusChange>[];
    if (entries.isEmpty) {
      return const _StateView(
        icon: Icons.history,
        title: 'История пуста',
        subtitle: 'Смены статусов пока не зафиксированы.',
      );
    }

    return ListView.separated(
      key: const Key('task-history-list'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: entries.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final change = entries[index];
        final from = _statusName(change.fromStatusId, statusNames);
        final to = _statusName(change.toStatusId, statusNames);
        return ListTile(
          key: const Key('task-history-item'),
          leading: const Icon(Icons.swap_horiz),
          title: Text('$from → $to'),
          subtitle: Text(
            '${change.changedBy ?? '—'} · ${formatChangedAt(change.changedAt)}',
          ),
        );
      },
    );
  }
}

/// Имя статуса по id; для неизвестного id возвращается сам id.
String _statusName(String? id, Map<String, String> statusNames) {
  if (id == null || id.isEmpty) return '—';
  return statusNames[id] ?? id;
}

/// Дата и время изменения в локальном времени: `dd.MM.yyyy HH:mm`.
String formatChangedAt(DateTime value) {
  final local = value.toLocal();
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${twoDigits(local.day)}.${twoDigits(local.month)}.${local.year} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}

String _errorTextOf(Object? error) {
  if (error is ApiException) return error.message;
  return 'Ошибка. Проверьте данные и сеть.';
}

class _StateView extends StatelessWidget {
  const _StateView({
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

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
            Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onAction,
                icon: Icon(actionIcon ?? Icons.refresh),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
