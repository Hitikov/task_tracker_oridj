import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'update_service.dart';

/// Скачивает архив обновления во временную папку и проверяет его SHA256
/// по файлу `SHA256SUMS.txt` из того же релиза.
class UpdateDownloader {
  UpdateDownloader({Dio? dio, Future<Directory> Function()? directory})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                sendTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 60),
              ),
            ),
        _directory = directory ?? getTemporaryDirectory;

  final Dio _dio;
  final Future<Directory> Function() _directory;

  /// Скачивает файл обновления. Если контрольная сумма не совпала — выбрасывает
  /// [StateError] и удаляет файл.
  Future<File> download(
    UpdateInfo update, {
    void Function(int received, int total)? onProgress,
  }) async {
    final url = update.downloadUrl;
    if (url == null || url.isEmpty) {
      throw ArgumentError.value(url, 'downloadUrl', 'Обновление без файла');
    }

    final base = await _directory();
    final updatesDir = Directory(p.join(base.path, 'arij_updates'))
      ..createSync(recursive: true);
    final fileName = _safeFileName(update.assetName ?? 'update-${update.tag}');
    final target = File(p.join(updatesDir.path, fileName));
    if (target.existsSync()) target.deleteSync();

    try {
      await _dio.download(url, target.path, onReceiveProgress: onProgress);
      await verifyChecksum(target, update);
      return target;
    } on Object {
      if (target.existsSync()) target.deleteSync();
      rethrow;
    }
  }

  /// Сверяет SHA256 скачанного файла со значением из `SHA256SUMS.txt`.
  ///
  /// Отсутствие файла сумм, сетевая ошибка или отсутствие записи для ассета
  /// блокируют установку: обновление без проверки целостности опасно.
  Future<void> verifyChecksum(File file, UpdateInfo update) async {
    final checksumUrl = update.checksumUrl;
    if (checksumUrl == null || checksumUrl.isEmpty) {
      throw StateError('В релизе нет SHA256SUMS.txt — установка запрещена');
    }

    final String sums;
    try {
      final response = await _dio.get<String>(checksumUrl);
      sums = response.data ?? '';
    } on Object {
      throw StateError(
        'Не удалось получить SHA256SUMS.txt — установка запрещена',
      );
    }

    final expected = _findHash(sums, update.assetName ?? '');
    if (expected == null || !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(expected)) {
      throw StateError(
        'В SHA256SUMS.txt нет корректной суммы для ${update.assetName}',
      );
    }
    final actual = sha256.convert(await file.readAsBytes()).toString();
    if (actual.toLowerCase() != expected.toLowerCase()) {
      throw StateError('SHA256 обновления не совпал: файл повреждён');
    }
  }

  /// Ищет строку `<hash>  <имя файла>` в содержимом `SHA256SUMS.txt`.
  static String? findHash(String sums, String fileName) =>
      _findHash(sums, fileName);

  static String? _findHash(String sums, String fileName) {
    for (final line in const LineSplitter().convert(sums)) {
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length < 2) continue;
      final name = parts.last.replaceFirst(RegExp(r'^\*'), '');
      if (name == fileName || p.basename(name) == p.basename(fileName)) {
        return parts.first;
      }
    }
    return null;
  }

  /// Убирает из имени файла символы, недопустимые в путях Windows.
  static String _safeFileName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    return cleaned.isEmpty ? 'update.bin' : cleaned;
  }
}
