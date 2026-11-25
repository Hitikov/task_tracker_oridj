import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'update_service.dart';

/// Показывает диалог с доступным обновлением.
///
/// [onInstall] передаётся только когда файл уже скачан: установка начинается
/// исключительно после нажатия кнопки пользователем.
Future<void> showUpdateDialog(
  BuildContext context,
  UpdateInfo update, {
  Future<void> Function()? onInstall,
}) async {
  final theme = Theme.of(context);
  final target = Uri.parse(update.downloadUrl ?? update.releaseUrl);

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: Icon(Icons.system_update, color: theme.colorScheme.primary),
      title: const Text('Доступно обновление'),
      content: Text(
        'Версия ${update.version} уже доступна на GitHub. '
        'Обновите приложение, чтобы получить последние исправления.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Позже'),
        ),
        FilledButton.icon(
          onPressed: () async {
            Navigator.of(dialogContext).pop();
            if (onInstall != null) {
              await onInstall();
            } else {
              await launchUrl(target, mode: LaunchMode.externalApplication);
            }
          },
          icon: const Icon(Icons.system_update_alt),
          label: Text(onInstall != null ? 'Установить' : 'Скачать'),
        ),
      ],
    ),
  );
}
