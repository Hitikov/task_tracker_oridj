import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_tracker_oridj/updates/update_controller.dart';
import 'package:task_tracker_oridj/updates/update_downloader.dart';
import 'package:task_tracker_oridj/updates/update_installer.dart';
import 'package:task_tracker_oridj/updates/update_service.dart';

const UpdateInfo _update = UpdateInfo(
  version: '2.1.0',
  tag: 'v2.1.0',
  releaseUrl: 'https://example.com/release',
  downloadUrl: 'https://example.com/ArijSetup-2.1.0-x64.exe',
  assetName: 'ArijSetup-2.1.0-x64.exe',
  checksumUrl: 'https://example.com/SHA256SUMS.txt',
);

class _FakeUpdateService extends UpdateService {
  _FakeUpdateService({this.result = _update});

  final UpdateInfo? result;

  @override
  Future<UpdateInfo?> check({bool includePrerelease = false}) async => result;
}

class _FakeDownloader extends UpdateDownloader {
  _FakeDownloader({this.error});

  final Object? error;

  @override
  Future<File> download(
    UpdateInfo update, {
    void Function(int received, int total)? onProgress,
  }) async {
    if (error != null) throw error!;
    onProgress?.call(1, 1);
    return File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}update-test.exe');
  }
}

class _FakeInstaller extends UpdateInstaller {
  int calls = 0;
  String? installedPath;

  @override
  Future<void> install(UpdateInfo update, String filePath) async {
    calls++;
    installedPath = filePath;
  }
}

class _SumsAdapter implements HttpClientAdapter {
  const _SumsAdapter(this.sums);

  final String sums;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(sums, 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('UpdateDownloader', () {
    test('findHash parses SHA256SUMS.txt lines', () {
      expect(
        UpdateDownloader.findHash(
          'abc123  ArijSetup-2.1.0-x64.exe\ndef456 *app.apk\n',
          'ArijSetup-2.1.0-x64.exe',
        ),
        'abc123',
      );
      expect(
        UpdateDownloader.findHash('def456 *app.apk\n', 'app.apk'),
        'def456',
      );
      expect(UpdateDownloader.findHash('bad line\n', 'app.apk'), isNull);
    });

    test('verifyChecksum accepts matching hash and rejects mismatch', () async {
      final file = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}arij-checksum-test.bin',
      );
      await file.writeAsString('payload');
      addTearDown(() async {
        if (file.existsSync()) await file.delete();
      });

      final digest = sha256.convert(utf8.encode('payload')).toString();
      final goodDio = Dio()
        ..httpClientAdapter = _SumsAdapter('$digest  app.apk');
      final badDio = Dio()
        ..httpClientAdapter = _SumsAdapter('${'0' * 64}  app.apk');

      await UpdateDownloader(dio: goodDio).verifyChecksum(
          file,
          const UpdateInfo(
            version: '2.1.0',
            tag: 'v2.1.0',
            releaseUrl: 'https://example.com',
            assetName: 'app.apk',
            checksumUrl: 'https://example.com/SHA256SUMS.txt',
          ));

      await expectLater(
        UpdateDownloader(dio: badDio).verifyChecksum(
          file,
          const UpdateInfo(
            version: '2.1.0',
            tag: 'v2.1.0',
            releaseUrl: 'https://example.com',
            assetName: 'app.apk',
            checksumUrl: 'https://example.com/SHA256SUMS.txt',
          ),
        ),
        throwsStateError,
      );
    });
  });

  group('UpdateController', () {
    ProviderContainer makeContainer({
      UpdateInfo? result = _update,
      Object? downloadError,
      required _FakeInstaller installer,
    }) {
      return ProviderContainer(
        overrides: [
          updateServiceProvider
              .overrideWithValue(_FakeUpdateService(result: result)),
          updateDownloaderProvider
              .overrideWithValue(_FakeDownloader(error: downloadError)),
          updateInstallerProvider.overrideWithValue(installer),
        ],
      );
    }

    test('downloads and installs an update automatically', () async {
      final installer = _FakeInstaller();
      final container = makeContainer(installer: installer);
      addTearDown(container.dispose);

      await container.read(updateControllerProvider.notifier).checkAndInstall();

      final state = container.read(updateControllerProvider);
      expect(state.phase, UpdatePhase.idle);
      expect(installer.calls, 1);
      expect(installer.installedPath, contains('update-test.exe'));
    });

    test('shows the release page when no direct asset is available', () async {
      final installer = _FakeInstaller();
      final container = makeContainer(
        result: const UpdateInfo(
          version: '2.1.0',
          tag: 'v2.1.0',
          releaseUrl: 'https://example.com/release',
        ),
        installer: installer,
      );
      addTearDown(container.dispose);

      await container.read(updateControllerProvider.notifier).checkAndInstall();

      final state = container.read(updateControllerProvider);
      expect(state.phase, UpdatePhase.ready);
      expect(state.update?.releaseUrl, 'https://example.com/release');
      expect(installer.calls, 0);
    });

    test('failure is reported and can be retried', () async {
      final installer = _FakeInstaller();
      final container = makeContainer(
        downloadError: StateError('network failure'),
        installer: installer,
      );
      addTearDown(container.dispose);

      await container.read(updateControllerProvider.notifier).checkAndInstall();

      final state = container.read(updateControllerProvider);
      expect(state.phase, UpdatePhase.failed);
      expect(state.error, contains('network failure'));
      expect(installer.calls, 0);
    });
  });
}
