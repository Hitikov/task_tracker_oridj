import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/arij_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final demoMode =
      String.fromEnvironment('DEMO_MODE', defaultValue: '') == 'true';

  runApp(
    ProviderScope(
      child: ArijApp(demoMode: demoMode),
    ),
  );
}
