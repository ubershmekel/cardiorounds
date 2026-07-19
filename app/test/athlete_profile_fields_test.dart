import 'package:cardio/core/db/database.dart';
import 'package:cardio/core/db/providers.dart';
import 'package:cardio/features/athletes/athlete_profile_fields.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Counts updateAthlete calls so we can assert the fields don't write on a
/// spurious mount/unmount — the trigger for the web write→rebuild→write loop
/// that also blanked the athlete row.
class _SpyDatabase extends AppDatabase {
  _SpyDatabase() : super.forTesting(NativeDatabase.memory());

  int updateCalls = 0;

  @override
  Future<void> updateAthlete({
    required int id,
    String? name,
    int? restingHeartrate,
    int? maxHeartrate,
    bool clearResting = false,
    bool clearMax = false,
  }) {
    updateCalls++;
    return super.updateAthlete(
      id: id,
      name: name,
      restingHeartrate: restingHeartrate,
      maxHeartrate: maxHeartrate,
      clearResting: clearResting,
      clearMax: clearMax,
    );
  }
}

Widget _host(AppDatabase db, Athlete? athlete) {
  return ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: MaterialApp(
      home: Scaffold(
        body: athlete == null
            ? const SizedBox()
            : AthleteProfileFields(athlete: athlete),
      ),
    ),
  );
}

void main() {
  testWidgets('does not write when mounted and unmounted without edits', (
    tester,
  ) async {
    final db = _SpyDatabase();
    addTearDown(db.close);
    final athlete = await db.insertAthlete(
      name: 'Y',
      maxHeartrate: 150,
      restingHeartrate: 50,
    );

    await tester.pumpWidget(_host(db, athlete));
    await tester.pump();
    expect(db.updateCalls, 0, reason: 'mounting must not write');

    // Unmount the fields. dispose() persists, but with no edits it must be a
    // no-op — otherwise the write re-fires the athletes stream and spins.
    await tester.pumpWidget(_host(db, null));
    await tester.pumpAndSettle();
    expect(db.updateCalls, 0, reason: 'unchanged unmount must not write');

    final row = await (db.select(
      db.athletes,
    )..where((a) => a.id.equals(athlete.id))).getSingle();
    expect(row.name, 'Y');
    expect(row.maxHeartrate, 150);
    expect(row.restingHeartrate, 50);
  });

  testWidgets('persists a real edit exactly once', (tester) async {
    final db = _SpyDatabase();
    addTearDown(db.close);
    final athlete = await db.insertAthlete(
      name: 'Y',
      maxHeartrate: 150,
      restingHeartrate: 50,
    );

    await tester.pumpWidget(_host(db, athlete));
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, 'Zoe');
    await tester.pump();

    // Unmount to flush the edit; the guard must let this real change through,
    // and only once (later no-op persists during teardown are suppressed).
    await tester.pumpWidget(_host(db, null));
    await tester.pumpAndSettle();
    expect(db.updateCalls, 1);

    final row = await (db.select(
      db.athletes,
    )..where((a) => a.id.equals(athlete.id))).getSingle();
    expect(row.name, 'Zoe');
    expect(row.maxHeartrate, 150);
    expect(row.restingHeartrate, 50);
  });
}
