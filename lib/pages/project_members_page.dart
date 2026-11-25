import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_error.dart';
import '../models/project.dart';
import '../models/project_member.dart';
import '../state/auth_providers.dart';
import '../state/members_providers.dart';
import '../state/projects_providers.dart';

class ProjectMembersPage extends ConsumerStatefulWidget {
  const ProjectMembersPage({super.key, required this.project});

  final Project project;

  @override
  ConsumerState<ProjectMembersPage> createState() => _ProjectMembersPageState();
}

class _ProjectMembersPageState extends ConsumerState<ProjectMembersPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isAdding = false;
  String? _removingUserId;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);
    final membersState = ref.watch(membersProvider(widget.project.id));
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    final selectedId = ref.watch(selectedProjectIdProvider);
    final user = session.value;
    final members = membersState.value ?? const <ProjectMember>[];
    final isOwner = user != null &&
        (user.id == widget.project.ownerId ||
            members.any(
              (member) =>
                  member.userId == user.id &&
                  member.role.toLowerCase() == 'owner',
            ));

    if (session.hasError && session.value == null) {
      return _MessageState(
        icon: Icons.error_outline,
        title: 'Сессия потеряна',
        message:
            _errorTextOf(session.error, fallback: 'Выйдите и войдите снова.'),
      );
    }

    if (membersState.isLoading && membersState.value == null) {
      return const _LoadingState();
    }

    if (membersState.hasError && membersState.value == null) {
      return _MessageState(
        icon: Icons.error_outline,
        title: 'Ошибка загрузки участников',
        message: _errorTextOf(
          membersState.error,
          fallback: 'Проверьте соединение и попробуйте снова.',
        ),
        actionLabel: 'Повторить',
        onAction: () =>
            ref.read(membersProvider(widget.project.id).notifier).refresh(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProjectHeader(
          project: widget.project,
          projects: projects,
          selectedId: selectedId ?? widget.project.id,
          onProjectChanged: (id) {
            ref.read(selectedProjectIdProvider.notifier).state = id;
          },
        ),
        if (isOwner)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Form(
              key: _formKey,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      validator: _validateEmail,
                      onFieldSubmitted: (_) => _addMember(context),
                      decoration: const InputDecoration(
                        labelText: 'Email нового участника',
                        hintText: 'user@example.com',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _isAdding ? null : () => _addMember(context),
                    icon: _isAdding
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.person_add_outlined),
                    label: const Text('Добавить'),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: members.isEmpty
              ? const _EmptyMembers()
              : ListView.builder(
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    return _MemberTile(
                      member: member,
                      canRemove: isOwner &&
                          member.userId != user.id &&
                          member.role.toLowerCase() != 'owner',
                      isRemoving: _removingUserId == member.userId,
                      onRemove: () => _removeMember(context, member),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Введите email';
    final pattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!pattern.hasMatch(email)) return 'Некорректный email';
    return null;
  }

  Future<void> _addMember(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text.trim();
    setState(() => _isAdding = true);
    try {
      await ref.read(membersProvider(widget.project.id).notifier).addMember(
            email: email,
          );
      if (!context.mounted) return;
      _emailController.clear();
      _showSnackBar(context, 'Участник добавлен');
    } on Exception catch (error) {
      if (!context.mounted) return;
      _showSnackBar(
        context,
        _errorTextOf(error, fallback: 'Не удалось добавить участника.'),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<void> _removeMember(BuildContext context, ProjectMember member) async {
    setState(() => _removingUserId = member.userId);
    try {
      await ref
          .read(membersProvider(widget.project.id).notifier)
          .removeMember(member.userId);
      if (!context.mounted) return;
      _showSnackBar(context, 'Участник удалён');
    } on Exception catch (error) {
      if (!context.mounted) return;
      _showSnackBar(
        context,
        _errorTextOf(error, fallback: 'Не удалось удалить участника.'),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _removingUserId = null);
    }
  }

  void _showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? Theme.of(context).colorScheme.errorContainer : null,
      ),
    );
  }
}

class _ProjectHeader extends StatelessWidget {
  const _ProjectHeader({
    required this.project,
    required this.projects,
    required this.selectedId,
    required this.onProjectChanged,
  });

  final Project project;
  final List<Project> projects;
  final String selectedId;
  final ValueChanged<String> onProjectChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(Icons.group_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Участники проекта ${project.key}',
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  project.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (projects.length > 1)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: DropdownButton<String>(
                value: projects.any((item) => item.id == selectedId)
                    ? selectedId
                    : null,
                hint: const Text('Проект'),
                isDense: true,
                isExpanded: true,
                underline: const SizedBox.shrink(),
                items: [
                  for (final item in projects)
                    DropdownMenuItem<String>(
                      value: item.id,
                      child: Text(
                        item.key,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (id) {
                  if (id != null) onProjectChanged(id);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.canRemove,
    required this.isRemoving,
    required this.onRemove,
  });

  final ProjectMember member;
  final bool canRemove;
  final bool isRemoving;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = member.name.isNotEmpty ? member.name : member.email;
    final initial =
        name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundColor: theme.colorScheme.onPrimaryContainer,
        child: Text(initial),
      ),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle:
          Text(member.email, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Chip(
            visualDensity: VisualDensity.compact,
            label: Text(_roleLabel(member.role)),
          ),
          if (canRemove)
            IconButton(
              tooltip: 'Удалить участника',
              onPressed: isRemoving ? null : onRemove,
              icon: isRemoving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.delete_outline,
                      color: theme.colorScheme.error,
                    ),
            ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(
            'Загрузка участников…',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyMembers extends StatelessWidget {
  const _EmptyMembers();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text('Участников пока нет', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Добавьте первого участника по email.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
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
            Icon(icon, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh),
                label: Text(actionLabel ?? 'Повторить'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _roleLabel(String role) {
  return switch (role.toLowerCase()) {
    'owner' => 'Владелец',
    'member' => 'Участник',
    _ => role,
  };
}

String _errorTextOf(Object? error, {required String fallback}) {
  if (error is ApiException) return error.message;
  return fallback;
}
