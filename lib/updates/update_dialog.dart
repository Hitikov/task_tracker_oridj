import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'update_service.dart';

/// Показывает диалог с доступным обновлением.
Future<void> showUpdateDialog(BuildContext context, UpdateInfo update) async {
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
          onPressed: () {
            Navigator.of(dialogContext).pop();
            launchUrl(target, mode: LaunchMode.externalApplication);
          },
          icon: const Icon(Icons.download),
          label: const Text('Скачать'),
        ),
      ],
    ),
  );
}
