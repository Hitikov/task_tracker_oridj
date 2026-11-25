import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/task_status_change.dart';
import 'auth_providers.dart';

/// История смены статусов задачи: `GET /api/v1/tasks/{taskId}/history`.
///
/// Отдельный провайдер поверх [apiClientProvider]: репозиторий задач не
/// загружает историю, поэтому запрос выполняется через `getTaskHistory`.
/// Состояние — `AsyncValue`: загрузка, ошибка и список записей.
final taskHistoryProvider =
    FutureProvider.family<List<TaskStatusChange>, String>((ref, taskId) async {
  final data = await ref.read(apiClientProvider).getTaskHistory(taskId);
  return <TaskStatusChange>[
    for (final entry in data) TaskStatusChange.fromJson(entry),
  ];
});
