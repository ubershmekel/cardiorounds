import 'package:cardio/core/db/database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('device history', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'onlyKnownDevice returns null when there are no remembered devices',
      () async {
        expect(await db.onlyKnownDevice(), isNull);
      },
    );

    test('onlyKnownDevice returns the single remembered device', () async {
      await db.upsertDevice(platformId: 'strap-1', name: 'Strap 1');

      final device = await db.onlyKnownDevice();

      expect(device?.platformId, 'strap-1');
      expect(device?.name, 'Strap 1');
    });

    test(
      'onlyKnownDevice returns null when multiple devices were used',
      () async {
        await db.upsertDevice(platformId: 'strap-1', name: 'Strap 1');
        await db.upsertDevice(platformId: 'strap-2', name: 'Strap 2');

        expect(await db.onlyKnownDevice(), isNull);
      },
    );
  });
}
