import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_error.dart';
import '../models/project.dart';
import '../models/project_create.dart';
import '../state/auth_providers.dart';
import '../state/projects_providers.dart';

/// Экран проектов: список + создание нового проекта
/// (`POST /api/v1/projects`, схема `ProjectCreate`).
class ProjectsPage extends ConsumerWidget {
  const ProjectsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final session = ref.watch(authSessionProvider);

    if (session.hasError) {
      return Center(
        child: Text(
          'Сессия потеряна. Выйдите и войдите снова.',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.error),
        ),
      );
    }

    final projects = ref.watch(projectsProvider);

    if (projects.hasError) {
      return _ErrorCard(message: _errorTextOf(projects.error));
    }

    final list = projects.value ?? const <Project>[];

    return Column(
      children: [
        Expanded(
          child: list.isEmpty
              ? const _EmptyState()
              : ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) => _ProjectTile(
                    project: list[index],
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: () => _showCreateDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Создать проект'),
          ),
        ),
      ],
    );
  }

  void _showCreateDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => const _CreateProjectDialog(),
    );
  }
}

class _ProjectTile extends StatelessWidget {
  const _ProjectTile({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Icon(Icons.folder_outlined, color: theme.colorScheme.primary),
      title: Text(project.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(project.key),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text('Проектов пока нет', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Создайте первый проект — ключ используется в номерах задач.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends ConsumerWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            Text(message),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => ref.read(projectsProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateProjectDialog extends ConsumerStatefulWidget {
  const _CreateProjectDialog();

  @override
  ConsumerState<_CreateProjectDialog> createState() =>
      _CreateProjectDialogState();
}

class _CreateProjectDialogState extends ConsumerState<_CreateProjectDialog> {
  final _formKey = GlobalKey<FormState>();
  final _keyController = TextEditingController();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _keyController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  static final RegExp _keyRegExp = RegExp(r'^[A-Z][A-Z0-9]{1,9}$');

  String? _validateKey(String? value) {
    final key = value?.trim().toUpperCase() ?? '';
    if (key.isEmpty) {
      return 'Введите ключ проекта';
    }
    if (!_keyRegExp.hasMatch(key)) {
      return 'Ключ: 2–10 символов, заглавные буквы и цифры';
    }
    return null;
  }

  String? _validateName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) {
      return 'Введите название';
    }
    if (name.length > 100) {
      return 'Максимум 100 символов';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final description = _descriptionController.text.trim();
    final create = ProjectCreate(
      key: _keyController.text.trim().toUpperCase(),
      name: _nameController.text.trim(),
      description: description.isEmpty ? null : description,
    );

    try {
      await ref.read(projectsProvider.notifier).createProject(create);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(text: 'Проект создан'),
      );
    } on Exception catch (e) {
      setState(() => _errorText = _errorTextOf(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Создать проект'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _keyController,
              textInputAction: TextInputAction.next,
              validator: _validateKey,
              decoration: const InputDecoration(
                labelText: 'Ключ проекта',
                hintText: 'ARIJ',
                border: OutlineInputBorder(),
                helper: SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              validator: _validateName,
              decoration: const InputDecoration(
                labelText: 'Название',
                border: OutlineInputBorder(),
                helper: SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              textInputAction: TextInputAction.done,
              validator: (value) => null,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Описание',
                border: OutlineInputBorder(),
                helper: SizedBox.shrink(),
              ),
            ),
            if (_errorText != null)
              Text(
                _errorText!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Отмена')),
        FilledButton(onPressed: _submit, child: const Text('Создать')),
      ],
    );
  }
}

String _errorTextOf(Object? error) {
  if (error is ApiException) {
    return error.message;
  }
  return 'Ошибка создания проекта. Проверьте данные и сеть.';
}
