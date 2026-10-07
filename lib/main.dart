import 'package:flutter/material.dart';

// --- Главная функция приложения ---
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true, // Используем Material 3 для современного вида
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
      ),
      home: const TaskTrackerHomePage(),
    );
  }
}

// --- Основная страница трекера задач (с боковым меню) ---
class TaskTrackerHomePage extends StatefulWidget {
  const TaskTrackerHomePage({super.key});

  @override
  State<TaskTrackerHomePage> createState() => _TaskTrackerHomePageState();
}

class _TaskTrackerHomePageState extends State<TaskTrackerHomePage> {
  // Отслеживаем текущий активный раздел (для демонстрации работы меню)
  String _selectedSection = 'Планируемые функции';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Tracker Oridj'),
        elevation: 0,
      ),
      body: Row(
        children: <Widget>[
          // 1. Боковое меню навигации (Sidebar)
          _buildSidebar(),
          // Разделитель между меню и контентом
          const VerticalDivider(thickness: 1),
          // 2. Основная область контента
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildContentArea(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 250, // Фиксированная ширина боковой панели
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Меню', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 30),
          // Элементы меню
          _buildMenuItem(
            '📊 Дашборд',
            () {
              setState(() {
                _selectedSection = 'Дашборд';
              });
            },
          ),
          const SizedBox(height: 10),
          _buildMenuItem(
            '➕ Создать задачу',
            () {
              setState(() {
                _selectedSection = 'Создание задачи';
              });
            },
          ),
          const SizedBox(height: 10),
          _buildMenuItem(
            '📚 Проекты',
            () {
              setState(() {
                _selectedSection = 'Проекты';
              });
            },
          ),
          const SizedBox(height: 20),
          // Разделитель для секции планов
          const Divider(),
          const SizedBox(height: 10),
          Text('Функционал', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          _buildMenuItem(
            '💡 Планы развития (Текущее)',
            () {
              setState(() {
                _selectedSection = 'Планируемые функции';
              });
            },
          ),
        ],
      ),
    );
  }

  // Вспомогательная функция для создания элемента меню
  Widget _buildMenuItem(String title, VoidCallback onTap) {
    final isSelected = (_selectedSection == title.split(' ')[0]); // Простая логика выбора
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300)
        ),
        child: Text(title, style: TextStyle(fontSize: 16, color: isSelected ? Theme.of(context).colorScheme.primary : Colors.black)),
      ),
    );
  }

  // Виджет для отображения контента в основной области
  Widget _buildContentArea() {
    if (_selectedSection == 'Планируемые функции') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📄 Планируемые функции (Roadmap)', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Text("Цель: Расширить функционал для поддержки сложных командных процессов и отчетности.", style: TextStyle(fontSize: 16, color: Colors.grey[700])),
          const Divider(),
          Expanded(
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Checkbox(value: false, onChanged: (val) {}),
                      const SizedBox(width: 10),
                      Expanded(child: Text('Настройка проектов (досок) с независимыми типами задач и статусами', style: TextStyle(fontSize: 16))),
                    ],
                  ),
                ),
                 Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Checkbox(value: false, onChanged: (val) {}),
                      const SizedBox(width: 10),
                      Expanded(child: Text('Настраиваемые обязательные/необязательные поля для задач', style: TextStyle(fontSize: 16))),
                    ],
                  ),
                ),
                 Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Checkbox(value: false, onChanged: (val) {}),
                      const SizedBox(width: 10),
                      Expanded(child: Text('Фильтрация и поиск задач', style: TextStyle(fontSize: 16))),
                    ],
                  ),
                ),
                 Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Checkbox(value: false, onChanged: (val) {}),
                      const SizedBox(width: 10),
                      Expanded(child: Text('Детализированные отчеты и графики', style: TextStyle(fontSize: 16))),
                    ],
                  ),
                ),
                 Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Checkbox(value: false, onChanged: (val) {}),
                      const SizedBox(width: 10),
                      Expanded(child: Text('Ролевая модель доступа (администратор, руководитель, исполнитель, наблюдатель)', style: TextStyle(fontSize: 16))),
                    ],
                  ),
                ),
                 Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Checkbox(value: false, onChanged: (val) {}),
                      const SizedBox(width: 10),
                      Expanded(child: Text('Создавать/редактировать задачи с помощью агента', style: TextStyle(fontSize: 16))),
                    ],
                  ),
                ),
                 Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Checkbox(value: false, onChanged: (val) {}),
                      const SizedBox(width: 10),
                      Expanded(child: Text('Получать статистику по задачам с помощью агента', style: TextStyle(fontSize: 16))),
                    ],
                  ),
                ),
                 Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Checkbox(value: false, onChanged: (val) {}),
                      const SizedBox(width: 10),
                      Expanded(child: Text('Просто общение с агентом <3', style: TextStyle(fontSize: 16, color: Colors.blue))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    // Здесь будет логика для отображения контента других разделов (Дашборд, Проекты и т.д.)
    return const Center(child: Text('Содержимое раздела будет добавлено позже.', style: TextStyle(fontSize: 20)));
  }
}