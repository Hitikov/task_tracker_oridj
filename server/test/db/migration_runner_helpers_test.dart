import 'dart:io';

import 'package:arij_server/src/db/migration_runner.dart';
import 'package:test/test.dart';

void main() {
  group('discoverMigrations', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('arij_migrations_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    File write(String name) {
      final file = File('${tempDir.path}${Platform.pathSeparator}$name');
      file.writeAsStringSync('-- stub');
      return file;
    }

    test('возвращает файлы по возрастанию номера', () {
      write('0002_projects.sql');
      write('0000_schema_migrations.sql');
      write('0003_project_members.sql');
      write('0001_users.sql');

      expect(discoverMigrations(tempDir.path), [
        '0000_schema_migrations.sql',
        '0001_users.sql',
        '0002_projects.sql',
        '0003_project_members.sql',
      ]);
    });

    test('ошибка при дублирующихся номерах', () {
      write('0001_a.sql');
      write('0001_b.sql');

      expect(
        () => discoverMigrations(tempDir.path),
        throwsA(
          isA<MigrationRunnerException>().having(
            (e) => e.message,
            'message',
            contains('Дублирующийся номер миграции'),
          ),
        ),
      );
    });

    test('ошибка при пропуске номеров', () {
      write('0000_a.sql');
      write('0002_b.sql');

      expect(
        () => discoverMigrations(tempDir.path),
        throwsA(
          isA<MigrationRunnerException>().having(
            (e) => e.message,
            'message',
            contains('Пропуск в нумерации'),
          ),
        ),
      );
    });

    test('ошибка при несоответствующем имени файла', () {
      write('0001-users.sql');

      expect(
        () => discoverMigrations(tempDir.path),
        throwsA(
          isA<MigrationRunnerException>().having(
            (e) => e.message,
            'message',
            contains('Ошибка в имени файла'),
          ),
        ),
      );
    });

    test('ошибка при отсутствующем каталоге', () {
      expect(
        () => discoverMigrations('missing/directory'),
        throwsA(
          isA<MigrationRunnerException>().having(
            (e) => e.message,
            'message',
            contains('Каталог миграций не найден'),
          ),
        ),
      );
    });

    test('ошибка, если в каталоге нет файлов миграций', () {
      write('notes.txt');

      expect(
        () => discoverMigrations(tempDir.path),
        throwsA(
          isA<MigrationRunnerException>().having(
            (e) => e.message,
            'message',
            contains('нет файлов формата'),
          ),
        ),
      );
    });
  });

  group('validateAppliedAgainstDiscovered', () {
    test('пропускает корректный список', () {
      expect(
        () => validateAppliedAgainstDiscovered(['0001_a.sql'], {'0001_a.sql'}),
        returnsNormally,
      );
    });

    test('ошибка на файл, которого нет в каталоге', () {
      expect(
        () => validateAppliedAgainstDiscovered(
          ['0001_a.sql'],
          {'0001_a.sql', '0002_gone.sql'},
        ),
        throwsA(
          isA<MigrationRunnerException>().having(
            (e) => e.message,
            'message',
            contains('0002_gone.sql'),
          ),
        ),
      );
    });
  });

  group('selectToApply', () {
    test('возвращает только неприменённые', () {
      expect(
        selectToApply(
          ['0001_a.sql', '0002_b.sql', '0003_c.sql'],
          {'0002_b.sql'},
        ),
        ['0001_a.sql', '0003_c.sql'],
      );
    });
  });

  group('migrationsDirectory', () {
    test('MIGRATIONS_DIR из окружения имеет приоритет', () {
      expect(
        migrationsDirectory(<String, String>{
          'MIGRATIONS_DIR': 'custom/migrations',
        }),
        'custom/migrations',
      );
    });

    test('по умолчанию возвращает каталог migrations', () {
      final directory = migrationsDirectory(<String, String>{});
      expect(Directory(directory).existsSync(), isTrue);
    });
  });
}
