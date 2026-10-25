import 'package:flutter_test/flutter_test.dart';
import 'package:task_tracker_oridj/auth/demo_auth.dart';

void main() {
  group('checkDemoCredentials', () {
    test('принимает демо-логин и пароль', () {
      expect(
        checkDemoCredentials(login: demoLogin, password: demoPassword),
        DemoAuthStatus.success,
      );
    });

    test('обрезает пробелы вокруг логина', () {
      expect(
        checkDemoCredentials(login: '  $demoLogin  ', password: demoPassword),
        DemoAuthStatus.success,
      );
    });

    test('не обрезает пробелы в пароле', () {
      expect(
        checkDemoCredentials(login: demoLogin, password: ' $demoPassword '),
        DemoAuthStatus.invalidCredentials,
      );
    });

    test('возвращает emptyFields, если логин пустой', () {
      expect(
        checkDemoCredentials(login: '   ', password: demoPassword),
        DemoAuthStatus.emptyFields,
      );
    });

    test('возвращает emptyFields, если пароль пустой', () {
      expect(
        checkDemoCredentials(login: demoLogin, password: ''),
        DemoAuthStatus.emptyFields,
      );
    });

    test('отклоняет неверный логин', () {
      expect(
        checkDemoCredentials(login: 'demo', password: demoPassword),
        DemoAuthStatus.invalidCredentials,
      );
    });

    test('отклоняет неверный пароль', () {
      expect(
        checkDemoCredentials(login: demoLogin, password: 'secret'),
        DemoAuthStatus.invalidCredentials,
      );
    });

    test('логин чувствителен к регистру', () {
      expect(
        checkDemoCredentials(login: 'Demo', password: demoPassword),
        DemoAuthStatus.invalidCredentials,
      );
    });
  });
}
