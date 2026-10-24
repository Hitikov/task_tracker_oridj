import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_tracker_oridj/api/person_controller.dart';
import 'package:task_tracker_oridj/app/arij_app.dart';
import 'package:task_tracker_oridj/database/app_database.dart';
import 'package:task_tracker_oridj/repositories/person_repository.dart';

void main() {
  late AppDatabase db;
  late PersonController personController;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    personController = PersonController(PersonRepository(db));
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> login(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).at(0), '12345');
    await tester.enterText(find.byType(TextField).at(1), '12345');
    await tester.tap(find.widgetWithText(FilledButton, 'Войти'));
    await tester.pumpAndSettle();
  }

  testWidgets('приложение стартует с экрана входа', (tester) async {
    await tester.pumpWidget(ArijApp(personController: personController));

    expect(find.text('Arij'), findsOneWidget);
    expect(find.text('Вход в Arij'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Войти'), findsOneWidget);
  });

  testWidgets('пустая форма входа показывает ошибку', (tester) async {
    await tester.pumpWidget(ArijApp(personController: personController));

    await tester.tap(find.widgetWithText(FilledButton, 'Войти'));
    await tester.pumpAndSettle();

    expect(find.text('Введите логин и пароль'), findsOneWidget);
  });

  testWidgets('неверные данные не пускают в приложение', (tester) async {
    await tester.pumpWidget(ArijApp(personController: personController));

    await tester.enterText(find.byType(TextField).at(0), 'demo_user');
    await tester.enterText(find.byType(TextField).at(1), 'secret');
    await tester.tap(find.widgetWithText(FilledButton, 'Войти'));
    await tester.pumpAndSettle();

    expect(find.text('Неверный логин или пароль'), findsOneWidget);
    expect(find.text('Вход в Arij'), findsOneWidget);
  });

  testWidgets('вход открывает основную оболочку', (tester) async {
    await tester.pumpWidget(ArijApp(personController: personController));

    await login(tester);

    expect(find.text('Дашборд'), findsWidgets);
    expect(find.byIcon(Icons.menu), findsOneWidget);
  });

  testWidgets('на широком экране боковое меню видно постоянно', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ArijApp(personController: personController));
    await login(tester);

    expect(find.byIcon(Icons.menu), findsNothing);
    expect(find.widgetWithText(ListTile, 'Проекты'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Планы развития'), findsOneWidget);
  });

  testWidgets('компактное окно 1187x609 не вызывает переполнения',
      (tester) async {
    tester.view.physicalSize = const Size(1187, 609);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ArijApp(personController: personController));
    await login(tester);

    expect(tester.takeException(), isNull);
  });

  testWidgets('из меню открывается раздел планов', (tester) async {
    await tester.pumpWidget(ArijApp(personController: personController));
    await login(tester);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Планы развития'));
    await tester.pumpAndSettle();

    expect(find.text('Планы развития Arij'), findsOneWidget);
  });

  testWidgets('из меню открывается демо работы с БД', (tester) async {
    await tester.pumpWidget(ArijApp(personController: personController));
    await login(tester);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Демо работы с БД'));
    await tester.pumpAndSettle();

    expect(find.text('Демо работы с БД'), findsOneWidget);
    expect(
      find.widgetWithText(
          ElevatedButton, 'Запустить CRUD-демо (Проверка связи с БД)'),
      findsOneWidget,
    );
  });

  testWidgets('регистрация возвращает логин на экран входа', (tester) async {
    await tester.pumpWidget(ArijApp(personController: personController));

    await tester.tap(find.widgetWithText(TextButton, 'Зарегистрироваться'));
    await tester.pumpAndSettle();

    expect(find.text('Создать аккаунт'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'new_user');
    await tester.enterText(find.byType(TextFormField).at(1), 'new@example.com');
    await tester.enterText(find.byType(TextFormField).at(2), 'secret123');
    await tester.enterText(find.byType(TextFormField).at(3), 'secret123');

    await tester.tap(
      find.widgetWithText(FilledButton, 'Зарегистрироваться'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Вы зарегистрированы'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Перейти ко входу'));
    await tester.pumpAndSettle();

    expect(find.text('Вход в Arij'), findsOneWidget);
    final loginField = tester.widget<TextField>(find.byType(TextField).first);
    expect(loginField.controller?.text, 'new_user');
  });
}
