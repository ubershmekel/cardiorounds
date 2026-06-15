import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_logger.dart';
import '../../core/db/database.dart';
import '../../core/db/providers.dart';
import '../../core/hr/bluetooth_hr_scanner.dart';
import '../../core/hr/bluetooth_hr_source.dart';
import '../../core/hr/fake_hr_source.dart';
import '../../core/hr/hr_source.dart';

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
  ScanResult? _autoStartResult;
  String? _autoStartPlatformId;
  int? _autoStartSecondsRemaining;
  bool _scanning = false;
  bool _connecting = false;
  String? _error;

  bool get _showFakeStrap => kIsWeb || kDebugMode;

  @override
  void initState() {
    super.initState();
    _prefillSportType();
    if (!kIsWeb) {
      _scanner = BluetoothHrScanner();
      _scanResultsSub = _scanner!.results.listen(_handleScanResults);
      _loadOnlyKnownDevice();
      _startScan();
      _scanTimer = Timer.periodic(_scanInterval, (_) => _startScan());
    }
  }

  Future<void> _startScan() async {
    if (_scanning || _connecting) return;
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

  Future<void> _loadOnlyKnownDevice() async {
    final onlyKnownDevice = await ref.read(databaseProvider).onlyKnownDevice();
    if (!mounted) return;
    setState(() => _onlyKnownDevice = onlyKnownDevice);
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
        _onlyKnownDevice == null) {
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

  @override
  void dispose() {
    _scanTimer?.cancel();
    _autoStartTimer?.cancel();
    _scanResultsSub?.cancel();
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

  Future<void> _onSyntheticTap() async {
    if (_connecting) return;
    _cancelAutoStartCountdown();
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
    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      await _scanner?.stop();
      final source = await BluetoothHeartRateSource.connect(result.device);
      await ref
          .read(databaseProvider)
          .upsertDevice(
            platformId: result.device.remoteId.str,
            name: source.deviceName,
          );
      await _startWith(source);
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
              onPressed: _connecting ? null : _startScan,
            ),
        ],
      ),
      const SizedBox(height: 8),
      if (_showFakeStrap) ...[
        _PickerCard(
          title: 'Simulated Bluetooth strap',
          subtitle: 'Debug heart-rate stream for simulator and emulator runs.',
          icon: Icons.bug_report_outlined,
          onTap: _connecting ? null : _onSyntheticTap,
        ),
        const SizedBox(height: 8),
      ],
      if (_results.isEmpty && !_scanning)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Text(
            'No heart-rate straps found yet.\n'
            'Make sure your strap is on and within range.',
            textAlign: TextAlign.center,
          ),
        )
      else
        ..._results.map(
          (r) => _PickerCard(
            title: r.device.platformName.isEmpty
                ? r.device.remoteId.str
                : r.device.platformName,
            subtitle: 'Signal ${r.rssi} dBm',
            icon: Icons.favorite_outline,
            actionLabel: _deviceActionLabel(r),
            onTap: _connecting ? null : () => _onDeviceTap(r),
          ),
        ),
    ];
  }

  String _deviceActionLabel(ScanResult result) {
    if (result.device.remoteId.str == _autoStartPlatformId &&
        _autoStartSecondsRemaining != null) {
      return 'Starting in $_autoStartSecondsRemaining';
    }
    return 'Start recording';
  }
}

class _PickerCard extends StatelessWidget {
  const _PickerCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.actionLabel = 'Start recording',
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: Text(actionLabel),
              onPressed: onTap,
            ),
          ],
        ),
      ),
    );
  }
}
