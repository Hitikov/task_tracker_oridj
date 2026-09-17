import 'package:flutter/material.dart';

import 'register_page.dart';

/// Экран входа. Пока без логики — только вёрстка и заглушки.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
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
    // TODO: подключить реальную авторизацию.
    // Сейчас это заглушка: любая попытка входа показывает ошибку,
    // чтобы было видно, как выглядит блок сообщения.
    // Когда появится бэкенд — ставить _authError только при ответе 401,
    // а при успехе делать _authError = null и переходить на главный экран.
    setState(() => _authError = 'Неверный логин или пароль');
  }

  void _openRegistration() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const RegisterPage()),
    );
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Вход в arij',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _loginController,
                  textInputAction: TextInputAction.next,
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
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _onSubmit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Войти'),
                ),
                // Сообщение об ошибке — под кнопкой, чтобы поля не смещались.
                _AuthErrorBanner(message: _authError),
              ],
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
