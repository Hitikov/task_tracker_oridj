/// Raised when the environment cannot be turned into a valid [AppConfig].
class ConfigException implements Exception {
  ConfigException(Iterable<String> issues)
    : issues = List<String>.unmodifiable(issues);

  /// Individual configuration problems, in the order they were found.
  final List<String> issues;

  @override
  String toString() {
    final buffer = StringBuffer('Invalid server configuration:');
    for (final issue in issues) {
      buffer.write('\n  - $issue');
    }
    return buffer.toString();
  }
}

/// Immutable server configuration parsed from environment variables.
///
/// Database settings are validated here but are not used to open a connection
/// in stage 0: `GET /health` must work without PostgreSQL.
class AppConfig {
  const AppConfig({
    required this.host,
    required this.port,
    required this.dbHost,
    required this.dbPort,
    required this.dbName,
    required this.dbUser,
    required this.dbPassword,
    required this.jwtSecret,
  });

  /// Parses and validates configuration from [environment].
  ///
  /// Throws [ConfigException] listing every discovered problem when the
  /// environment is incomplete or invalid.
  factory AppConfig.fromEnvironment(Map<String, String> environment) {
    final issues = <String>[];

    String required(String key) {
      final value = environment[key]?.trim() ?? '';
      if (value.isEmpty) {
        issues.add('$key is required and must not be empty');
      }
      return value;
    }

    int port(String key, {int? defaultValue}) {
      final raw = environment[key]?.trim();
      if (raw == null || raw.isEmpty) {
        if (defaultValue != null) {
          return defaultValue;
        }
        issues.add('$key is required');
        return 0;
      }

      final parsed = int.tryParse(raw);
      if (parsed == null || parsed < 1 || parsed > 65535) {
        issues.add('$key must be an integer between 1 and 65535 (got "$raw")');
        return 0;
      }
      return parsed;
    }

    final host = environment['SERVER_HOST']?.trim();
    final dbHost = required('DB_HOST');
    final dbName = required('DB_NAME');
    final dbUser = required('DB_USER');
    final dbPassword = required('DB_PASSWORD');
    final jwtSecret = required('JWT_SECRET');
    if (jwtSecret.isNotEmpty && jwtSecret.length < minJwtSecretLength) {
      issues.add(
        'JWT_SECRET must be at least $minJwtSecretLength characters long '
        '(got ${jwtSecret.length})',
      );
    }

    final serverPort = port('SERVER_PORT', defaultValue: defaultPort);
    final dbPort = port('DB_PORT');

    if (issues.isNotEmpty) {
      throw ConfigException(issues);
    }

    return AppConfig(
      host: host == null || host.isEmpty ? defaultHost : host,
      port: serverPort,
      dbHost: dbHost,
      dbPort: dbPort,
      dbName: dbName,
      dbUser: dbUser,
      dbPassword: dbPassword,
      jwtSecret: jwtSecret,
    );
  }

  /// Default bind address used when `SERVER_HOST` is not set.
  static const String defaultHost = '0.0.0.0';

  /// Default port used when `SERVER_PORT` is not set.
  static const int defaultPort = 8080;

  /// Minimum accepted length of `JWT_SECRET`.
  static const int minJwtSecretLength = 32;

  final String host;
  final int port;
  final String dbHost;
  final int dbPort;
  final String dbName;
  final String dbUser;
  final String dbPassword;
  final String jwtSecret;
}
