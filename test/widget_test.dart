import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:task_tracker_oridj/api/person_controller.dart';
import 'package:task_tracker_oridj/app/arij_app.dart';
import 'package:task_tracker_oridj/database/app_database.dart';
import 'package:task_tracker_oridj/repositories/person_repository.dart';
import 'package:task_tracker_oridj/state/auth_providers.dart';

import 'fakes.dart';

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

  Future<void> pumpApp(WidgetTester tester, {FakeAuthSession? session}) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(() => session ?? FakeAuthSession()),
        ],
        child: ArijApp(personController: personController),
      ),
    );
  }

  Future<void> login(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).at(0), 'user@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'secret123');
    await tester.tap(find.widgetWithText(FilledButton, 'Войти'));
    await tester.pumpAndSettle();
  }

  testWidgets('приложение стартует с экрана входа', (tester) async {
    await pumpApp(tester);

    expect(find.text('Arij'), findsOneWidget);
    expect(find.text('Вход в Arij'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Войти'), findsOneWidget);
  });

  testWidgets('пустая форма входа показывает ошибку', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Войти'));
    await tester.pumpAndSettle();

    expect(find.text('Введите email'), findsOneWidget);
    expect(find.text('Введите пароль'), findsOneWidget);
  });

  testWidgets('неверные данные не пускают в приложение', (tester) async {
    await pumpApp(
      tester,
      session: FakeAuthSession(
        loginResponder: (email, password) async =>
            password == 'wrongpass' ? null : fakeUser(email),
      ),
    );

    await tester.enterText(find.byType(TextField).at(0), 'demo@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'wrongpass');
    await tester.tap(find.widgetWithText(FilledButton, 'Войти'));
    await tester.pumpAndSettle();

    expect(find.text('Неверный email или пароль'), findsOneWidget);
    expect(find.text('Вход в Arij'), findsOneWidget);
  });

  testWidgets('вход открывает основную оболочку', (tester) async {
    await pumpApp(tester);

    await login(tester);

    expect(find.text('Дашборд'), findsWidgets);
    expect(find.byIcon(Icons.menu), findsOneWidget);
  });

  testWidgets('на широком экране боковое меню видно постоянно', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpApp(tester);
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

    await pumpApp(tester);
    await login(tester);

    expect(tester.takeException(), isNull);
  });

  testWidgets('из меню открывается раздел планов', (tester) async {
    await pumpApp(tester);
    await login(tester);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Планы развития'));
    await tester.pumpAndSettle();

    expect(find.text('Планы развития Arij'), findsOneWidget);
  });

  testWidgets('проверка обновлений доступна на главном экране', (tester) async {
    await pumpApp(tester);
    await login(tester);

    expect(find.byIcon(Icons.system_update), findsOneWidget);
    expect(find.text('Демо работы с БД'), findsNothing);
  });

  testWidgets('регистрация сразу открывает главный экран', (tester) async {
    await pumpApp(tester);

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

    await tester.tap(find.widgetWithText(FilledButton, 'Продолжить'));
    await tester.pumpAndSettle();

    expect(find.text('Вход в Arij'), findsNothing);
    expect(find.text('Дашборд'), findsWidgets);
  });
}
