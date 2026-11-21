import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/person_controller.dart';
import '../state/auth_providers.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/roadmap_view.dart';
import '../widgets/section_placeholder.dart';
import 'db_demo_page.dart';
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

  void _selectSection(HomeSection section) {
    setState(() => _selectedSection = section);
  }

  void _openDbDemo() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DbDemoPage(
          personController: widget.personController,
        ),
      ),
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
                onDbDemoSelected: _openDbDemo,
                onLogout: _logout,
                closeOnSelect: true,
              ),
            ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isWideScreen) ...[
            SizedBox(
              width: 280,
              child: AppSidebar(
                login: widget.login,
                selectedSection: _selectedSection,
                onSectionSelected: _selectSection,
                onDbDemoSelected: _openDbDemo,
                onLogout: _logout,
              ),
            ),
            const VerticalDivider(width: 1),
          ],
          Expanded(child: _buildContent()),
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
