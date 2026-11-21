import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/person_controller.dart';
import '../pages/home_page.dart';
import '../pages/login_page.dart';
import '../state/auth_providers.dart';
import 'theme.dart';

/// Корневой виджет приложения.
///
/// Авторизованная сессия — основная оболочка [HomePage]; иначе —
/// экран [LoginPage].
class ArijApp extends ConsumerWidget {
  const ArijApp({
    super.key,
    required this.personController,
    this.demoMode = false,
  });

  final PersonController personController;
  final bool demoMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authenticatedUser = ref.watch(authSessionProvider).value;

    return MaterialApp(
      title: 'Arij',
      debugShowCheckedModeBanner: false,
      theme: buildArijTheme(),
      // Ограничиваем масштаб системного шрифта: на Android с крупным
      // textScaleFactor длинные строки иначе вылезают за карточки.
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final scaled = media.textScaler.clamp(
          minScaleFactor: 0.9,
          maxScaleFactor: 1.25,
        );
        return MediaQuery(
          data: media.copyWith(textScaler: scaled),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: authenticatedUser != null
          ? HomePage(
              login: authenticatedUser.email,
              personController: personController,
              demoMode: demoMode,
            )
          : LoginPage(demoMode: demoMode, personController: personController),
    );
  }
}
