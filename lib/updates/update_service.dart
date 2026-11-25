import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Информация о доступном обновлении из GitHub Releases.
class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.releaseUrl,
    required this.tag,
    this.downloadUrl,
    this.assetName,
    this.checksumUrl,
  });

  /// Версия без префикса `v`, например `2.0.2`.
  final String version;

  /// Тег релиза, например `v2.0.2`.
  final String tag;

  /// Страница релиза — запасной вариант, если прямой файл не найден.
  final String releaseUrl;

  /// Прямая ссылка на установщик (Windows) или APK (Android).
  final String? downloadUrl;

  /// Имя файла актива — используется как имя локального файла и для SHA256.
  final String? assetName;

  /// Ссылка на `SHA256SUMS.txt` того же релиза (если есть).
  final String? checksumUrl;
}

/// Проверяет последний релиз на GitHub и сравнивает версии.
class UpdateService {
  UpdateService({
    Dio? dio,
    PackageInfo? packageInfo,
    TargetPlatform? platform,
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 5),
                receiveTimeout: const Duration(seconds: 5),
              ),
            ),
        _packageInfo = packageInfo,
        _platform = platform ?? defaultTargetPlatform;

  static const String _repo = 'Hitikov/task_tracker_oridj';
  static const String _releasesApi =
      'https://api.github.com/repos/$_repo/releases/latest';

  final Dio _dio;
  final PackageInfo? _packageInfo;
  final TargetPlatform _platform;

  /// Возвращает [UpdateInfo], если на GitHub есть более новая версия.
  ///
  /// Сетевые и API-ошибки не пробрасываются: обновление — не критичный путь.
  Future<UpdateInfo?> check({bool includePrerelease = false}) async {
    try {
      final info = _packageInfo ?? await PackageInfo.fromPlatform();
      final response = await _dio.get<Map<String, dynamic>>(
        _releasesApi,
        queryParameters: <String, dynamic>{'per_page': 1},
      );
      final data = response.data;
      if (data == null) return null;

      final tag = data['tag_name'] as String?;
      if (tag == null || tag.isEmpty) return null;
      final latestVersion = tag.replaceFirst(RegExp(r'^v'), '');
      if (data['prerelease'] == true && !includePrerelease) return null;
      if (!isNewer(latestVersion, info.version)) return null;

      final assets = (data['assets'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .toList();
      String? downloadUrl;
      String? assetName;
      String? checksumUrl;

      // Автоустановка поддерживается только для Windows (.exe) и Android (.apk).
      // Для остальных платформ открывается страница релиза.
      final preferred = switch (_platform) {
        TargetPlatform.windows => '.exe',
        TargetPlatform.android => '.apk',
        _ => null,
      };
      if (preferred != null) {
        for (final asset in assets) {
          final name = asset['name'] as String? ?? '';
          if (name.toLowerCase().endsWith(preferred)) {
            downloadUrl = asset['browser_download_url'] as String?;
            assetName = name;
            break;
          }
        }
      }
      for (final asset in assets) {
        final name = asset['name'] as String? ?? '';
        if (name == 'SHA256SUMS.txt') {
          checksumUrl = asset['browser_download_url'] as String?;
          break;
        }
      }

      return UpdateInfo(
        version: latestVersion,
        tag: tag,
        releaseUrl: (data['html_url'] as String?) ??
            'https://github.com/$_repo/releases/latest',
        downloadUrl: downloadUrl,
        assetName: assetName,
        checksumUrl: checksumUrl,
      );
    } catch (_) {
      return null;
    }
  }

  /// Сравнивает версии вида `2.0.1` / `2.0.1+3`.
  static bool isNewer(String candidate, String current) {
    List<int> parts(String value) => value
        .split(RegExp(r'[.\-+]'))
        .map(
          (p) => int.tryParse(p) ?? 0,
        )
        .toList();

    final a = parts(candidate);
    final b = parts(current);
    final length = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < length; i++) {
      final av = i < a.length ? a[i] : 0;
      final bv = i < b.length ? b[i] : 0;
      if (av > bv) return true;
      if (av < bv) return false;
    }
    return false;
  }
}

final updateServiceProvider = Provider<UpdateService>((ref) => UpdateService());
