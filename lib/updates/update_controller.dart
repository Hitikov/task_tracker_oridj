import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'update_downloader.dart';
import 'update_installer.dart';
import 'update_service.dart';

/// Фаза автоматического обновления.
enum UpdatePhase {
  idle,
  checking,
  downloading,
  ready,
  installing,
  failed,
}

/// Состояние автоматического обновления.
class UpdateState {
  const UpdateState({
    this.phase = UpdatePhase.idle,
    this.update,
    this.progress = 0,
    this.downloadedPath,
    this.error,
  });

  final UpdatePhase phase;
  final UpdateInfo? update;
  final double progress;
  final String? downloadedPath;
  final String? error;

  bool get isBusy => switch (phase) {
        UpdatePhase.checking ||
        UpdatePhase.downloading ||
        UpdatePhase.installing =>
          true,
        _ => false,
      };

  UpdateState copyWith({
    UpdatePhase? phase,
    UpdateInfo? update,
    double? progress,
    String? downloadedPath,
    String? error,
    bool clearUpdate = false,
    bool clearError = false,
    bool clearDownloadedPath = false,
  }) {
    return UpdateState(
      phase: phase ?? this.phase,
      update: clearUpdate ? null : (update ?? this.update),
      progress: progress ?? this.progress,
      downloadedPath:
          clearDownloadedPath ? null : (downloadedPath ?? this.downloadedPath),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Загрузчик и установщик обновлений (инъекция зависимостей для тестов).
final updateDownloaderProvider =
    Provider<UpdateDownloader>((ref) => UpdateDownloader());

final updateInstallerProvider =
    Provider<UpdateInstaller>((ref) => const UpdateInstaller());

/// Оркестратор: проверка GitHub Releases → скачивание → установка.
///
/// Приложение проверяет обновления при старте и каждые 6 часов. Для Windows
/// установка беззвучная, для Android открывается системный установщик APK.
final updateControllerProvider =
    NotifierProvider<UpdateController, UpdateState>(UpdateController.new);

class UpdateController extends Notifier<UpdateState> {
  Timer? _timer;
  bool _autoStarted = false;

  @override
  UpdateState build() {
    ref.onDispose(() => _timer?.cancel());
    return const UpdateState();
  }

  /// Запускает фоновую проверку сейчас и затем каждые [interval].
  void startAutoUpdates({Duration interval = const Duration(hours: 6)}) {
    if (_autoStarted) return;
    _autoStarted = true;
    unawaited(checkAndInstall());
    _timer = Timer.periodic(interval, (_) => unawaited(checkAndInstall()));
  }

  /// Проверяет релиз, скачивает подходящий файл и запускает установку.
  Future<void> checkAndInstall() async {
    if (state.isBusy) return;
    state = state.copyWith(
      phase: UpdatePhase.checking,
      progress: 0,
      clearError: true,
      clearUpdate: true,
      clearDownloadedPath: true,
    );

    final update = await ref.read(updateServiceProvider).check();
    if (update == null) {
      state = const UpdateState();
      return;
    }

    if (update.downloadUrl == null) {
      // Платформа без автоустановки — UI покажет ссылку на страницу релиза.
      state = UpdateState(phase: UpdatePhase.ready, update: update);
      return;
    }

    state = state.copyWith(phase: UpdatePhase.downloading, update: update);
    try {
      final file = await ref.read(updateDownloaderProvider).download(
        update,
        onProgress: (received, total) {
          if (state.phase != UpdatePhase.downloading) return;
          final value = total > 0 ? received / total : 0.0;
          state = state.copyWith(
            progress: value < 0 ? 0 : (value > 1 ? 1 : value),
          );
        },
      );

      state = state.copyWith(
        phase: UpdatePhase.installing,
        downloadedPath: file.path,
        progress: 1,
      );
      await ref.read(updateInstallerProvider).install(update, file.path);
      state = const UpdateState();
    } on Object catch (error) {
      state = UpdateState(
        phase: UpdatePhase.failed,
        update: update,
        error: error.toString(),
      );
    }
  }
}
