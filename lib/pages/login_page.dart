import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/person_controller.dart';
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
  const LoginPage({super.key, this.demoMode = false, this.personController});

  final bool demoMode;

  /// Для открытия демо-страницы работы с БД (legacy Drift).
  final PersonController? personController;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _submitting = false;

  static final RegExp _emailRegExp = RegExp(
    r'^[\w.!#$%&’*+/=?^`{|}~-]+@[\w-]+(\.[\w-]+)+$',
  );

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateLogin(String? value) {
    final login = value?.trim() ?? '';
    if (login.isEmpty) {
      return 'Введите email';
    }
    if (login == demoLogin) {
      return null;
    }
    if (!_emailRegExp.hasMatch(login)) {
      return 'Некорректный email';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) {
      return 'Введите пароль';
    }
    if (_loginController.text.trim() == demoLogin && password == demoPassword) {
      return null;
    }
    if (password.length < 8) {
      return 'Минимум 8 символов';
    }
    if (password.length > 128) {
      return 'Максимум 128 символов';
    }
    return null;
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final login = _loginController.text.trim();
    final password = _passwordController.text;
    final status = checkDemoCredentials(login: login, password: password);

    if (status == DemoAuthStatus.success && widget.demoMode) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => HomePage(
            login: login,
            personController: widget.personController,
          ),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final user = await ref
          .read(authSessionProvider.notifier)
          .login(email: login, password: password);
      if (!mounted || user == null) return;
      // Явная навигация: смена `MaterialApp.home` не гарантирует переход,
      // если Navigator уже создан.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => HomePage(
            login: login,
            personController: widget.personController,
            demoMode: widget.demoMode,
          ),
        ),
      );
    } catch (_) {
      // Ошибка отображается из состояния сессии.
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _openRegistration() async {
    final registeredLogin = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const RegisterPage()),
    );

    if (!mounted || registeredLogin == null) {
      return;
    }

    _loginController.text = registeredLogin;
    _passwordController.clear();
    setState(() {});
  }

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
    final isLoading = _submitting;
    final errorText = _sessionErrorText();

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: AutofillGroup(
              child: Form(
                key: _formKey,
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
                    TextFormField(
                      controller: _loginController,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.username],
                      keyboardType: TextInputType.emailAddress,
                      validator: _validateLogin,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        helperText: ' ',
                        errorMaxLines: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      validator: _validatePassword,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      onFieldSubmitted: (_) => isLoading ? null : _onSubmit(),
                      decoration: InputDecoration(
                        labelText: 'Пароль',
                        border: const OutlineInputBorder(),
                        helperText: ' ',
                        errorMaxLines: 2,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          tooltip: _obscurePassword ? 'Показать' : 'Скрыть',
                          onPressed: () {
                            setState(
                              () => _obscurePassword = !_obscurePassword,
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: isLoading ? null : _openRegistration,
                        child: const Text('Зарегистрироваться'),
                      ),
                    ),
                    const SizedBox(height: 4),
                    FilledButton.icon(
                      onPressed: isLoading ? null : _onSubmit,
                      icon: isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      label: Text(isLoading ? 'Вход…' : 'Войти'),
                    ),
                    _AuthErrorBanner(message: errorText),
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
          crossAxisAlignment: CrossAxisAlignment.start,
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
                style: TextStyle(color: colors.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
