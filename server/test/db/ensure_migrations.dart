import 'package:arij_server/src/db/database.dart';
import 'package:arij_server/src/db/migration_runner.dart';

/// Приводит [database] к актуальной схеме идемпотентно.
///
/// Интеграционные тесты запускаются в параллельных изолятах. На чистой БД
/// несколько из них одновременно видят пустую `schema_migrations` и пытаются
/// применить одни и те же миграции: второй вызов получает нарушение
/// первичного ключа по имени файла (или duplicate_object для триггера).
/// Повторяем до тех пор, пока все найденные миграции не будут учтены.
Future<void> ensureMigrations(Database database) async {
  final directory = migrationsDirectory();
  final discovered = discoverMigrations(directory).toSet();
  Object? lastError;
  for (var attempt = 0; attempt < 10; attempt++) {
    try {
      await applyMigrations(database, directory);
      final applied = await appliedMigrations(database);
      if (discovered.every(applied.contains)) {
        return;
      }
    } on Object catch (error) {
      lastError = error;
    }
  }
  throw lastError ??
      StateError('Не удалось применить миграции после 10 попыток');
}
