/// Результат проверки демо-учётных данных.
enum DemoAuthStatus {
  success,
  emptyFields,
  invalidCredentials,
}

/// Демо-логин, пока в приложении нет серверной авторизации.
const String demoLogin = '12345';

/// Демо-пароль, пока в приложении нет серверной авторизации.
const String demoPassword = '12345';

/// Проверяет демо-учётные данные.
///
/// Логин обрезается от пробелов по краям, пароль проверяется как есть.
/// Логика вынесена из UI, чтобы её можно было покрыть unit-тестами.
DemoAuthStatus checkDemoCredentials({
  required String login,
  required String password,
}) {
  final normalizedLogin = login.trim();

  if (normalizedLogin.isEmpty || password.isEmpty) {
    return DemoAuthStatus.emptyFields;
  }

  if (normalizedLogin != demoLogin || password != demoPassword) {
    return DemoAuthStatus.invalidCredentials;
  }

  return DemoAuthStatus.success;
}
