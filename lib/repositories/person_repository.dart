import 'package:uuid/uuid.dart';
// Импортируем сгенерированный класс базы данных
import '../database/app_database.dart';

class PersonRepository {
  final AppDatabase _db;

  // Используем внедрение зависимости (Dependency Injection) через конструктор.
  // Экземпляр БД будет передаваться при создании репозитория (например, через Provider или GetIt).
  PersonRepository(this._db);

  /// Добавляет нового пользователя в базу данных.
  Future<PersonModel> addPerson({required String name}) async {
    final newId = const Uuid().v4();
    print('✅ [REPO] Попытка вставки пользователя: $name ($newId)...');

    try {
      // 1. Вызов метода из AppDatabase (INSERT)
      await _db.insertPerson(id: newId, name: name);

      // 2. Возвращаем созданную модель
      return PersonModel(id: newId, name: name);
    } catch (e) {
      print(
          '❌ [REPO ERROR] Ошибка при вставке пользователя $name: ${e.toString()}');
      rethrow;
    }
  }

  /// Получает список всех пользователей, отсортированных по имени (SELECT *).
  Future<List<PersonModel>> getAllPeople() async {
    print('✅ [REPO] Выборка всех пользователей из БД...');
    try {
      // Вызов метода из AppDatabase возвращает готовые PersonModel
      return await _db.selectAllPeople();
    } catch (e) {
      print(
          '❌ [REPO ERROR] Ошибка при получении всех пользователей: ${e.toString()}');
      rethrow;
    }
  }

  /// Получает пользователя по его UUID.
  Future<PersonModel?> getPersonById(String id) async {
    print('✅ [REPO] Поиск пользователя по ID: $id...');
    try {
      return await _db.selectPersonById(id);
    } catch (e) {
      print(
          '❌ [REPO ERROR] Ошибка при поиске пользователя по ID $id: ${e.toString()}');
      rethrow;
    }
  }

  /// Обновляет имя пользователя с заданным ID.
  Future<void> updatePerson(String id, String newName) async {
    print('✅ [REPO] Попытка обновления пользователя с ID $id...');
    try {
      await _db.updatePersonId(id, newName);
    } catch (e) {
      print(
          '❌ [REPO ERROR] Ошибка при обновлении пользователя $id: ${e.toString()}');
      rethrow;
    }
  }

  /// Удаляет пользователя по ID.
  Future<void> deletePerson(String id) async {
    print('✅ [REPO] Попытка удаления пользователя с ID: $id...');
    try {
      await _db.deletePersonById(id);
    } catch (e) {
      print(
          '❌ [REPO ERROR] Ошибка при удалении пользователя $id: ${e.toString()}');
      rethrow;
    }
  }
}
