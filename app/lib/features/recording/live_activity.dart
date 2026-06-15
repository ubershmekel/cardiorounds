import 'package:flutter/services.dart';

import '../../core/zones/zones.dart';

const MethodChannel _channel = MethodChannel('cardiorounds/live_activity');

class RecordingLiveActivity {
  const RecordingLiveActivity();

  Future<void> start({
    required int activityId,
    required String deviceName,
    required DateTime startedAt,
  }) async {
    await _invoke('start', {
      'activityId': activityId,
      'deviceName': deviceName,
      'startedAtMs': startedAt.millisecondsSinceEpoch,
    });
  }

  Future<void> update(LiveActivitySnapshot snapshot) async {
    await _invoke('update', snapshot.toJson());
  }

  Future<void> end({required int activityId}) async {
    await _invoke('end', {'activityId': activityId});
  }

  Future<void> _invoke(String method, Map<String, Object?> arguments) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // Non-iOS platforms do not provide the ActivityKit bridge.
    } on PlatformException {
      // Live Activities are best-effort; recording must continue if iOS rejects
      // an update because the device, OS version, or user settings disallow it.
    }
  }
}

class LiveActivitySnapshot {
  const LiveActivitySnapshot({
    required this.activityId,
    required this.elapsed,
    required this.bpm,
    required this.status,
    this.statusDetail,
    this.zoneLabel,
    this.zoneName,
    this.zoneColorHex,
  });

  final int activityId;
  final Duration elapsed;
  final int? bpm;
  final String status;
  final String? statusDetail;
  final String? zoneLabel;
  final String? zoneName;
  final String? zoneColorHex;

  Map<String, Object?> toJson() => {
    'activityId': activityId,
    'elapsedSeconds': elapsed.inSeconds,
    'bpm': bpm,
    'status': status,
    'statusDetail': statusDetail,
    'zoneLabel': zoneLabel,
    'zoneName': zoneName,
    'zoneColorHex': zoneColorHex,
  };
}

String zoneColorHex(Color color) {
  final value = color.toARGB32() & 0x00FFFFFF;
  return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

LiveActivitySnapshot liveActivitySnapshotFor({
  required int activityId,
  required Duration elapsed,
  required int? bpm,
  required String status,
  required Zone? zone,
  String? statusDetail,
}) {
  return LiveActivitySnapshot(
    activityId: activityId,
    elapsed: elapsed,
    bpm: bpm,
    status: status,
    statusDetail: statusDetail,
    zoneLabel: zone?.shortLabel,
    zoneName: zone?.name,
    zoneColorHex: zone == null ? null : zoneColorHex(zone.color),
  );
}
