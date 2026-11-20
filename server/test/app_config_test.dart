import 'package:arij_server/arij_server.dart';
import 'package:test/test.dart';

Map<String, String> _validEnvironment() => <String, String>{
  'SERVER_HOST': '127.0.0.1',
  'SERVER_PORT': '9090',
  'DB_HOST': 'localhost',
  'DB_PORT': '5432',
  'DB_NAME': 'arij_test',
  'DB_USER': 'arij',
  'DB_PASSWORD': 'arij_test_password',
  'JWT_SECRET': 'test-secret-that-is-at-least-32-chars',
};

Matcher _configError(String fragment) => throwsA(
  isA<ConfigException>().having(
    (ConfigException error) => error.toString(),
    'message',
    contains(fragment),
  ),
);

void main() {
  group('AppConfig', () {
    test('parses a complete environment', () {
      final config = AppConfig.fromEnvironment(_validEnvironment());

      expect(config.host, '127.0.0.1');
      expect(config.port, 9090);
      expect(config.dbHost, 'localhost');
      expect(config.dbPort, 5432);
      expect(config.dbName, 'arij_test');
      expect(config.dbUser, 'arij');
      expect(config.dbPassword, 'arij_test_password');
      expect(config.jwtSecret, 'test-secret-that-is-at-least-32-chars');
    });

    test('applies server defaults', () {
      final environment = _validEnvironment()
        ..remove('SERVER_HOST')
        ..remove('SERVER_PORT');

      final config = AppConfig.fromEnvironment(environment);

      expect(config.host, AppConfig.defaultHost);
      expect(config.port, AppConfig.defaultPort);
      expect(config.host, '0.0.0.0');
      expect(config.port, 8080);
    });

    test('trims whitespace around values', () {
      final environment = _validEnvironment()
        ..['SERVER_PORT'] = ' 8080 '
        ..['DB_NAME'] = ' arij ';

      final config = AppConfig.fromEnvironment(environment);

      expect(config.port, 8080);
      expect(config.dbName, 'arij');
    });

    test('rejects a missing required variable', () {
      final environment = _validEnvironment()..remove('DB_HOST');

      expect(
        () => AppConfig.fromEnvironment(environment),
        _configError('DB_HOST'),
      );
    });

    test('rejects a non-numeric server port', () {
      final environment = _validEnvironment()..['SERVER_PORT'] = 'http';

      expect(
        () => AppConfig.fromEnvironment(environment),
        _configError('SERVER_PORT'),
      );
    });

    test('rejects an out-of-range server port', () {
      for (final port in <String>['0', '65536', '-1']) {
        final environment = _validEnvironment()..['SERVER_PORT'] = port;

        expect(
          () => AppConfig.fromEnvironment(environment),
          _configError('SERVER_PORT'),
          reason: 'port $port must be rejected',
        );
      }
    });

    test('rejects an invalid database port', () {
      final environment = _validEnvironment()..['DB_PORT'] = '70000';

      expect(
        () => AppConfig.fromEnvironment(environment),
        _configError('DB_PORT'),
      );
    });

    test('rejects a JWT secret shorter than 32 characters', () {
      final environment = _validEnvironment()..['JWT_SECRET'] = 'a' * 31;

      expect(
        () => AppConfig.fromEnvironment(environment),
        _configError('JWT_SECRET'),
      );
    });

    test('accepts a JWT secret with exactly 32 characters', () {
      final secret = 'a' * 32;
      final environment = _validEnvironment()..['JWT_SECRET'] = secret;

      final config = AppConfig.fromEnvironment(environment);

      expect(config.jwtSecret, secret);
    });

    test('reports every configuration problem at once', () {
      final environment = _validEnvironment()
        ..['SERVER_PORT'] = '0'
        ..['JWT_SECRET'] = 'short';

      expect(
        () => AppConfig.fromEnvironment(environment),
        throwsA(
          isA<ConfigException>()
              .having((error) => error.issues, 'issues', hasLength(2))
              .having(
                (error) => error.issues.join('\n'),
                'issues',
                allOf(contains('SERVER_PORT'), contains('JWT_SECRET')),
              ),
        ),
      );
    });
  });
}
