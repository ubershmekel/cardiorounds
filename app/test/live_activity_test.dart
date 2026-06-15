import 'package:cardio/app/colors.dart';
import 'package:cardio/core/zones/zones.dart';
import 'package:cardio/features/recording/live_activity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('serializes zone color as opaque RGB hex', () {
    expect(zoneColorHex(AppColors.zoneHard), '#FD6C00');
  });

  test('snapshot includes zone label name and color when available', () {
    final snapshot = liveActivitySnapshotFor(
      activityId: 1,
      elapsed: const Duration(seconds: 65),
      bpm: 165,
      status: 'Recording',
      zone: Zone.z4,
    );

    expect(snapshot.toJson(), containsPair('zoneLabel', 'Z4'));
    expect(snapshot.toJson(), containsPair('zoneName', 'Hard'));
    expect(snapshot.toJson(), containsPair('zoneColorHex', '#FD6C00'));
  });
}
