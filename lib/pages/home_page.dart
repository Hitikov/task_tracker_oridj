import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/person_controller.dart';
import '../state/auth_providers.dart';
import '../updates/update_controller.dart';
import '../updates/update_dialog.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/roadmap_view.dart';
import '../widgets/section_placeholder.dart';
import 'home_section.dart';
import 'login_page.dart';
import 'projects_page.dart';

/// Основная оболочка приложения: боковое меню и область контента.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({
    super.key,
    required this.login,
    this.personController,
    this.demoMode = false,
  });

  final String login;

  /// Для открытия демо-страницы работы с БД (legacy Drift).
  final PersonController? personController;

  /// Демо-режим: локальный вход `12345/12345` без сервера.
  final bool demoMode;

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  HomeSection _selectedSection = HomeSection.dashboard;

  /// Ширина бокового меню на широких экранах; меняется перетаскиванием.
  double _sidebarWidth = 280;
  static const double _minSidebarWidth = 200;
  static const double _maxSidebarWidth = 440;

  void _resizeSidebar(double delta) {
    final next = _sidebarWidth + delta;
    if (next < _minSidebarWidth) {
      if (_sidebarWidth != _minSidebarWidth) {
        setState(() => _sidebarWidth = _minSidebarWidth);
      }
    } else if (next > _maxSidebarWidth) {
      if (_sidebarWidth != _maxSidebarWidth) {
        setState(() => _sidebarWidth = _maxSidebarWidth);
      }
    } else if (next != _sidebarWidth) {
      setState(() => _sidebarWidth = next);
    }
  }

  void _selectSection(HomeSection section) {
    setState(() => _selectedSection = section);
  }

  @override
  void initState() {
    super.initState();
    // Не дёргаем GitHub API в отладочных/тестовых сборках.
    if (!kDebugMode) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(updateControllerProvider.notifier).startAutoUpdates(),
      );
    }
  }

  /// Ручная проверка из меню: использует тот же поток, что и автообновление.
  void _checkForUpdate() {
    unawaited(
      ref.read(updateControllerProvider.notifier).checkAndInstall(),
    );
  }

  void _logout() {
    ref.read(authSessionProvider.notifier).logout();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => LoginPage(
          demoMode: widget.demoMode,
          personController: widget.personController,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.sizeOf(context).width >= 1000;
    final updateState = ref.watch(updateControllerProvider);

    ref.listen<UpdateState>(updateControllerProvider, (previous, next) {
      if (!mounted) return;
      if (next.phase == UpdatePhase.failed &&
          next.error != null &&
          previous?.phase != UpdatePhase.failed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось обновить приложение: ${next.error}'),
            action:
                SnackBarAction(label: 'Повторить', onPressed: _checkForUpdate),
          ),
        );
      }
      if (next.phase == UpdatePhase.ready &&
          next.update != null &&
          previous?.phase != UpdatePhase.ready) {
        unawaited(showUpdateDialog(context, next.update!));
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedSection.title),
        actions: [
          if (isWideScreen)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Text(
                  widget.login,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                ),
              ),
            ),
          if (isWideScreen)
            IconButton(
              onPressed: () => setState(() => _sidebarWidth = 280),
              tooltip: 'Сбросить ширину меню',
              icon: const Icon(Icons.view_sidebar_outlined),
            ),
          IconButton(
            onPressed: updateState.isBusy ? null : _checkForUpdate,
            tooltip: updateState.isBusy
                ? 'Обновление выполняется'
                : 'Проверить обновления',
            icon: updateState.isBusy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.system_update),
          ),
          IconButton(
            onPressed: _logout,
            tooltip: 'Выйти',
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: isWideScreen
          ? null
          : Drawer(
              child: AppSidebar(
                login: widget.login,
                selectedSection: _selectedSection,
                onSectionSelected: _selectSection,
                onLogout: _logout,
                closeOnSelect: true,
              ),
            ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (updateState.phase == UpdatePhase.downloading ||
              updateState.phase == UpdatePhase.installing)
            LinearProgressIndicator(
              value: updateState.phase == UpdatePhase.installing
                  ? null
                  : updateState.progress,
            ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isWideScreen) ...[
                  SizedBox(
                    key: const Key('sidebar-panel'),
                    width: _sidebarWidth,
                    child: AppSidebar(
                      login: widget.login,
                      selectedSection: _selectedSection,
                      onSectionSelected: _selectSection,
                      onLogout: _logout,
                    ),
                  ),
                  MouseRegion(
                    cursor: SystemMouseCursors.resizeLeftRight,
                    child: GestureDetector(
                      key: const Key('sidebar-resize-handle'),
                      behavior: HitTestBehavior.translucent,
                      onHorizontalDragUpdate: (details) =>
                          _resizeSidebar(details.delta.dx),
                      onDoubleTap: () => setState(() => _sidebarWidth = 280),
                      child: SizedBox(
                        width: 10,
                        child: VerticalDivider(
                          width: 10,
                          thickness: 2,
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                  ),
                ],
                Expanded(child: _buildContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return switch (_selectedSection) {
      HomeSection.dashboard => SectionPlaceholder(
          icon: Icons.space_dashboard_outlined,
          title: 'Дашборд',
          description: 'Здесь появится сводка по проектам, задачам и срокам. '
              'Раздел находится в разработке.',
          actions: [
            FilledButton.icon(
              onPressed: () => _selectSection(HomeSection.projects),
              icon: const Icon(Icons.folder_outlined),
              label: const Text('Перейти к проектам'),
            ),
            OutlinedButton.icon(
              onPressed: () => _selectSection(HomeSection.roadmap),
              icon: const Icon(Icons.map_outlined),
              label: const Text('Планы развития'),
            ),
          ],
        ),
      HomeSection.createTask => SectionPlaceholder(
          icon: Icons.add_task_outlined,
          title: 'Создание задачи',
          description: 'Задачи живут внутри проекта. Откройте раздел '
              '«Проекты», выберите проект и откройте Backlog или Kanban, '
              'чтобы создавать и перемещать задачи.',
          actions: [
            FilledButton.icon(
              onPressed: () => _selectSection(HomeSection.projects),
              icon: const Icon(Icons.folder_outlined),
              label: const Text('Перейти к проектам'),
            ),
          ],
        ),
      HomeSection.projects => const ProjectsPage(),
      HomeSection.roadmap => const RoadmapView(),
    };
  }
}
