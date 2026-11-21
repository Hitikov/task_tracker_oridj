import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_error.dart';
import '../auth/demo_auth.dart';
import '../state/auth_providers.dart';
import 'home_page.dart';
import 'register_page.dart';

/// Экран входа: реальная авторизация через [AuthSession] (REST API).
///
/// Дополнительно доступен демо-вход `12345/12345` (см. [demoLogin],
/// [demoPassword]) — локальный, без сети, включён через `DEMO_MODE=true`.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key, this.demoMode = false});

  final bool demoMode;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final TextEditingController _loginController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  /// Текст ошибки ввода (валидация полей, локальный вход).
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
    final status = checkDemoCredentials(login: login, password: password);

    switch (status) {
      case DemoAuthStatus.emptyFields:
        setState(() => _authError = 'Введите логин и пароль');
        return;
      case DemoAuthStatus.invalidCredentials:
        // В реальном режиме пробуем сервер — он решит.
        break;
      case DemoAuthStatus.success:
        if (widget.demoMode) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => HomePage(
                login: login,
                personController: ref.read(authRepositoryProvider),
              ),
            ),
          );
          return;
        }
    }

    setState(() => _authError = null);
    ref
        .read(authSessionProvider.notifier)
        .login(email: login, password: password);
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

  /// Ошибка сессии для показа пользователю.
  String? _sessionErrorText() {
    final session = ref.watch(authSessionProvider);
    final error = session.error;
    if (!session.hasError || error == null) {
      return null;
    }
    if (error is ApiException) {
      return error.message;
    }
    return 'Ошибка входа. Проверьте данные и сеть.';
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
                  _AuthErrorBanner(message: _authError ?? _sessionErrorText()),
                  const SizedBox(height: 8),
                  Text(
                    'Демо-вход: логин и пароль — $demoLogin (только DEMO_MODE).',
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
class _AuthErrorBanner extends StatelessWidget {
  const _AuthErrorBanner({required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (message == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                message!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
