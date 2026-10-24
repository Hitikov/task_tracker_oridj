import 'package:drift/drift.dart';

part 'app_database.g.dart'; // Не забудьте подключить сгенерированный файл

/// Определение структуры таблицы Person
@DataClassName(
    'PersonModel') // Генерирует класс PersonModel для работы с данными
class Person extends Table {
  // UUID (Primary Key). Указываем, что колонка является первичным ключом.
  TextColumn get id => text().withLength(min: 36, max: 36)();

  // Имя пользователя (ограничим длину до 255 символов)
  TextColumn get name => text().withLength(max: 255)();

  @override
  Set<Column> get primaryKey =>
      {id}; // Корректное указание первичного ключа в Drift
}

/// Класс AppDatabase — точка входа для всех операций с БД.
@DriftDatabase(tables: [Person])
class AppDatabase extends _$AppDatabase {
  // Конструктор, принимающий QueryExecutor (реальное подключение к БД)
  AppDatabase(super.e);

  // Версия схемы базы данных (обязательна для миграций)
  @override
  int get schemaVersion => 1;

  // --- Бизнес-метод: Добавить пользователя (INSERT) ---
  Future<void> insertPerson({required String id, required String name}) async {
    await into(person).insert(PersonCompanion.insert(id: id, name: name));
  }

  // --- Бизнес-метод: Получить всех пользователей (SELECT * ORDER BY) ---
  Future<List<PersonModel>> selectAllPeople() async {
    return (select(person)
          ..orderBy([
            (p) => OrderingTerm(expression: p.name, mode: OrderingMode.asc)
          ]))
        .get();
  }

  // --- Бизнес-метод: Поиск по ID (SELECT WHERE id = ?) ---
  Future<PersonModel?> selectPersonById(String id) async {
    return (select(person)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  // --- Бизнес-метод: Обновить пользователя (UPDATE SET ...) ---
  Future<void> updatePersonId(String id, String newName) async {
    await (update(person)..where((t) => t.id.equals(id)))
        .write(PersonCompanion(name: Value(newName)));
  }

  // --- Бизнес-метод: Удалить пользователя (DELETE WHERE ...) ---
  Future<void> deletePersonById(String id) async {
    await (delete(person)..where((t) => t.id.equals(id))).go();
  }
}
