import 'package:arij_server/src/config/app_config.dart';
import 'package:arij_server/src/db/database.dart';
import 'package:arij_server/src/db/migration_runner.dart';
import 'package:test/test.dart';

Map<String, String> _environment() => <String, String>{
  'DB_HOST': 'localhost',
  'DB_PORT': '5432',
  'DB_NAME': 'arij_test',
  'DB_USER': 'arij',
  'DB_PASSWORD': 'arij_test_password',
  'JWT_SECRET': 'test-secret-that-is-at-least-32-chars',
};

Future<bool> _databaseAvailable() async {
  final database = Database(AppConfig.fromEnvironment(_environment()));
  try {
    await database.open();
    await database.close();
    return true;
  } catch (_) {
    return false;
  }
}

Future<void> main() async {
  final environment = _environment();
  final available = await _databaseAvailable();

  test(
    'applies migrations to a live PostgreSQL',
    skip: available ? null : 'База недоступна: запустите PostgreSQL',
    () async {
      final database = Database(AppConfig.fromEnvironment(environment));
      await database.open();
      try {
        final applied = await applyMigrations(database, migrationsDirectory());
        expect(applied, isNotEmpty);
      } finally {
        await database.close();
      }
    },
  );
}
