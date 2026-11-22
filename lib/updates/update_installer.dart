import 'dart:io';

import 'package:open_filex/open_filex.dart';

import 'update_service.dart';

/// Запускает установку уже скачанного файла обновления.
///
/// * Windows — Inno Setup-установщик запускается беззвучно
///   (`PrivilegesRequired=lowest`, установка в `%LOCALAPPDATA%`, UAC не нужен).
///   Флаги `/CLOSEAPPLICATIONS /RESTARTAPPLICATIONS` закрывают приложение и
///   открывают его заново после установки.
/// * Android — APK открывается через FileProvider плагина `open_filex`;
///   финальное подтверждение установки делает Android (ОС запрещает тихую
///   установку сторонних APK).
class UpdateInstaller {
  const UpdateInstaller();

  Future<void> install(UpdateInfo update, String filePath) async {
    if (Platform.isWindows) {
      await Process.start(
        filePath,
        const <String>[
          '/VERYSILENT',
          '/NORESTART',
          '/CLOSEAPPLICATIONS',
          '/RESTARTAPPLICATIONS',
        ],
        mode: ProcessStartMode.detached,
      );
      // Приложение не завершаем сами: /CLOSEAPPLICATIONS закроет его в момент,
      // когда установщик начнёт заменять файлы, а /RESTARTAPPLICATIONS
      // откроет его заново после установки.
    }

    if (Platform.isAndroid) {
      final result = await OpenFilex.open(
        filePath,
        type: 'application/vnd.android.package-archive',
      );
      if (result.type != ResultType.done) {
        throw StateError('Не удалось открыть APK: ${result.message}');
      }
      return;
    }

    throw UnsupportedError(
      'Автоматическая установка не поддерживается на этой платформе',
    );
  }
}
