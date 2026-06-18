import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/colors.dart';
import '../../core/app_logger.dart';
import '../../core/db/database.dart';
import '../../core/db/providers.dart';
import '../../core/hr/bluetooth_hr_scanner.dart';
import '../../core/hr/bluetooth_hr_source.dart';
import '../../core/hr/fake_hr_source.dart';
import '../../core/hr/hr_source.dart';
import '../../core/hr/native_bluetooth_hr_source.dart';

class ConfirmRecordScreen extends ConsumerStatefulWidget {
  const ConfirmRecordScreen({super.key});

  @override
  ConsumerState<ConfirmRecordScreen> createState() =>
      _ConfirmRecordScreenState();
}

class _ConfirmRecordScreenState extends ConsumerState<ConfirmRecordScreen> {
  static const _scanInterval = Duration(seconds: 3);
  static const _scanTimeout = Duration(seconds: 2);
  static const _autoStartDelaySeconds = 5;

  final _sportTypeController = TextEditingController();
  final _sportTypeFocus = FocusNode();
  List<String> _pastSportTypes = const [];
  BluetoothHrScanner? _scanner;
  StreamSubscription<List<ScanResult>>? _scanResultsSub;
  Timer? _scanTimer;
  Timer? _autoStartTimer;
  List<ScanResult> _results = const [];
  Device? _onlyKnownDevice;
  Set<String> _knownPlatformIds = {};
  ScanResult? _autoStartResult;
  String? _autoStartPlatformId;
  int? _autoStartSecondsRemaining;
  // Set when the user explicitly dismisses the countdown; prevents it from
  // restarting on subsequent scan results within the same screen visit.
  bool _autoStartDismissed = false;
  bool _scanning = false;
  bool _connecting = false;
  String? _error;
  BluetoothHeartRateSource? _monitorSource;
  String? _monitoringPlatformId;
  ScanResult? _monitorScanResult;
  int? _monitorBpm;
  StreamSubscription<HrSample>? _monitorSampleSub;

  bool get _showFakeStrap => kIsWeb || kDebugMode;

  @override
  void initState() {
    super.initState();
    _prefillSportType();
    if (!kIsWeb) {
      _scanner = BluetoothHrScanner();
      _scanResultsSub = _scanner!.results.listen(_handleScanResults);
      _loadKnownDevices();
      _startScan();
      _scanTimer = Timer.periodic(_scanInterval, (_) => _startScan());
    }
  }

  Future<void> _startScan() async {
    if (_scanning || _connecting || _monitorSource != null) return;
    setState(() => _scanning = true);
    try {
      await _scanner?.start(timeout: _scanTimeout);
    } catch (e) {
      appLog('Scan', 'Scan failed: $e');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _prefillSportType() async {
    final pastSportTypes = await ref
        .read(databaseProvider)
        .distinctSportTypes();
    if (!mounted || pastSportTypes.isEmpty) return;
    setState(() => _pastSportTypes = pastSportTypes);
    // Don't clobber anything the user typed while the query was in flight.
    if (_sportTypeController.text.isEmpty) {
      _sportTypeController.text = pastSportTypes.first;
    }
  }

  Future<void> _loadKnownDevices() async {
    final allDevices = await ref.read(databaseProvider).allDevices();
    if (!mounted) return;
    setState(() {
      _knownPlatformIds = {for (final d in allDevices) d.platformId};
      _onlyKnownDevice = allDevices.length == 1 ? allDevices.single : null;
    });
    _maybeStartSingleDeviceCountdown(_results);
  }

  void _handleScanResults(List<ScanResult> results) {
    if (!mounted) return;
    setState(() => _results = results);
    if (_autoStartPlatformId != null &&
        !results.any((r) => r.device.remoteId.str == _autoStartPlatformId)) {
      _cancelAutoStartCountdown();
    }
    _maybeStartSingleDeviceCountdown(results);
  }

  void _maybeStartSingleDeviceCountdown(List<ScanResult> results) {
    if (_connecting ||
        _autoStartTimer != null ||
        _autoStartPlatformId != null ||
        _onlyKnownDevice == null ||
        _monitorSource != null ||
        _autoStartDismissed) {
      return;
    }
    for (final result in results) {
      if (result.device.remoteId.str == _onlyKnownDevice!.platformId) {
        _beginAutoStartCountdown(result);
        return;
      }
    }
  }

  void _beginAutoStartCountdown(ScanResult result) {
    if (!mounted) return;
    setState(() {
      _autoStartResult = result;
      _autoStartPlatformId = result.device.remoteId.str;
      _autoStartSecondsRemaining = _autoStartDelaySeconds;
    });
    _autoStartTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final remaining = _autoStartSecondsRemaining;
      if (_connecting || remaining == null) {
        timer.cancel();
        return;
      }
      if (remaining <= 1) {
        final result = _autoStartResult;
        _cancelAutoStartCountdown();
        if (result != null) _onDeviceTap(result);
        return;
      }
      setState(() => _autoStartSecondsRemaining = remaining - 1);
    });
  }

  void _cancelAutoStartCountdown() {
    _autoStartTimer?.cancel();
    _autoStartTimer = null;
    if (!mounted) return;
    setState(() {
      _autoStartResult = null;
      _autoStartPlatformId = null;
      _autoStartSecondsRemaining = null;
    });
  }

  // Called by the pause button — prevents the countdown from restarting within
  // this screen visit even if the same device keeps appearing in scan results.
  void _dismissAutoStartCountdown() {
    _cancelAutoStartCountdown();
    _autoStartDismissed = true;
  }

  Future<void> _startMonitoring(ScanResult result) async {
    if (_connecting) return;
    _cancelAutoStartCountdown();
    if (_monitorSource != null) await _stopMonitoring();
    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      await _scanner?.stop();
      final source = await BluetoothHeartRateSource.connect(result.device);
      if (!mounted) {
        await source.dispose();
        return;
      }
      setState(() {
        _monitorSource = source;
        _monitoringPlatformId = result.device.remoteId.str;
        _monitorScanResult = result;
        _connecting = false;
      });
      _monitorSampleSub = source.samples.listen((sample) {
        if (!mounted) return;
        // null BPM means signal/contact loss — clear so UI shows "Connecting…"
        setState(() => _monitorBpm = sample.bpm);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not connect: $e';
        _connecting = false;
      });
      await _startScan();
    }
  }

  Future<void> _stopMonitoring() async {
    await _monitorSampleSub?.cancel();
    _monitorSampleSub = null;
    final source = _monitorSource;
    _monitorSource = null;
    await source?.dispose();
    if (!mounted) return;
    setState(() {
      _monitoringPlatformId = null;
      _monitorScanResult = null;
      _monitorBpm = null;
    });
    _startScan();
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _autoStartTimer?.cancel();
    _scanResultsSub?.cancel();
    _monitorSampleSub?.cancel();
    _monitorSource?.dispose(); // fire-and-forget; dispose() can't await
    _sportTypeController.dispose();
    _sportTypeFocus.dispose();
    _scanner?.dispose();
    super.dispose();
  }

  Future<int> _createActivity(int athleteId) async {
    final db = ref.read(databaseProvider);
    final now = DateTime.now().millisecondsSinceEpoch;
    final sport = _sportTypeController.text.trim();
    return db.startActivity(
      athleteId: athleteId,
      startedAtMs: now,
      sportType: sport.isEmpty ? null : sport,
    );
  }

  Future<void> _startWith(HeartRateSource source) async {
    final db = ref.read(databaseProvider);
    final athlete = await db.ensureDefaultAthlete();
    final activityId = await _createActivity(athlete.id);
    ref.read(pendingHrSourceProvider.notifier).state = source;
    ref.read(activeRecordingIdProvider.notifier).state = activityId;
    if (!mounted) return;
    context.go('/record/recording/$activityId');
  }

  // Hands recording off to the native-backed source, which keeps collecting
  // heart-rate samples while iOS has the app suspended (see
  // NativeBluetoothHeartRateSource). The flutter_blue_plus monitor connection
  // used for the live preview is foreground-only and is disposed before this.
  Future<void> _startNativeRecording({
    required String platformId,
    required String name,
  }) async {
    await ref.read(databaseProvider).upsertDevice(platformId: platformId, name: name);
    final source = await NativeBluetoothHeartRateSource.start(
      remoteId: platformId,
      name: name,
    );
    await _startWith(source);
  }

  Future<void> _onSyntheticTap() async {
    if (_connecting) return;
    _cancelAutoStartCountdown();
    if (_monitorSource != null) await _stopMonitoring();
    setState(() => _connecting = true);
    try {
      await _startWith(FakeHeartRateSource());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not start: $e';
        _connecting = false;
      });
    }
  }

  Future<void> _onDeviceTap(ScanResult result) async {
    if (_connecting) return;
    _cancelAutoStartCountdown();

    final platformId = result.device.remoteId.str;

    // The live preview uses a flutter_blue_plus monitor connection. Recording is
    // handed to the native source instead, so first tear down the preview
    // connection (if any) to free the peripheral, then start native.
    final name = _monitoringPlatformId == platformId && _monitorSource != null
        ? _monitorSource!.deviceName
        : (result.device.platformName.isNotEmpty
              ? result.device.platformName
              : platformId);

    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      await _monitorSampleSub?.cancel();
      _monitorSampleSub = null;
      final monitor = _monitorSource;
      _monitorSource = null;
      await monitor?.dispose();
      await _scanner?.stop();
      setState(() {
        _monitoringPlatformId = null;
        _monitorScanResult = null;
        _monitorBpm = null;
      });
      await _startNativeRecording(platformId: platformId, name: name);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not connect: $e';
        _connecting = false;
      });
      await _startScan();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Start recording')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          RawAutocomplete<String>(
            textEditingController: _sportTypeController,
            focusNode: _sportTypeFocus,
            optionsBuilder: (_) => _pastSportTypes.take(5),
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      children: [
                        for (final sport in options)
                          ListTile(
                            title: Text(sport),
                            onTap: () => onSelected(sport),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
            fieldViewBuilder:
                (context, controller, focusNode, onFieldSubmitted) {
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'Sport type (optional)',
                      hintText: 'e.g. BJJ, Treadmill, Bike',
                      border: OutlineInputBorder(),
                    ),
                  );
                },
          ),
          const SizedBox(height: 24),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ..._buildDevicePicker(context),
          if (_connecting)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildDevicePicker(BuildContext context) {
    // Monitored device stays pinned at top even when scanning has stopped.
    final displayedResults = [
      ?_monitorScanResult,
      ..._results.where((r) => r.device.remoteId.str != _monitoringPlatformId),
    ];

    return [
      Row(
        children: [
          Text(
            'Nearby heart-rate devices',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Spacer(),
          if (_scanning)
            const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Scan again',
              onPressed:
                  (_connecting || _monitorSource != null) ? null : _startScan,
            ),
        ],
      ),
      const SizedBox(height: 8),
      if (_showFakeStrap) ...[
        _PickerCard(
          title: 'Simulated Bluetooth strap',
          isSimulated: true,
          onTap: _connecting ? null : _onSyntheticTap,
        ),
        const SizedBox(height: 8),
      ],
      if (displayedResults.isEmpty && !_scanning)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Text(
            'No heart-rate straps found yet.\n'
            'Make sure your strap is on and within range.',
            textAlign: TextAlign.center,
          ),
        )
      else
        ...displayedResults.map((r) {
          final platformId = r.device.remoteId.str;
          final isKnown = _knownPlatformIds.contains(platformId);
          final isMonitoring = _monitoringPlatformId == platformId;
          final isCountingDown = _autoStartPlatformId == platformId;
          // Non-monitored rows are stale while scanning is paused; dim them.
          final stale = _monitorSource != null && !isMonitoring;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Opacity(
              opacity: stale ? 0.4 : 1.0,
              child: _PickerCard(
              title: r.device.platformName.isEmpty
                  ? platformId
                  : r.device.platformName,
              rssi: r.rssi,
              isKnown: isKnown,
              countdownSeconds: isCountingDown ? _autoStartSecondsRemaining : null,
              monitorBpm: isMonitoring ? _monitorBpm : null,
              isMonitoring: isMonitoring,
              onTap: _connecting ? null : () => _onDeviceTap(r),
              onMonitor: _connecting
                  ? null
                  : (isMonitoring
                        ? _stopMonitoring
                        : () => _startMonitoring(r)),
              onCountdownCancel: isCountingDown
                  ? _dismissAutoStartCountdown
                  : null,
            ),
            ),
          );
        }),
    ];
  }
}

class _PickerCard extends StatelessWidget {
  const _PickerCard({
    required this.title,
    this.rssi,
    this.isKnown = false,
    this.isSimulated = false,
    this.countdownSeconds,
    this.monitorBpm,
    this.isMonitoring = false,
    required this.onTap,
    this.onMonitor,
    this.onCountdownCancel,
  });

  final String title;
  final int? rssi;
  final bool isKnown;
  final bool isSimulated;
  final int? countdownSeconds;
  final int? monitorBpm;
  final bool isMonitoring;
  final VoidCallback? onTap;
  final VoidCallback? onMonitor;
  final VoidCallback? onCountdownCancel;

  @override
  Widget build(BuildContext context) {
    final isCounting = countdownSeconds != null;
    final iconColor = isSimulated
        ? null
        : countdownSeconds != null
            ? AppColors.zoneMax      // Z5 pink  — auto-starting
            : isKnown
                ? AppColors.zoneHard // Z4 orange — recognised device
                : AppColors.zoneBaseline; // grey — first-time device

    Widget subtitle;
    if (isSimulated) {
      subtitle = Text(
        'Debug heart-rate stream',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    } else if (isMonitoring) {
      final bpm = monitorBpm;
      subtitle = Text(
        bpm != null ? '$bpm BPM' : 'Connecting…',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    } else {
      subtitle = _SignalBars(rssi: rssi ?? -90);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              isSimulated ? Icons.bug_report_outlined : Icons.favorite,
              color: iconColor,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  subtitle,
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (isCounting) ...[
              // Tap to cancel the countdown; separate Start to fire immediately.
              IconButton(
                icon: const Icon(Icons.pause),
                tooltip: 'Cancel auto-start',
                onPressed: onCountdownCancel,
              ),
              FilledButton.icon(
                icon: Text(
                  '$countdownSeconds',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                label: const Icon(Icons.play_arrow, size: 18),
                onPressed: onTap,
              ),
            ] else ...[
              if (!isSimulated)
                IconButton(
                  icon: Icon(
                    isMonitoring
                        ? Icons.stop_circle_outlined
                        : Icons.visibility_outlined,
                  ),
                  tooltip: isMonitoring ? 'Stop monitoring' : 'Monitor HR',
                  onPressed: onMonitor,
                ),
              FilledButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start'),
                onPressed: onTap,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SignalBars extends StatelessWidget {
  const _SignalBars({required this.rssi});
  final int rssi;

  int get _bars {
    if (rssi >= -60) return 4;
    if (rssi >= -70) return 3;
    if (rssi >= -80) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (int i = 0; i < 4; i++) ...[
          if (i > 0) const SizedBox(width: 2),
          _SignalBar(
            height: 4.0 + i * 3.0,
            active: i < _bars,
            color: color,
          ),
        ],
      ],
    );
  }
}

class _SignalBar extends StatelessWidget {
  const _SignalBar({
    required this.height,
    required this.active,
    required this.color,
  });
  final double height;
  final bool active;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: height,
      decoration: BoxDecoration(
        color: active ? color : color.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}
