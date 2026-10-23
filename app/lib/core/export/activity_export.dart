// Design docs: docs/design/export.md

import 'package:drift/drift.dart';

import '../db/database.dart';

/// Namespace of the Cardio Rounds `<Extensions>` block inside an exported TCX.
/// It identifies our data to the importer, so it must never change once files
/// exist; a breaking format change bumps [kTcxFormatVersion] instead.
const String kTcxExtensionNamespace =
    'https://github.com/ubershmekel/cardiorounds/tcx/v1';
const int kTcxFormatVersion = 1;
const String kTcxMimeType = 'application/vnd.garmin.tcx+xml';

const String _tcxNamespace =
    'http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2';

/// Longest activity-name slug kept in an export filename.
const int _fileNameSlugMaxLength = 40;

/// One HR stream with everything the export needs: its device and attributed
/// athlete (both may be gone/absent) and its samples in time order.
class ExportSet {
  const ExportSet({
    required this.set,
    required this.device,
    required this.athlete,
    required this.samples,
  });

  final SampleSet set;
  final Device? device;
  final Athlete? athlete;
  final List<HrSampleRow> samples;
}

/// A snapshot of one activity, loaded once and encoded without the database.
class ActivityExport {
  const ActivityExport({
    required this.activity,
    required this.sets,
    required this.markers,
  });

  final Activity activity;

  /// HR sets in `sample_sets.id` order; the first is the primary set.
  final List<ExportSet> sets;
  final List<Marker> markers;

  /// Distinct stream owners, primary set's owner first. An attributed athlete
  /// owns all of their streams; each unattributed stream is its own owner.
  List<ExportOwner> get owners {
    final result = <ExportOwner>[];
    for (final s in sets) {
      if (result.any((o) => o.owns(s))) continue;
      result.add(
        s.athlete != null
            ? ExportOwner._athlete(s.athlete!)
            : ExportOwner._unattributed(s),
      );
    }
    return result;
  }
}

/// Whose workout an export is for: the athlete (or unattributed stream) whose
/// HR fills the standard TCX trackpoints.
class ExportOwner {
  ExportOwner._athlete(Athlete this.athlete)
    : _unattributedSetId = null,
      _deviceName = null;
  ExportOwner._unattributed(ExportSet s)
    : athlete = null,
      _unattributedSetId = s.set.id,
      _deviceName = s.device?.name;

  final Athlete? athlete;
  final int? _unattributedSetId;
  final String? _deviceName;

  bool owns(ExportSet s) => athlete != null
      ? s.athlete?.id == athlete!.id
      : s.set.id == _unattributedSetId;

  /// Picker label: the athlete's name, or the device that recorded an
  /// unattributed stream.
  String get label {
    if (athlete != null) {
      return athlete!.name.trim().isEmpty ? 'Unnamed athlete' : athlete!.name;
    }
    return 'Unassigned (${_deviceName ?? 'unknown device'})';
  }
}

/// Loads everything [encodeTcx] needs for [activityId].
Future<ActivityExport> loadActivityExport(
  AppDatabase db,
  int activityId,
) async {
  final activity = await (db.select(
    db.activities,
  )..where((a) => a.id.equals(activityId))).getSingle();
  final sets = <ExportSet>[];
  for (final set in await db.hrSetsForActivity(activityId)) {
    final device = set.deviceId == null
        ? null
        : await (db.select(
            db.devices,
          )..where((d) => d.id.equals(set.deviceId!))).getSingleOrNull();
    final athlete = set.athleteId == null
        ? null
        : await (db.select(
            db.athletes,
          )..where((a) => a.id.equals(set.athleteId!))).getSingleOrNull();
    final samples =
        await (db.select(db.hrSamples)
              ..where((s) => s.setId.equals(set.id))
              ..orderBy([(s) => OrderingTerm.asc(s.tMs)]))
            .get();
    sets.add(
      ExportSet(set: set, device: device, athlete: athlete, samples: samples),
    );
  }
  final markers =
      await (db.select(db.markers)
            ..where((m) => m.activityId.equals(activityId))
            ..orderBy([(m) => OrderingTerm.asc(m.tMs)]))
          .get();
  return ActivityExport(activity: activity, sets: sets, markers: markers);
}

/// Encodes [data] as a TCX document.
///
/// [owner]'s first stream fills the standard trackpoints that other apps read.
/// The `cr:` extension carries every stream when [includeAllAthletes] is true,
/// otherwise only [owner]'s, so other people's HR doesn't leave the device.
String encodeTcx(
  ActivityExport data, {
  required ExportOwner owner,
  required bool includeAllAthletes,
  required String appVersion,
}) {
  final a = data.activity;
  final ownerSets = data.sets.where(owner.owns).toList();
  final track = ownerSets.isEmpty ? null : ownerSets.first;
  final extensionSets = includeAllAthletes ? data.sets : ownerSets;
  // The real primary set keeps its flag when it's in the file, so a full
  // export re-imports identically; otherwise the trackpoint stream is primary.
  final primarySetId = extensionSets.contains(data.sets.first)
      ? data.sets.first.set.id
      : track?.set.id;

  final out = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln(
      '<TrainingCenterDatabase xmlns="$_tcxNamespace" '
      'xmlns:cr="$kTcxExtensionNamespace">',
    )
    ..writeln('  <Activities>')
    ..writeln('    <Activity Sport="Other">')
    ..writeln('      <Id>${_tcxTime(a.startedAtMs)}</Id>');

  // One lap covering the whole activity; rounds-as-laps is a later step.
  final bpms = [
    for (final s in track?.samples ?? const <HrSampleRow>[])
      if (_validBpm(s.hr)) s.hr!,
  ];
  out
    ..writeln('      <Lap StartTime="${_tcxTime(a.startedAtMs)}">')
    ..writeln(
      '        <TotalTimeSeconds>${_seconds(a.durationMs)}</TotalTimeSeconds>',
    )
    ..writeln('        <DistanceMeters>0</DistanceMeters>')
    ..writeln('        <Calories>0</Calories>');
  if (bpms.isNotEmpty) {
    final avg = (bpms.reduce((x, y) => x + y) / bpms.length).round();
    final max = bpms.reduce((x, y) => x > y ? x : y);
    out
      ..writeln(
        '        <AverageHeartRateBpm><Value>$avg</Value></AverageHeartRateBpm>',
      )
      ..writeln(
        '        <MaximumHeartRateBpm><Value>$max</Value></MaximumHeartRateBpm>',
      );
  }
  out
    ..writeln('        <Intensity>Active</Intensity>')
    ..writeln('        <TriggerMethod>Manual</TriggerMethod>');
  // TCX requires at least one trackpoint per Track, so an empty stream omits it.
  if (track != null && track.samples.isNotEmpty) {
    out.writeln('        <Track>');
    for (final s in track.samples) {
      out
        ..writeln('          <Trackpoint>')
        ..writeln(
          '            <Time>${_tcxTime(a.startedAtMs + s.tMs)}</Time>',
        );
      // A NULL (or out-of-range) reading stays a time-only trackpoint, so the
      // dropout survives as a gap.
      if (_validBpm(s.hr)) {
        out.writeln(
          '            <HeartRateBpm><Value>${s.hr}</Value></HeartRateBpm>',
        );
      }
      out.writeln('          </Trackpoint>');
    }
    out.writeln('        </Track>');
  }
  out.writeln('      </Lap>');
  if (a.note != null && a.note!.isNotEmpty) {
    out.writeln('      <Notes>${_escape(a.note!)}</Notes>');
  }

  out
    ..writeln('      <Extensions>')
    ..writeln(
      '        <cr:CardioRounds formatVersion="$kTcxFormatVersion" '
      'appVersion="${_escape(appVersion)}">',
    )
    ..writeln(
      '          <cr:Activity${_attrs({'startedAtMs': a.startedAtMs, 'durationMs': a.durationMs, 'name': a.name, 'sportType': a.sportType, 'shapeStart': a.shapeStart, 'shapeMid': a.shapeMid, 'shapeEnd': a.shapeEnd})}/>',
    );
  for (final s in extensionSets) {
    // The trackpoint set's samples aren't repeated here: the trackpoints
    // already hold them losslessly (ms times, NULLs as HR-less points).
    final inTrackpoints = s == track;
    out.writeln(
      '          <cr:Set${_attrs({'kind': s.set.kind, if (s.set.id == primarySetId) 'primary': 'true', if (inTrackpoints) 'samples': 'trackpoints'})}>',
    );
    if (s.device != null) {
      out.writeln(
        '            <cr:Device${_attrs({'platformId': s.device!.platformId, 'name': s.device!.name})}/>',
      );
    }
    if (s.athlete != null) {
      // Raw profile values only: zones are recomputed on import, never stored.
      out.writeln(
        '            <cr:Athlete${_attrs({'name': s.athlete!.name, 'restingHeartrate': s.athlete!.restingHeartrate, 'maxHeartrate': s.athlete!.maxHeartrate})}/>',
      );
    }
    if (!inTrackpoints) {
      out
        ..writeln(
          '            <cr:T>${s.samples.map((r) => r.tMs).join(' ')}</cr:T>',
        )
        ..writeln(
          '            <cr:Hr>${s.samples.map((r) => r.hr ?? '-').join(' ')}</cr:Hr>',
        );
    }
    out.writeln('          </cr:Set>');
  }
  for (final m in data.markers) {
    out.writeln(
      '          <cr:Marker${_attrs({'tMs': m.tMs, 'durationMs': m.durationMs, 'kind': m.kind, 'name': m.name})}/>',
    );
  }
  out
    ..writeln('        </cr:CardioRounds>')
    ..writeln('      </Extensions>')
    ..writeln('    </Activity>')
    ..writeln('  </Activities>')
    ..writeln('</TrainingCenterDatabase>');
  return out.toString();
}

/// `cardio-rounds-2026-10-22-0700-evening-rounds.tcx`, in local time. The name
/// (or sport type) part is slugged so it's safe on every file system.
String exportFileName(Activity a) {
  final t = DateTime.fromMillisecondsSinceEpoch(a.startedAtMs);
  String two(int v) => v.toString().padLeft(2, '0');
  final stamp =
      '${t.year}-${two(t.month)}-${two(t.day)}-${two(t.hour)}${two(t.minute)}';
  var slug = (a.name ?? a.sportType ?? '')
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (slug.length > _fileNameSlugMaxLength) {
    slug = slug
        .substring(0, _fileNameSlugMaxLength)
        .replaceAll(RegExp(r'-+$'), '');
  }
  return slug.isEmpty
      ? 'cardio-rounds-$stamp.tcx'
      : 'cardio-rounds-$stamp-$slug.tcx';
}

// TCX's HeartRateBpm value is an unsigned byte with a minimum of 1.
bool _validBpm(int? hr) => hr != null && hr >= 1 && hr <= 255;

String _tcxTime(int epochMs) =>
    DateTime.fromMillisecondsSinceEpoch(epochMs, isUtc: true).toIso8601String();

String _seconds(int ms) {
  final s = ms / 1000;
  return s == s.truncateToDouble() ? s.toInt().toString() : s.toString();
}

/// ` key="value"` pairs, skipping nulls, with values XML-escaped.
String _attrs(Map<String, Object?> attrs) => attrs.entries
    .where((e) => e.value != null)
    .map((e) => ' ${e.key}="${_escape(e.value.toString())}"')
    .join();

String _escape(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');
