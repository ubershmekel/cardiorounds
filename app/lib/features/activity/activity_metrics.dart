// Pure Activity-review analysis: per-stream zone resolution plus the shape and
// load metrics. Kept out of the widget so it can be unit-tested (see
// test/activity_metrics_test.dart) and so the "score every stream against its
// own athlete, never the default" rule lives in exactly one place.
//
// The default athlete is a Home-screen viewing context (whose live number to
// color), not an Activity-analysis input: an activity is analysed strictly from
// the athlete each stream is attributed to. See docs/design/multi-athlete.md.

import '../../core/db/database.dart' show Athlete, HrSampleRow;
import '../../core/zones/zones.dart';
import 'hr_stats.dart';

/// The zones a stream should be scored against: its **attributed athlete's**
/// (looked up in [athletes]), or null when the stream is unattributed or that
/// athlete has no valid max/resting HR.
///
/// Activity analysis is strictly per stream, so this **never** falls back to the
/// default athlete — an unattributed or profile-less stream stays locked rather
/// than borrowing someone else's zones. (Live recording colors unattributed
/// straps with the default athlete, but that's a viewing convenience, not
/// analysis; see docs/design/multi-athlete.md.)
ZoneSetup? zoneSetupForStream(int? athleteId, List<Athlete> athletes) {
  if (athleteId == null) return null;
  for (final a in athletes) {
    if (a.id == athleteId) {
      return zoneSetupFor(maxHr: a.maxHeartrate, restingHr: a.restingHeartrate);
    }
  }
  return null;
}

/// Max HR for each time-third of the workout window over one stream's [samples].
/// Profile-free: this is the workout's HR *shape*, not a scored metric, so it
/// renders even when the stream has no athlete profile. Returns three nulls when
/// there isn't enough data to split into thirds.
List<int?> computeThirds(
  List<HrSampleRow> samples, {
  int? windowStartMs,
  int? windowEndMs,
}) {
  final filtered = samples.where((r) {
    if (windowStartMs != null && r.tMs < windowStartMs) return false;
    if (windowEndMs != null && r.tMs > windowEndMs) return false;
    return true;
  }).toList();
  if (filtered.length < 3) return [null, null, null];
  final t0 = filtered.first.tMs;
  final t1 = filtered.last.tMs;
  if (t0 == t1) return [null, null, null];
  final span = (t1 - t0) / 3;
  return List.generate(3, (i) {
    final lo = t0 + (span * i).round();
    final hi = t0 + (span * (i + 1)).round();
    return HrStats.fromHeartRates(
      filtered.where((r) => r.tMs >= lo && r.tMs < hi).map((r) => r.hr),
    ).max;
  });
}

/// Total extra beats above [restingHr] over the workout window for one stream's
/// [samples] — the load metric ((bpm − rest_bpm) × minutes = beats). Returns null
/// when there aren't enough samples to integrate.
///
/// The caller supplies the stream's **own athlete's** resting HR, so each
/// stream's load reflects that person; a stream whose athlete has no profile
/// gets no load value rather than one computed against the default athlete.
int? computeExtraBeats(
  List<HrSampleRow> samples, {
  required int restingHr,
  int? windowStartMs,
  int? windowEndMs,
}) {
  final filtered = samples.where((r) {
    if (windowStartMs != null && r.tMs < windowStartMs) return false;
    if (windowEndMs != null && r.tMs > windowEndMs) return false;
    return r.hr != null && r.hr! > 0;
  }).toList();
  if (filtered.length < 2) return null;
  double extra = 0;
  for (int i = 0; i < filtered.length - 1; i++) {
    final hr = filtered[i].hr;
    if (hr == null || hr <= 0) continue;
    final dtMin = (filtered[i + 1].tMs - filtered[i].tMs) / 60000;
    extra += (hr - restingHr).clamp(0, 9999) * dtMin;
  }
  return extra.round();
}
