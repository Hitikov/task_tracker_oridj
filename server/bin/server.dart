import 'dart:async';
import 'dart:io';

import 'package:arij_server/arij_server.dart';
import 'package:arij_server/src/db/database.dart';
import 'package:arij_server/src/db/migration_runner.dart';
import 'package:arij_server/src/version.dart';
import 'package:dotenv/dotenv.dart';
import 'package:logging/logging.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

final Logger _log = Logger('arij.server');

/// Environment variables that may come from `.env` files.
const List<String> _envKeys = <String>[
  'SERVER_HOST',
  'SERVER_PORT',
  'DB_HOST',
  'DB_PORT',
  'DB_NAME',
  'DB_USER',
  'DB_PASSWORD',
  'JWT_SECRET',
  'APPLY_MIGRATIONS',
];

Future<void> main() async {
  _configureLogging();

  final environment = _loadEnvironment();
  final AppConfig config;
  try {
    config = AppConfig.fromEnvironment(environment);
  } on ConfigException catch (error) {
    stderr.writeln(error);
    exitCode = 78; // EX_CONFIG
    return;
  }

  final database = Database(config);
  if (_applyMigrationsEnabled(environment)) {
    try {
      await database.open();
      final applied = await applyMigrations(
        database,
        migrationsDirectory(environment),
      );
      if (applied.isNotEmpty) {
        _log.info(
          'Применено миграций: ${applied.length} (${applied.join(', ')})',
        );
      }
    } on Object catch (error, stackTrace) {
      await database.close();
      _log.severe(
        'Не удалось запустить сервер: подключение к БД или применение '
        'миграций не прошли',
        error,
        stackTrace,
      );
      stderr.writeln('Ошибка миграций: $error');
      exitCode = 1;
      return;
    }
  } else {
    _log.warning('APPLY_MIGRATIONS=false: запуск без применения миграций');
  }

  final server = await shelf_io.serve(
    buildHandler(config: config),
    config.host,
    config.port,
  );
  server.autoCompress = true;

  _log.info(
    'Arij server $serverVersion listening on '
    'http://${config.host}:${server.port}',
  );

  final subscriptions = <StreamSubscription<ProcessSignal>>[];
  var shuttingDown = false;

  Future<void> shutdown(String reason) async {
    if (shuttingDown) {
      return;
    }
    shuttingDown = true;
    _log.info('Shutting down: $reason');

    await server.close(force: false);
    await database.close();
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }

    _log.info('Server stopped');
    await stdout.flush();
    exit(0);
  }

  for (final signal in const <ProcessSignal>[
    ProcessSignal.sigint,
    ProcessSignal.sigterm,
  ]) {
    try {
      subscriptions.add(
        signal.watch().listen(
          (received) => unawaited(shutdown('received $received')),
          onError: (Object error) {
            _log.fine('Signal $signal is not supported: $error');
          },
        ),
      );
    } on SignalException catch (error) {
      _log.fine('Signal $signal is not supported: $error');
    } on UnsupportedError catch (error) {
      _log.fine('Signal $signal is not supported: $error');
    }
  }
}

/// Loads `.env` files without overriding the process environment.
///
/// `./.env` takes precedence over `../.env`; real environment variables always
/// win over file values.
Map<String, String> _loadEnvironment() {
  final environment = Map<String, String>.of(Platform.environment);

  for (final path in const <String>['.env', '../.env']) {
    if (!File(path).existsSync()) {
      continue;
    }

    final dotenv = DotEnv(quiet: true)..load(<String>[path]);
    for (final key in _envKeys) {
      final value = dotenv[key];
      if (value == null || value.isEmpty) {
        continue;
      }
      environment.putIfAbsent(key, () => value);
    }
  }

  return environment;
}

/// Возвращает `false`, если `APPLY_MIGRATIONS` в `false`/`0`/`no`.
bool _applyMigrationsEnabled([Map<String, String>? environment]) {
  final value = (environment ?? Platform.environment)['APPLY_MIGRATIONS']
      ?.trim()
      .toLowerCase();
  return switch (value) {
    'false' || '0' || 'no' => false,
    _ => true,
  };
}

void _configureLogging() {
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((LogRecord record) {
    final line = StringBuffer()
      ..write(record.time.toUtc().toIso8601String())
      ..write(' ${record.level.name.padRight(7)} ')
      ..write(record.loggerName)
      ..write(': ')
      ..write(record.message);
    if (record.error != null) {
      line.write(' | ${record.error}');
    }

    final sink = record.level >= Level.SEVERE ? stderr : stdout;
    sink.writeln(line);
    final stackTrace = record.stackTrace;
    if (stackTrace != null) {
      sink.writeln(stackTrace);
    }
  });
}
