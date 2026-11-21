import 'dart:io';

import 'package:logging/logging.dart';
import 'package:postgres/postgres.dart';

import 'database.dart';

final Logger _log = Logger('arij.db.migrations');

/// Ошибка обнаружения или применения миграций.
class MigrationRunnerException implements Exception {
  MigrationRunnerException(this.message);

  /// Понятное сообщение о проблеме.
  final String message;

  @override
  String toString() => 'Ошибка миграций: $message';
}

/// Имена файлов миграций: `NNNN_name.sql`.
final RegExp _fileNamePattern = RegExp(r'^(\d{4})_[\w]+\.sql$');

/// Возвращает имя файла из [path] (учитывает `/` и `\`).
String _fileName(String path) {
  final normalized = path.replaceAll('\\', '/');
  return normalized.substring(normalized.lastIndexOf('/') + 1);
}

/// Обнаруживает файлы миграций в каталоге [directory].
///
/// Возвращает имена файлов, отсортированные по возрастанию номера.
/// При несоответствии именованию или пропусках в номерации выбрасывает
/// [MigrationRunnerException].
List<String> discoverMigrations(String directory) {
  final dir = Directory(directory);
  if (!dir.existsSync()) {
    throw MigrationRunnerException('Каталог миграций не найден: $directory');
  }

  final byNumber = <int, String>{};
  for (final entity in dir.listSync()) {
    if (entity is! File) {
      continue;
    }
    final name = _fileName(entity.path);
    if (!name.endsWith('.sql')) {
      continue;
    }
    final match = _fileNamePattern.firstMatch(name);
    if (match == null) {
      throw MigrationRunnerException(
        'Ошибка в имени файла "$name": ожидается формат NNNN_name.sql',
      );
    }
    final number = int.parse(match.group(1)!);
    final previous = byNumber[number];
    if (previous != null) {
      throw MigrationRunnerException(
        'Дублирующийся номер миграции: $number '
        '(файлы "$previous" и "$name")',
      );
    }
    byNumber[number] = name;
  }

  if (byNumber.isEmpty) {
    throw MigrationRunnerException(
      'В каталоге миграций нет файлов формата NNNN_*.sql: $directory',
    );
  }

  final numbers = byNumber.keys.toList()..sort();
  for (var i = 0; i < numbers.length; i++) {
    if (numbers[i] != numbers[0] + i) {
      throw MigrationRunnerException(
        'Пропуск в нумерации миграций: ожидался ${numbers[0] + i}, '
        'найдено ${numbers[i]} (файл "${byNumber[numbers[i]]}")',
      );
    }
  }

  return numbers.map((number) => byNumber[number]!).toList();
}

/// Проверяет, что в `schema_migrations` нет записей о файлах без файла в
/// каталоге миграций ([discovered]).
void validateAppliedAgainstDiscovered(
  List<String> discovered,
  Set<String> applied,
) {
  final missing = applied.where((name) => !discovered.contains(name)).toList()
    ..sort();
  if (missing.isNotEmpty) {
    throw MigrationRunnerException(
      'Запись schema_migrations ссылается на отсутствующий файл миграции: '
      '${missing.join(', ')}',
    );
  }
}

/// Возвращает имена из [discovered], которых нет в [applied],
/// сохраняя порядок возрастания.
List<String> selectToApply(List<String> discovered, Set<String> applied) {
  return discovered.where((name) => !applied.contains(name)).toList();
}

/// Возвращает имена применённых миграций из таблицы `schema_migrations`.
///
/// На чистой БД таблица ещё не создана — возвращает пустой набор.
Future<Set<String>> appliedMigrations(Database database) async {
  try {
    final result = await database.query(
      'SELECT filename FROM schema_migrations',
    );
    return result.map((row) => row[0] as String).toSet();
  } on ServerException catch (error) {
    if (error.code != '42P01') {
      rethrow;
    }
    return <String>{};
  }
}

/// Применяет неприменённые миграции из каталога [directory].
///
/// Каждая миграция выполняется в транзакции; вместе с ней в
/// `schema_migrations` записывается имя файла. Метод идемпотентен:
/// уже применённые миграции пропускаются. Возвращает список миграций,
/// применённых в этом вызове.
Future<List<String>> applyMigrations(
  Database database,
  String directory,
) async {
  final discovered = discoverMigrations(directory);
  final applied = await appliedMigrations(database);
  validateAppliedAgainstDiscovered(discovered, applied);

  final toApply = selectToApply(discovered, applied);
  for (final name in toApply) {
    final sql = File(
      '$directory${Platform.pathSeparator}$name',
    ).readAsStringSync();
    await database.transaction((tx) async {
      await tx.execute(sql, queryMode: QueryMode.simple);
      await tx.execute(
        Sql.named(
          'INSERT INTO schema_migrations (filename) VALUES (@filename)',
        ),
        parameters: <String, Object?>{'filename': name},
      );
    });
    _log.info('Миграция применена: $name');
  }

  return toApply;
}

/// Возвращает каталог с SQL-миграциями.
///
/// Порядок разрешения:
/// 1. `MIGRATIONS_DIR` — если задан и не пустой;
/// 2. `migrations` относительно текущей директории;
/// 3. `migrations` рядом с исполняемым файлом: для `dart run bin/server.dart`
///    — `<root>/migrations`, для AOT-бинарника — `<root>/migrations`.
///
/// Если каталог не найден — возвращает `migrations` (ошибка будет
/// в [discoverMigrations]).
String migrationsDirectory([Map<String, String>? environment]) {
  final variables = environment ?? Platform.environment;
  final directory = variables['MIGRATIONS_DIR']?.trim();
  if (directory != null && directory.isNotEmpty) {
    return directory;
  }

  for (final candidate in _candidateDirectories()) {
    if (candidate.existsSync()) {
      return candidate.path;
    }
  }

  return 'migrations';
}

List<Directory> _candidateDirectories() {
  final candidates = <Directory>[Directory('migrations')];
  for (final scriptDir in _scriptDirectories()) {
    // Для `dart run bin/server.dart`: скрипт в `<root>/bin/server.dart`
    // → `<root>/migrations`.
    candidates.add(
      Directory(
        '${scriptDir.parent.parent.path}${Platform.pathSeparator}migrations',
      ),
    );
    // Для AOT-бинарника `<root>/server` → `<root>/migrations`.
    candidates.add(
      Directory('${scriptDir.parent.path}${Platform.pathSeparator}migrations'),
    );
  }
  return candidates;
}

List<Directory> _scriptDirectories() {
  try {
    final uri = Platform.script;
    return <Directory>[Directory(uri.toFilePath())];
  } on Object {
    return const <Directory>[];
  }
}
