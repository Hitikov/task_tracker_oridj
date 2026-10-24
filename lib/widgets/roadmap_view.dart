import 'package:flutter/material.dart';

/// Пункты дорожной карты из README (раздел «Планируемые функции»).
const List<String> _roadmapItems = <String>[
  'Настройка проектов (досок) с независимыми типами задач и статусами',
  'Настраиваемые обязательные/необязательные поля для задач',
  'Фильтрация и поиск задач',
  'Детализированные отчёты и графики',
  'Ролевая модель доступа (администратор, руководитель, исполнитель, наблюдатель)',
  'Создавать/редактировать задачи с помощью агента',
  'Получать статистику по задачам с помощью агента',
  'Просто общение с агентом <3',
];

/// Содержимое раздела «Планы развития».
///
/// Список носит информационный характер: отметки показывают, что функции
/// ещё не реализованы, и не сохраняют состояние.
class RoadmapView extends StatelessWidget {
  const RoadmapView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Планы развития Arij',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Функции за пределами текущего MVP. Отметки появятся, когда '
          'соответствующий пункт будет реализован.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                color: theme.colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Сейчас в работе — базовый цикл управления задачами: '
                  'проекты, эпики, задачи и статусы.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var index = 0; index < _roadmapItems.length; index++) ...[
                ListTile(
                  leading: const Checkbox(
                    value: false,
                    onChanged: null,
                  ),
                  title: Text(_roadmapItems[index]),
                ),
                if (index != _roadmapItems.length - 1)
                  const Divider(height: 1, indent: 16, endIndent: 16),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
