import 'package:flutter/material.dart';

import '../api/person_controller.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/roadmap_view.dart';
import '../widgets/section_placeholder.dart';
import 'db_demo_page.dart';
import 'home_section.dart';
import 'login_page.dart';

/// Основная оболочка приложения: боковое меню и область контента.
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.login,
    required this.personController,
  });

  final String login;
  final PersonController personController;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  HomeSection _selectedSection = HomeSection.dashboard;

  void _selectSection(HomeSection section) {
    setState(() => _selectedSection = section);
  }

  void _openDbDemo() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DbDemoPage(personController: widget.personController),
      ),
    );
  }

  void _logout() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => LoginPage(personController: widget.personController),
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
              onPressed: () => _selectSection(HomeSection.createTask),
              icon: const Icon(Icons.add),
              label: const Text('Создать задачу'),
            ),
            OutlinedButton.icon(
              onPressed: () => _selectSection(HomeSection.roadmap),
              icon: const Icon(Icons.map_outlined),
              label: const Text('Планы развития'),
            ),
          ],
        ),
      HomeSection.createTask => const SectionPlaceholder(
          icon: Icons.add_task_outlined,
          title: 'Создание задачи',
          description: 'Форма создания задачи появится на следующем этапе. '
              'Сейчас в проекте собран только интерфейс приложения.',
        ),
      HomeSection.projects => const SectionPlaceholder(
          icon: Icons.folder_outlined,
          title: 'Проекты',
          description: 'Список проектов, участников команды и задач появится '
              'после подключения серверной части.',
        ),
      HomeSection.roadmap => const RoadmapView(),
    };
  }
}
