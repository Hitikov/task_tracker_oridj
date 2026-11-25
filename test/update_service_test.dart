import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:task_tracker_oridj/updates/update_service.dart';

/// Минимальный HTTP-адаптер: отдаёт заданный JSON вместо реального GitHub API.
class _JsonAdapter implements HttpClientAdapter {
  const _JsonAdapter(this.payload);

  final Map<String, dynamic> payload;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(payload),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const Map<String, dynamic> _release = <String, dynamic>{
  'tag_name': 'v2.1.0',
  'html_url':
      'https://github.com/Hitikov/task_tracker_oridj/releases/tag/v2.1.0',
  'prerelease': false,
  'assets': <dynamic>[
    <String, dynamic>{
      'name': 'ArijSetup-2.1.0-x64.exe',
      'browser_download_url': 'https://example.com/ArijSetup-2.1.0-x64.exe',
    },
    <String, dynamic>{
      'name': 'task_tracker_oridj-2.1.0-android.apk',
      'browser_download_url':
          'https://example.com/task_tracker_oridj-2.1.0-android.apk',
    },
    <String, dynamic>{
      'name': 'SHA256SUMS.txt',
      'browser_download_url': 'https://example.com/SHA256SUMS.txt',
    },
  ],
};

UpdateService _service({
  required TargetPlatform platform,
  Map<String, dynamic>? payload,
}) {
  final dio = Dio()..httpClientAdapter = _JsonAdapter(payload ?? _release);
  return UpdateService(
    dio: dio,
    packageInfo: PackageInfo(
      appName: 'Arij',
      packageName: 'com.example.task_tracker_oridj',
      version: '2.0.3',
      buildNumber: '4',
    ),
    platform: platform,
  );
}

void main() {
  group('UpdateService.isNewer', () {
    test('more significant version is newer', () {
      expect(UpdateService.isNewer('2.0.2', '2.0.1'), isTrue);
      expect(UpdateService.isNewer('3.0.0', '2.9.9'), isTrue);
    });

    test('same version is not newer', () {
      expect(UpdateService.isNewer('2.0.1', '2.0.1'), isFalse);
      expect(UpdateService.isNewer('2.0.1+3', '2.0.1+3'), isFalse);
    });

    test('build number alone counts as newer', () {
      expect(UpdateService.isNewer('2.0.1+3', '2.0.1'), isTrue);
      expect(UpdateService.isNewer('2.0.4+6', '2.0.4+5'), isTrue);
    });

    test('older version is not newer', () {
      expect(UpdateService.isNewer('2.0.0', '2.0.1'), isFalse);
      expect(UpdateService.isNewer('1.9.9', '2.0.0'), isFalse);
    });
  });

  group('UpdateService.check', () {
    test('Windows picks the installer and checksum', () async {
      final update = await _service(platform: TargetPlatform.windows).check();

      expect(update, isNotNull);
      expect(update!.version, '2.1.0');
      expect(update.tag, 'v2.1.0');
      expect(update.assetName, 'ArijSetup-2.1.0-x64.exe');
      expect(update.downloadUrl, contains('.exe'));
      expect(update.checksumUrl, contains('SHA256SUMS.txt'));
    });

    test('Android picks the APK', () async {
      final update = await _service(platform: TargetPlatform.android).check();

      expect(update, isNotNull);
      expect(update!.assetName, 'task_tracker_oridj-2.1.0-android.apk');
      expect(update.downloadUrl, contains('.apk'));
    });

    test('unsupported platforms only get the release page', () async {
      final update = await _service(platform: TargetPlatform.iOS).check();

      expect(update, isNotNull);
      expect(update!.downloadUrl, isNull);
      expect(update.releaseUrl, contains('releases/tag/v2.1.0'));
    });

    test('prerelease is ignored by default', () async {
      final payload = Map<String, dynamic>.from(_release)
        ..['prerelease'] = true;
      final update = await _service(
        platform: TargetPlatform.windows,
        payload: payload,
      ).check();

      expect(update, isNull);
    });
  });
}
