import 'package:flutter/material.dart';

import '../pages/home_section.dart';

/// Боковое меню приложения.
///
/// Используется в двух режимах: как постоянная панель на широких экранах
/// и как содержимое [Drawer] на узких.
class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.login,
    required this.selectedSection,
    required this.onSectionSelected,
    required this.onDbDemoSelected,
    required this.onLogout,
    this.closeOnSelect = false,
  });

  final String login;
  final HomeSection selectedSection;
  final ValueChanged<HomeSection> onSectionSelected;
  final VoidCallback onDbDemoSelected;
  final VoidCallback onLogout;

  /// Если меню открыто в [Drawer], после выбора его нужно закрыть.
  final bool closeOnSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = login.trim().isEmpty
        ? '?'
        : login.trim().characters.first.toUpperCase();

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.task_alt,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Arij',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      Text(
                        'Трекер задач',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    for (final section in HomeSection.values)
                      _sectionTile(context, section),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(),
                    ),
                    Text(
                      'Сервис',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ListTile(
                      leading: const Icon(Icons.storage_outlined),
                      title: const Text('Демо работы с БД'),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onTap: () => _afterDrawer(context, onDbDemoSelected),
                    ),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                  child: Text(initial),
                ),
                title: Text(
                  login,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: const Text('Демо-пользователь'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.logout,
                  color: theme.colorScheme.error,
                ),
                title: Text(
                  'Выйти',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () => _afterDrawer(context, onLogout),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTile(BuildContext context, HomeSection section) {
    final theme = Theme.of(context);
    final isSelected = section == selectedSection;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: Icon(section.icon),
        title: Text(section.title),
        selected: isSelected,
        selectedColor: theme.colorScheme.onPrimaryContainer,
        selectedTileColor: theme.colorScheme.primaryContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        onTap: () {
          onSectionSelected(section);
          if (closeOnSelect) {
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }

  /// Выполняет действие после закрытия [Drawer], если меню в нём открыто.
  void _afterDrawer(BuildContext context, VoidCallback action) {
    if (!closeOnSelect) {
      action();
      return;
    }

    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) => action());
  }
}
