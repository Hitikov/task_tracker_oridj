import 'package:flutter/material.dart';

import '../api/person_controller.dart';
import '../pages/login_page.dart';
import 'theme.dart';

/// Корневой виджет приложения.
///
/// Приложение стартует с экрана входа; после успешной (пока демонстрационной)
/// авторизации открывается основная оболочка с боковым меню.
class ArijApp extends StatelessWidget {
  const ArijApp({super.key, required this.personController});

  final PersonController personController;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arij',
      debugShowCheckedModeBanner: false,
      theme: buildArijTheme(),
      home: LoginPage(personController: personController),
    );
  }
}
