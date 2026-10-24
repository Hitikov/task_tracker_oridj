import 'package:flutter/material.dart';

import '../api/person_controller.dart';
import 'home_page.dart';
import 'register_page.dart';

/// Экран входа в приложение.
///
/// Реальная авторизация пока не подключена. Для демонстрации используется
/// фиксированная пара логин/пароль; при успехе открывается основная оболочка.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.personController});

  final PersonController personController;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  /// Демо-учётные данные, пока нет серверной авторизации.
  static const String _demoLogin = '12345';
  static const String _demoPassword = '12345';

  final TextEditingController _loginController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  /// Текст ошибки авторизации (неверный логин/пароль, недоступен сервер и т.п.).
  /// null — блок ошибки скрыт.
  String? _authError;

  @override
  void initState() {
    super.initState();
    // Как только пользователь начал что-то править — прячем старую ошибку.
    _loginController.addListener(_clearAuthError);
    _passwordController.addListener(_clearAuthError);
  }

  @override
  void dispose() {
    _loginController.removeListener(_clearAuthError);
    _passwordController.removeListener(_clearAuthError);
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _clearAuthError() {
    if (_authError != null) {
      setState(() => _authError = null);
    }
  }

  void _onSubmit() {
    final login = _loginController.text.trim();
    final password = _passwordController.text;

    if (login.isEmpty || password.isEmpty) {
      setState(() => _authError = 'Введите логин и пароль');
      return;
    }

    if (login != _demoLogin || password != _demoPassword) {
      setState(() => _authError = 'Неверный логин или пароль');
      return;
    }

    // TODO(backend): заменить на реальный запрос авторизации.
    // При ответе 401 показывать _authError, при успехе — открывать HomePage.
    setState(() => _authError = null);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => HomePage(
          login: login,
          personController: widget.personController,
        ),
      ),
    );
  }

  Future<void> _openRegistration() async {
    final registeredLogin = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const RegisterPage()),
    );

    if (!mounted || registeredLogin == null) {
      return;
    }

    // Возвращаемся на экран входа с уже заполненным логином.
    _loginController.text = registeredLogin;
    _passwordController.clear();
    setState(() => _authError = null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: AutofillGroup(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.task_alt,
                    size: 56,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Arij',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Трекер задач для командной работы',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Вход в Arij',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _loginController,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username],
                    decoration: const InputDecoration(
                      labelText: 'Логин',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => _onSubmit(),
                    decoration: InputDecoration(
                      labelText: 'Пароль',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        tooltip: _obscurePassword ? 'Показать' : 'Скрыть',
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _openRegistration,
                      child: const Text('Зарегистрироваться'),
                    ),
                  ),
                  const SizedBox(height: 4),
                  FilledButton(
                    onPressed: _onSubmit,
                    child: const Text('Войти'),
                  ),
                  _AuthErrorBanner(message: _authError),
                  const SizedBox(height: 8),
                  Text(
                    'Демо-вход: логин и пароль — 12345.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Блок с сообщением об ошибке авторизации.
///
/// Место под сообщение зарезервировано всегда ([_reservedHeight]), даже когда
/// [message] == null. Поэтому появление ошибки не меняет высоту формы и поля,
/// ссылка и кнопка «Войти» остаются ровно на своих местах.
class _AuthErrorBanner extends StatelessWidget {
  const _AuthErrorBanner({required this.message});

  final String? message;

  /// Верхний отступ (12) + паддинги контейнера (10 + 10) + строка текста (~22).
  static const double _reservedHeight = 54;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      height: _reservedHeight,
      child: AnimatedOpacity(
        opacity: message == null ? 0 : 1,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: colors.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 20,
                    color: colors.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      // Пробел вместо null — чтобы высота считалась одинаково.
                      message ?? ' ',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
