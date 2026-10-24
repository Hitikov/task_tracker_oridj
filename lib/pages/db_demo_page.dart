import 'package:flutter/material.dart';

import '../api/person_controller.dart';
import '../database/app_database.dart';

/// Демонстрационная страница работы с локальной базой данных.
///
/// Показывает полный CRUD-цикл над таблицей `Person` через слои
/// repository → controller. Используется как диагностический экран.
class DbDemoPage extends StatefulWidget {
  const DbDemoPage({super.key, required this.personController});

  final PersonController personController;

  @override
  State<DbDemoPage> createState() => _DbDemoPageState();
}

class _DbDemoPageState extends State<DbDemoPage> {
  String _statusMessage =
      "Готов к работе с данными. Нажмите 'Запустить демо' для запуска CRUD-цикла.";

  // Используем PersonModel, сгенерированный Drift.
  List<PersonModel> _peopleList = [];

  // --- Демонстрация полного цикла CRUD ---
  Future<void> runDemo() async {
    setState(() {
      _statusMessage = 'Запуск демо... (1/4: Добавление пользователя)';
      _peopleList.clear();
    });

    try {
      // 1. CREATE (Добавить)
      final newUser =
          await widget.personController.createPerson('Михаил Сидоров');
      setState(() {
        _statusMessage = 'Успех: Пользователь ${newUser.name} добавлен.';
      });

      await Future<void>.delayed(const Duration(milliseconds: 500));

      // 2. READ (Получить список)
      setState(() {
        _statusMessage =
            'Загрузка данных... (2/4: Получение списка пользователей)';
      });
      final peopleList = await widget.personController.getPeople();
      setState(() {
        _peopleList = peopleList;
        _statusMessage =
            'Успех: Загружено ${_peopleList.length} пользователей.';
      });

      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (_peopleList.isNotEmpty) {
        // Берем первого пользователя для редактирования.
        final personToUpdateId = _peopleList[0].id;

        // 3. UPDATE (Обновить)
        setState(() {
          _statusMessage = 'Изменение данных... (3/4: Обновление)';
        });
        await widget.personController
            .updatePerson(personToUpdateId, 'Михаил Сидоров - Обновлено');

        // Снова получаем список после обновления для подтверждения.
        final refreshedPeopleList = await widget.personController.getPeople();
        setState(() {
          _peopleList = refreshedPeopleList;
          _statusMessage =
              'Успех: Пользователь обновлен и список синхронизирован.';
        });

        await Future<void>.delayed(const Duration(milliseconds: 500));

        // 4. DELETE (Удалить)
        // Проверяем, есть ли хотя бы 2 пользователя, чтобы не получить RangeError.
        if (_peopleList.length >= 2) {
          final idToDelete = _peopleList[1].id;
          setState(() {
            _statusMessage = 'Удаление данных... (4/4: Удаление)';
          });

          await widget.personController.deletePerson(idToDelete);

          // Финальная загрузка, исключая удаленного.
          final finalPeopleList = await widget.personController.getPeople();
          setState(() {
            _peopleList = finalPeopleList;
            _statusMessage = '✅ Демо завершено! Пользователь успешно удален.';
          });
        } else {
          setState(() {
            _statusMessage =
                '✅ Демо завершено! (Меньше 2 пользователей для удаления)';
          });
        }
      } else {
        setState(() {
          _statusMessage =
              'Не удалось запустить цикл демо: Не получено ни одного пользователя.';
        });
      }
    } catch (e) {
      // Обработка ошибок API или БД.
      setState(() {
        _statusMessage = '❌ ОШИБКА при выполнении CRUD-цикла: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Демо работы с БД'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Кнопка запуска демо.
            Center(
              child: ElevatedButton.icon(
                onPressed: runDemo,
                icon: const Icon(Icons.play_arrow),
                label: const Text(
                  'Запустить CRUD-демо (Проверка связи с БД)',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Статус выполнения операций (Логирование).
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Текущий статус работы:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    Text(
                      _statusMessage,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Секция "Список пользователей" (Результат READ).
            const Text(
              'Текущий список пользователей в БД:',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            if (_peopleList.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(50),
                  child: Text(
                    'Список пуст. Запустите демо для добавления данных.',
                  ),
                ),
              )
            else
              Column(
                children: _peopleList.map((person) {
                  return Card(
                    margin:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 5),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Имя: ${person.name}',
                                style: const TextStyle(fontSize: 18),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'ID: ${person.id.substring(0, 8)}...',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}
