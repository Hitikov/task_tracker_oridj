import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_tracker_oridj/api/person_controller.dart';
import 'package:task_tracker_oridj/database/app_database.dart';
import 'package:task_tracker_oridj/repositories/person_repository.dart';

void main() {
  late AppDatabase db;
  late PersonController controller;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    controller = PersonController(PersonRepository(db));
  });

  tearDown(() async {
    await db.close();
  });

  group('PersonController', () {
    test('createPerson сохраняет пользователя и возвращает модель', () async {
      final created = await controller.createPerson('Анна');

      expect(created.name, 'Анна');
      expect(created.id, hasLength(36));

      final people = await controller.getPeople();
      expect(people, hasLength(1));
      expect(people.single.name, 'Анна');
      expect(people.single.id, created.id);
    });

    test('createPerson отклоняет пустое имя', () async {
      await expectLater(
        controller.createPerson('   '),
        throwsA(isA<Exception>()),
      );

      expect(await controller.getPeople(), isEmpty);
    });

    test('getPeople возвращает пользователей по алфавиту', () async {
      await controller.createPerson('Яна');
      await controller.createPerson('Анна');
      await controller.createPerson('Мария');

      final names =
          (await controller.getPeople()).map((person) => person.name).toList();

      expect(names, ['Анна', 'Мария', 'Яна']);
    });

    test('getPersonById находит существующего пользователя', () async {
      final created = await controller.createPerson('Иван');

      final found = await controller.getPersonById(created.id);

      expect(found, isNotNull);
      expect(found!.name, 'Иван');
    });

    test('getPersonById возвращает null для неизвестного ID', () async {
      expect(await controller.getPersonById('unknown-id'), isNull);
    });

    test('updatePerson меняет имя', () async {
      final created = await controller.createPerson('Иван');

      await controller.updatePerson(created.id, 'Пётр');

      final updated = await controller.getPersonById(created.id);
      expect(updated!.name, 'Пётр');
    });

    test('updatePerson отклоняет пустое имя', () async {
      final created = await controller.createPerson('Иван');

      await expectLater(
        controller.updatePerson(created.id, '  '),
        throwsA(isA<Exception>()),
      );

      final unchanged = await controller.getPersonById(created.id);
      expect(unchanged!.name, 'Иван');
    });

    test('updatePerson отклоняет неизвестный ID', () async {
      await expectLater(
        controller.updatePerson('unknown-id', 'Пётр'),
        throwsA(isA<Exception>()),
      );
    });

    test('deletePerson удаляет пользователя', () async {
      final created = await controller.createPerson('Иван');

      await controller.deletePerson(created.id);

      expect(await controller.getPersonById(created.id), isNull);
      expect(await controller.getPeople(), isEmpty);
    });
  });
}
