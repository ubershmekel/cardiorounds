import '../db/database.dart' show HrSampleRow;
import 'zones.dart';

/// Total time spent in each zone over a sample series, plus time where the
/// strap reported no HR (signal loss). All values in milliseconds.
class ZoneTimes {
  const ZoneTimes({required this.perZone, required this.unknownMs});

  final Map<Zone, int> perZone;
  final int unknownMs;

  int get knownMs => perZone.values.fold(0, (a, b) => a + b);
  int get totalMs => knownMs + unknownMs;
}

/// Step-function attribution: between consecutive samples, the elapsed time
/// is credited to the *earlier* sample's zone. Samples with a null bpm
/// contribute to [ZoneTimes.unknownMs].
///
/// If [windowStartMs] / [windowEndMs] are non-null, only samples inside the
/// window are considered.
ZoneTimes computeZoneTimes(
  List<HrSampleRow> samples,
  ZoneSetup setup, {
  int? windowStartMs,
  int? windowEndMs,
}) {
  final perZone = <Zone, int>{for (final z in Zone.values) z: 0};
  var unknownMs = 0;

  final inWindow = samples.where((s) {
    if (windowStartMs != null && s.tMs < windowStartMs) return false;
    if (windowEndMs != null && s.tMs > windowEndMs) return false;
    return true;
  }).toList();

  for (var i = 0; i < inWindow.length - 1; i++) {
    final s = inWindow[i];
    final deltaMs = inWindow[i + 1].tMs - s.tMs;
    if (deltaMs <= 0) continue;
    final zone = setup.zoneFor(s.hr);
    if (zone == null) {
      unknownMs += deltaMs;
    } else {
      perZone[zone] = perZone[zone]! + deltaMs;
    }
  }
  return ZoneTimes(perZone: perZone, unknownMs: unknownMs);
}
