import 'package:flutter_test/flutter_test.dart';
import 'package:task_tracker_oridj/updates/update_service.dart';

void main() {
  group('UpdateService.isNewer', () {
    test('more significant version is newer', () {
      expect(UpdateService.isNewer('2.0.2', '2.0.1'), isTrue);
      expect(UpdateService.isNewer('3.0.0', '2.9.9'), isTrue);
    });

    test('same version is not newer', () {
      expect(UpdateService.isNewer('2.0.1', '2.0.1'), isFalse);
      expect(UpdateService.isNewer('2.0.1+3', '2.0.1'), isFalse);
    });

    test('older version is not newer', () {
      expect(UpdateService.isNewer('2.0.0', '2.0.1'), isFalse);
      expect(UpdateService.isNewer('1.9.9', '2.0.0'), isFalse);
    });
  });
}
