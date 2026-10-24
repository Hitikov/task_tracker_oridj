// Импортируем репозиторий
import '../repositories/person_repository.dart';
// Импортируем сгенерированные модели из базы данных (где лежит PersonModel)
import '../database/app_database.dart';

/// Контроллер, который содержит бизнес-логику для работы с пользователями.
class PersonController {
  final PersonRepository _repository;

  // Внедряем PersonRepository через конструктор
  PersonController(this._repository);

  // --- C (CREATE): Добавить пользователя ---
  Future<PersonModel> createPerson(String name) async {
    if (name.trim().isEmpty) {
      throw Exception("Имя пользователя не может быть пустым.");
    }
    return await _repository.addPerson(name: name);
  }

  // --- R (READ): Получить всех пользователей ---
  Future<List<PersonModel>> getPeople() async {
    return await _repository.getAllPeople();
  }

  // --- R (READ): Поиск по ID ---
  Future<PersonModel?> getPersonById(String id) async {
    return await _repository.getPersonById(id);
  }

  // --- U (UPDATE): Обновить пользователя ---
  Future<void> updatePerson(String id, String newName) async {
    if (newName.trim().isEmpty) {
      throw Exception("Имя пользователя не может быть пустым.");
    }

    // Проверяем, существует ли пользователь перед обновлением
    final existingPerson = await _repository.getPersonById(id);
    if (existingPerson == null) {
      throw Exception("Пользователь с ID $id не найден.");
    }

    await _repository.updatePerson(id, newName);
  }

  // --- D (DELETE): Удалить пользователя ---
  Future<void> deletePerson(String id) async {
    await _repository.deletePerson(id);
  }
}
