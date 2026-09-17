import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:task_tracker_oridj/main.dart';

void main() {
  testWidgets('Стартовый экран — форма входа', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Вход в arij'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Логин'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Пароль'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Войти'), findsOneWidget);
  });
}
