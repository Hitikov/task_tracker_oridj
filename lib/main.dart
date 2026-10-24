import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'api/person_controller.dart';
import 'app/arij_app.dart';
import 'database/app_database.dart';
import 'repositories/person_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализируем подключение к базе данных Drift (файловая БД SQLite).
  final dbFolder = await getApplicationDocumentsDirectory();
  final file = File(p.join(dbFolder.path, 'db.sqlite'));
  final db = AppDatabase(NativeDatabase(file));

  // Создаём репозиторий и контроллер, передавая базу через Dependency Injection.
  final personRepository = PersonRepository(db);
  final personController = PersonController(personRepository);

  runApp(ArijApp(personController: personController));
}
