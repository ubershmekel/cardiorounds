import 'package:cardio/core/db/database.dart';
import 'package:cardio/core/export/activity_export.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

const _tcxNs = 'http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  /// Ana wears strap-1 (primary) and strap-3, Ben wears strap-2, and a fourth
  /// stream from the fake source is unattributed.
  Future<int> seedGroupSession() async {
    final ana = await db.ensureDefaultAthlete();
    await db.updateAthlete(
      id: ana.id,
      name: 'Ana',
      restingHeartrate: 55,
      maxHeartrate: 190,
    );
    final ben = await db.insertAthlete(name: 'Ben & Co');
    final d1 = await db.upsertDevice(platformId: 'strap-1', name: 'Polar H10');
    final d2 = await db.upsertDevice(platformId: 'strap-2', name: 'Wahoo');
    final d3 = await db.upsertDevice(platformId: 'strap-3', name: 'Garmin');
    final started = await db.startActivityWithDevices(
      athleteId: ana.id,
      startedAtMs: DateTime.utc(2026, 10, 22, 7).millisecondsSinceEpoch,
      sportType: 'BJJ',
      deviceIds: [d1.id, d2.id, d3.id, null],
    );
    final [s1, s2, s3, s4] = started.hrSetIds;
    await db.setStreamAthlete(setId: s2, athleteId: ben.id);
    await db.setStreamAthlete(setId: s4, athleteId: null);
    await db.insertHrSample(setId: s1, tMs: 0, hr: 90);
    await db.insertHrSample(setId: s1, tMs: 1000, hr: null); // dropout
    await db.insertHrSample(setId: s1, tMs: 2000, hr: 120);
    await db.insertHrSample(setId: s2, tMs: 500, hr: 100);
    await db.insertHrSample(setId: s2, tMs: 1500, hr: 140);
    await db.insertHrSample(setId: s3, tMs: 0, hr: 91);
    await db.updateActivity(
      activityId: started.activityId,
      name: 'Open mat',
      note: 'Felt <good>',
    );
    await db.finalizeActivity(activityId: started.activityId, durationMs: 2500);
    await db.upsertWorkoutMarker(
      activityId: started.activityId,
      tMs: 0,
      durationMs: 2000,
    );
    await db
        .into(db.markers)
        .insert(
          MarkersCompanion.insert(
            activityId: started.activityId,
            tMs: 1000,
            kind: 'moment',
            name: const Value('Round start'),
          ),
        );
    return started.activityId;
  }

  XmlDocument encode(
    ActivityExport data,
    ExportOwner owner, {
    bool includeAll = true,
  }) => XmlDocument.parse(
    encodeTcx(
      data,
      owner: owner,
      includeAllAthletes: includeAll,
      appVersion: '1.2.3',
    ),
  );

  List<XmlElement> crSets(XmlDocument doc) =>
      doc.findAllElements('Set', namespaceUri: kTcxExtensionNamespace).toList();

  test(
    'owners: one per athlete, one per unattributed stream, primary first',
    () async {
      final data = await loadActivityExport(db, await seedGroupSession());
      expect(data.owners.map((o) => o.label), [
        'Ana',
        'Ben & Co',
        'Unassigned (unknown device)',
      ]);
      // Ana owns both of her straps.
      expect(data.sets.where(data.owners.first.owns), hasLength(2));
    },
  );

  test('a solo activity has exactly one owner', () async {
    final athlete = await db.ensureDefaultAthlete();
    final started = await db.startActivity(
      athleteId: athlete.id,
      startedAtMs: 0,
    );
    await db.insertHrSample(setId: started.hrSetId, tMs: 0, hr: 80);
    final data = await loadActivityExport(db, started.activityId);
    expect(data.owners, hasLength(1));
  });

  test(
    'trackpoints carry the chosen owner and keep NULL samples as gaps',
    () async {
      final data = await loadActivityExport(db, await seedGroupSession());
      final doc = encode(data, data.owners.first);

      final points = doc.findAllElements('Trackpoint', namespaceUri: _tcxNs);
      expect(points.map((p) => p.getElement('Time')!.innerText), [
        '2026-10-22T07:00:00.000Z',
        '2026-10-22T07:00:01.000Z',
        '2026-10-22T07:00:02.000Z',
      ]);
      expect(points.map((p) => p.getElement('HeartRateBpm')?.innerText), [
        '90',
        null,
        '120',
      ]);
      final lap = doc.findAllElements('Lap', namespaceUri: _tcxNs).single;
      expect(lap.getElement('TotalTimeSeconds')!.innerText, '2.5');
      expect(lap.getElement('AverageHeartRateBpm')!.innerText, '105');
      expect(lap.getElement('MaximumHeartRateBpm')!.innerText, '120');
      expect(
        doc.findAllElements('Notes', namespaceUri: _tcxNs).single.innerText,
        'Felt <good>',
      );

      final ben = encode(data, data.owners[1]);
      expect(
        ben
            .findAllElements('HeartRateBpm', namespaceUri: _tcxNs)
            .map((e) => e.innerText),
        ['100', '140'],
      );
    },
  );

  test(
    'include all athletes: every set, primary flag on the real primary',
    () async {
      final data = await loadActivityExport(db, await seedGroupSession());
      final doc = encode(data, data.owners[1]); // Ben's file, everyone included

      final sets = crSets(doc);
      expect(sets, hasLength(4));
      expect(sets.map((s) => s.getAttribute('primary')), [
        'true',
        null,
        null,
        null,
      ]);
      expect(
        sets.first
            .getElement('Device', namespaceUri: kTcxExtensionNamespace)!
            .getAttribute('platformId'),
        'strap-1',
      );
      final anaSnapshot = sets.first.getElement(
        'Athlete',
        namespaceUri: kTcxExtensionNamespace,
      )!;
      expect(anaSnapshot.getAttribute('name'), 'Ana');
      expect(anaSnapshot.getAttribute('restingHeartrate'), '55');
      expect(anaSnapshot.getAttribute('maxHeartrate'), '190');
      expect(
        sets.first
            .getElement('T', namespaceUri: kTcxExtensionNamespace)!
            .innerText,
        '0 1000 2000',
      );
      expect(
        sets.first
            .getElement('Hr', namespaceUri: kTcxExtensionNamespace)!
            .innerText,
        '90 - 120',
      );
      // The unattributed fake stream has neither device nor athlete.
      expect(sets.last.childElements.map((e) => e.localName), ['T', 'Hr']);
      // Ben's set fills the trackpoints, so its samples aren't repeated.
      expect(sets.map((s) => s.getAttribute('samples')), [
        null,
        'trackpoints',
        null,
        null,
      ]);
      expect(sets[1].childElements.map((e) => e.localName), [
        'Device',
        'Athlete',
      ]);
    },
  );

  test('excluding other athletes keeps only the owner\'s sets', () async {
    final data = await loadActivityExport(db, await seedGroupSession());

    final ben = crSets(encode(data, data.owners[1], includeAll: false));
    expect(ben, hasLength(1));
    expect(ben.single.getAttribute('primary'), 'true');
    // A one-athlete file has no sample lists in the extension at all.
    expect(ben.single.getAttribute('samples'), 'trackpoints');
    expect(
      ben.single.getElement('T', namespaceUri: kTcxExtensionNamespace),
      isNull,
    );
    expect(
      ben.single
          .getElement('Athlete', namespaceUri: kTcxExtensionNamespace)!
          .getAttribute('name'),
      'Ben & Co',
    );

    final ana = crSets(encode(data, data.owners.first, includeAll: false));
    expect(
      ana.map(
        (s) => s
            .getElement('Device', namespaceUri: kTcxExtensionNamespace)!
            .getAttribute('platformId'),
      ),
      ['strap-1', 'strap-3'],
    );
    // Only Ana's first strap is in the trackpoints; her second keeps its list.
    expect(
      ana.map(
        (s) =>
            s.getElement('T', namespaceUri: kTcxExtensionNamespace)?.innerText,
      ),
      [null, '0'],
    );
  });

  test(
    'activity fields and markers go into the extension either way',
    () async {
      final data = await loadActivityExport(db, await seedGroupSession());
      final doc = encode(data, data.owners[1], includeAll: false);

      final root = doc
          .findAllElements('CardioRounds', namespaceUri: kTcxExtensionNamespace)
          .single;
      expect(root.getAttribute('formatVersion'), '$kTcxFormatVersion');
      expect(root.getAttribute('appVersion'), '1.2.3');
      final activity = root.getElement(
        'Activity',
        namespaceUri: kTcxExtensionNamespace,
      )!;
      expect(activity.getAttribute('name'), 'Open mat');
      expect(activity.getAttribute('sportType'), 'BJJ');
      expect(activity.getAttribute('durationMs'), '2500');
      final markers = root.findElements(
        'Marker',
        namespaceUri: kTcxExtensionNamespace,
      );
      expect(markers.map((m) => m.getAttribute('kind')), ['workout', 'moment']);
      expect(markers.first.getAttribute('durationMs'), '2000');
      expect(markers.last.getAttribute('durationMs'), isNull);
      expect(markers.last.getAttribute('name'), 'Round start');
    },
  );

  test('an owner with no samples exports a lap without a track', () async {
    final athlete = await db.ensureDefaultAthlete();
    final started = await db.startActivity(
      athleteId: athlete.id,
      startedAtMs: 0,
    );
    final data = await loadActivityExport(db, started.activityId);
    final doc = encode(data, data.owners.single);
    expect(doc.findAllElements('Track', namespaceUri: _tcxNs), isEmpty);
    expect(doc.findAllElements('Lap', namespaceUri: _tcxNs), hasLength(1));
  });

  group('exportFileName', () {
    Activity activity({String? name, String? sportType}) => Activity(
      id: 1,
      startedAtMs: DateTime(2026, 10, 22, 7, 5).millisecondsSinceEpoch,
      durationMs: 0,
      name: name,
      sportType: sportType,
      createdAtMs: 0,
      updatedAtMs: 0,
    );

    test('slugs the name, falling back to sport type, then nothing', () {
      expect(
        exportFileName(activity(name: ' Evening Rounds #3! ')),
        'cardio-rounds-2026-10-22-0705-evening-rounds-3.tcx',
      );
      expect(
        exportFileName(activity(sportType: 'BJJ')),
        'cardio-rounds-2026-10-22-0705-bjj.tcx',
      );
      expect(
        exportFileName(activity(name: '日本')),
        'cardio-rounds-2026-10-22-0705.tcx',
      );
    });

    test('caps the slug length', () {
      final name = exportFileName(activity(name: 'a' * 100));
      expect(name, 'cardio-rounds-2026-10-22-0705-${'a' * 40}.tcx');
    });
  });
}
