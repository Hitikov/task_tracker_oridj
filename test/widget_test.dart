import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:task_tracker_oridj/main.dart';
import 'package:task_tracker_oridj/database/app_database.dart';
import 'package:task_tracker_oridj/repositories/person_repository.dart';
import 'package:task_tracker_oridj/api/person_controller.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Создаем базу в памяти для теста
    final db = AppDatabase(NativeDatabase.memory());
    final repository = PersonRepository(db);
    final controller = PersonController(repository);

    // Передаем контроллер в MyApp
    await tester.pumpWidget(MyApp(personController: controller));

    // Проверяем, что приложение запустилось
    expect(find.byType(MyApp), findsOneWidget);
  });
}
