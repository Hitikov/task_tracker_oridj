import 'package:flutter/material.dart';

/// Разделы основной оболочки приложения.
enum HomeSection {
  dashboard('Дашборд', Icons.space_dashboard_outlined),
  createTask('Создать задачу', Icons.add_task_outlined),
  projects('Проекты', Icons.folder_outlined),
  roadmap('Планы развития', Icons.map_outlined);

  const HomeSection(this.title, this.icon);

  final String title;
  final IconData icon;
}
