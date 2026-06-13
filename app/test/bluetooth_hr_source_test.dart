import 'package:cardio/core/hr/bluetooth_hr_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseHeartRateMeasurement', () {
    test('parses 8-bit heart-rate measurements', () {
      expect(parseHeartRateMeasurement([0x00, 147]), 147);
    });

    test('parses 16-bit heart-rate measurements', () {
      expect(parseHeartRateMeasurement([0x01, 0x2c, 0x01]), 300);
    });

    test('returns null for malformed packets', () {
      expect(parseHeartRateMeasurement([]), isNull);
      expect(parseHeartRateMeasurement([0x00]), isNull);
      expect(parseHeartRateMeasurement([0x01, 0x2c]), isNull);
    });
  });

  group('bluetoothReconnectDelayForAttempt', () {
    test('starts immediately and backs off with a cap', () {
      expect(bluetoothReconnectDelayForAttempt(1), Duration.zero);
      expect(bluetoothReconnectDelayForAttempt(2), const Duration(seconds: 1));
      expect(bluetoothReconnectDelayForAttempt(3), const Duration(seconds: 2));
      expect(bluetoothReconnectDelayForAttempt(4), const Duration(seconds: 4));
      expect(bluetoothReconnectDelayForAttempt(7), const Duration(seconds: 30));
      expect(
        bluetoothReconnectDelayForAttempt(20),
        const Duration(seconds: 30),
      );
    });
  });
}
