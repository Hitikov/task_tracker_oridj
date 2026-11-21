import 'package:postgres/postgres.dart';

import '../config/app_config.dart';

/// Обёртка над пулом PostgreSQL-соединений, созданным из [AppConfig].
class Database {
  Database(AppConfig config)
    : _pool = Pool<Never>.withEndpoints(
        <Endpoint>[
          Endpoint(
            host: config.dbHost,
            port: config.dbPort,
            database: config.dbName,
            username: config.dbUser,
            password: config.dbPassword,
          ),
        ],
        // Локальный PostgreSQL в docker compose работает без TLS.
        // В production соединение защищается Nginx/сетью, а не TLS внутри compose.
        settings: PoolSettings(sslMode: SslMode.disable),
      );

  final Pool<Never> _pool;

  /// Открывает пул соединений: захватывает первое соединение и
  /// проверяет доступность БД.
  Future<void> open() => _pool.run((_) async {});

  /// Закрывает пул и все соединения.
  Future<void> close() => _pool.close();

  /// Выполняет запрос и возвращает результат.
  Future<Result> query(
    Object query, {
    Object? parameters,
    QueryMode? queryMode,
  }) {
    return _pool.execute(query, parameters: parameters, queryMode: queryMode);
  }

  /// Выполняет операцию внутри транзакции: автокоммит при успехе,
  /// rollback при ошибке.
  Future<void> transaction(Future<void> Function(TxSession session) callback) {
    return _pool.runTx(callback);
  }
}
