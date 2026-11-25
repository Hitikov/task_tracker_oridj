import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_error.dart';
import 'home_page.dart';
import '../state/auth_providers.dart';

/// Экран регистрации: реальный вызов `POST /api/v1/auth/register`
/// через [AuthSession].
///
/// После валидации формы регистрация вызывается сразу; по успеху показывается
/// диалог «Вы зарегистрированы», а кнопка «Продолжить» открывает главный экран
/// (сервер вернул JWT, поэтому сессия уже активна).
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  /// Нужен, чтобы перепроверить «повторите пароль» при правке основного пароля.
  final _confirmFieldKey = GlobalKey<FormFieldState<String>>();
  bool _confirmTouched = false;

  final TextEditingController _loginController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _submitting = false;

  /// Простая проверка формата email: что-то@что-то.домен
  static final RegExp _emailRegExp = RegExp(
    r'^[\w.!#$%&’*+/=?^`{|}~-]+@[\w-]+(\.[\w-]+)+$',
  );

  @override
  void dispose() {
    _loginController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) {
      return 'Введите имя';
    }
    if (name.length > 100) {
      return 'Максимум 100 символов';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) {
      return 'Введите email';
    }
    if (!_emailRegExp.hasMatch(email)) {
      return 'Некорректный email';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) {
      return 'Введите пароль';
    }
    if (password.length < 8) {
      return 'Минимум 8 символов';
    }
    if (password.length > 128) {
      return 'Максимум 128 символов';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if ((value ?? '').isEmpty) {
      return 'Повторите пароль';
    }
    if (value != _passwordController.text) {
      return 'Пароли не совпадают';
    }
    return null;
  }

  Future<void> _onSubmit() async {
    _confirmTouched = true;
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(authSessionProvider.notifier).register(
            email: _emailController.text.trim(),
            name: _loginController.text.trim(),
            password: _passwordController.text,
          );
      if (mounted) setState(() => _submitting = false);
      await _showSuccessDialog();
    } catch (_) {
      // Ошибка отображается из состояния сессии.
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _showSuccessDialog() {
    if (!mounted) return Future.value();

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.check_circle_outline, size: 48),
          title: const Text('Вы зарегистрированы'),
          content: Text(
            'Аккаунт «${_emailController.text.trim()}» успешно создан. '
            'Вы уже вошли в систему.',
            textAlign: TextAlign.center,
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(); // закрыть диалог
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute<void>(
                    builder: (_) => HomePage(
                      login: _emailController.text.trim(),
                    ),
                  ),
                );
              },
              child: const Text('Продолжить'),
            ),
          ],
        );
      },
    );
  }

  /// Сообщение об ошибке сессии — показывается под формой.
  String? _sessionErrorText() {
    final error = ref.watch(authSessionProvider).error;
    if (error is ApiException) {
      return error.message;
    }
    return error != null
        ? 'Ошибка регистрации. Проверьте данные и сеть.'
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLoading = _submitting;
    final errorText = _sessionErrorText();

    return Scaffold(
      appBar: AppBar(title: const Text('Регистрация')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Создать аккаунт',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _loginController,
                    textInputAction: TextInputAction.next,
                    validator: _validateName,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: const InputDecoration(
                      labelText: 'Имя',
                      border: OutlineInputBorder(),
                      helperText: ' ',
                      errorMaxLines: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    validator: _validateEmail,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'name@example.com',
                      border: OutlineInputBorder(),
                      helperText: ' ',
                      errorMaxLines: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.next,
                    validator: _validatePassword,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    onChanged: (_) {
                      // Повтор пароля перепроверяем, только если его уже трогали.
                      if (_confirmTouched) {
                        _confirmFieldKey.currentState?.validate();
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Пароль',
                      border: const OutlineInputBorder(),
                      helperText: ' ',
                      errorMaxLines: 1,
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
                  const SizedBox(height: 8),
                  TextFormField(
                    key: _confirmFieldKey,
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    textInputAction: TextInputAction.done,
                    validator: _validateConfirmPassword,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    onChanged: (_) => _confirmTouched = true,
                    onFieldSubmitted: (_) => _onSubmit(),
                    decoration: InputDecoration(
                      labelText: 'Повторите пароль',
                      border: const OutlineInputBorder(),
                      helperText: ' ',
                      errorMaxLines: 1,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        tooltip:
                            _obscureConfirmPassword ? 'Показать' : 'Скрыть',
                        onPressed: () {
                          setState(
                            () => _obscureConfirmPassword =
                                !_obscureConfirmPassword,
                          );
                        },
                      ),
                    ),
                  ),
                  if (errorText != null)
                    Text(
                      errorText,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: isLoading ? null : _onSubmit,
                    icon: isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.person_add_outlined),
                    label: Text(
                      isLoading ? 'Регистрация…' : 'Зарегистрироваться',
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
