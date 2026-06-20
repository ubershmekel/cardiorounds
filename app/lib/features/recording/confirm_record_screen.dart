import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_logger.dart';
import '../../core/db/database.dart';
import '../../core/db/providers.dart';
import '../../core/hr/bluetooth_hr_scanner.dart';
import '../../core/hr/bluetooth_hr_source.dart';
import '../../core/hr/fake_hr_source.dart';
import '../../core/hr/hr_scanner.dart';
import '../../core/hr/hr_source.dart';
import '../../core/hr/native_bluetooth_hr_source.dart';
import '../../core/hr/native_hr_scanner.dart';
import '../../core/settings/app_settings.dart';

/// A row in the device picker — either a scanned Bluetooth device or the
/// simulated strap. Snapshotting the display fields here keeps the selected
/// entry usable for committing even if it later drops out of scan results.
class _Entry {
  const _Entry({
    required this.id,
    required this.name,
    this.rssi,
    this.isKnown = false,
    this.isFake = false,
  });

  final String id;
  final String name;
  final int? rssi;
  final bool isKnown;
  final bool isFake;
}

class ConfirmRecordScreen extends ConsumerStatefulWidget {
  const ConfirmRecordScreen({super.key});

  @override
  ConsumerState<ConfirmRecordScreen> createState() =>
      _ConfirmRecordScreenState();
}

class _ConfirmRecordScreenState extends ConsumerState<ConfirmRecordScreen> {
  static const _scanInterval = Duration(seconds: 3);
  static const _scanTimeout = Duration(seconds: 2);
  static const _fakeId = '__fake__';

  final _sportTypeController = TextEditingController();
  final _sportTypeFocus = FocusNode();
  List<String> _pastSportTypes = const [];

  HrScanner? _scanner;
  StreamSubscription<List<ScannedDevice>>? _scanResultsSub;
  Timer? _scanTimer;
  bool _scanning = false;

  // Frozen display order of device ids; newcomers append to the bottom.
  final List<String> _orderedIds = [];
  final Map<String, ScannedDevice> _devicesById = {};
  Set<String> _knownPlatformIds = {};
  Device? _onlyKnownDevice;
  // The known single device is auto-selected at most once per screen visit.
  bool _autoSelectConsumed = false;

  // The currently-selected entry holds a live preview connection (so the user
  // can confirm sensor contact) that is handed straight to recording on Start.
  _Entry? _selected;
  HeartRateSource? _previewSource;
  int? _previewBpm;
  StreamSubscription<HrSample>? _previewSampleSub;
  bool _connectingPreview = false;
  // Start tapped while the preview is still connecting; honored once ready.
  bool _startRequested = false;
  // Committing the selected source to a new recording (full-screen spinner).
  bool _starting = false;
  String? _error;

  bool get _showFakeStrap => ref.watch(fakeHrDeviceEnabledProvider);

  bool get _busy => _connectingPreview || _startRequested || _starting;

  // On iOS the native CoreBluetooth central handles scanning and preview, so
  // connecting for preview and then recording uses a single uninterrupted
  // connection. On Android we stay on FlutterBluePlus throughout.
  bool get _useNative => !kIsWeb && Platform.isIOS;

  @override
  void initState() {
    super.initState();
    _prefillSportType();
    if (!kIsWeb) {
      _scanner = _useNative ? NativeHrScanner() : BluetoothHrScanner();
      _init();
    }
  }

  // Load known devices before scanning so the first-paint ordering can put
  // known devices first.
  Future<void> _init() async {
    await _loadKnownDevices();
    if (!mounted) return;
    _scanResultsSub = _scanner!.results.listen(_handleScanResults);
    _startScan();
    // Native scanner accumulates results continuously; periodic re-scan only
    // needed for FlutterBluePlus which times out after each window.
    if (!_useNative) {
      _scanTimer = Timer.periodic(_scanInterval, (_) => _startScan());
    }
  }

  Future<void> _startScan() async {
    if (_scanning || _busy || _selected != null) return;
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
  }

  void _handleScanResults(List<ScannedDevice> results) {
    if (!mounted) return;
    setState(() {
      for (final d in results) {
        _devicesById[d.platformId] = d;
      }
      // Append devices not seen yet this visit. The first population is sorted
      // known-first/signal-second; after that, newcomers append in discovery
      // order — the list never reshuffles under the user.
      final newcomers = results
          .where((d) => !_orderedIds.contains(d.platformId))
          .toList();
      if (_orderedIds.isEmpty) {
        newcomers.sort((a, b) {
          final aKnown = _knownPlatformIds.contains(a.platformId);
          final bKnown = _knownPlatformIds.contains(b.platformId);
          if (aKnown != bKnown) return aKnown ? -1 : 1;
          return b.rssi.compareTo(a.rssi);
        });
      }
      _orderedIds.addAll(newcomers.map((d) => d.platformId));
    });
    _maybeAutoSelect();
  }

  void _maybeAutoSelect() {
    if (_autoSelectConsumed || _selected != null || _onlyKnownDevice == null) {
      return;
    }
    final device = _devicesById[_onlyKnownDevice!.platformId];
    if (device == null) return;
    _autoSelectConsumed = true;
    _select(
      _Entry(
        id: device.platformId,
        name: device.name,
        rssi: device.rssi,
        isKnown: true,
      ),
    );
  }

  Future<void> _disposePreview() async {
    await _previewSampleSub?.cancel();
    _previewSampleSub = null;
    final source = _previewSource;
    _previewSource = null;
    await source?.dispose();
  }

  Future<void> _select(_Entry entry) async {
    if (_starting) return;
    // Any interaction consumes the one-shot auto-selection.
    _autoSelectConsumed = true;
    // Tapping the selected row again deselects it.
    if (_selected?.id == entry.id) {
      await _deselect();
      return;
    }

    await _disposePreview();
    setState(() {
      _selected = entry;
      _previewBpm = null;
      _connectingPreview = true;
      _startRequested = false;
      _error = null;
    });
    await _scanner?.stop();
    try {
      final HeartRateSource source;
      if (entry.isFake) {
        source = FakeHeartRateSource();
      } else if (_useNative) {
        source = await NativeBluetoothHeartRateSource.start(
          remoteId: entry.id,
          name: entry.name,
        );
      } else {
        source = await BluetoothHeartRateSource.connect(
          entry.id,
          name: entry.name,
        );
      }
      // The selection may have changed (or the screen closed) while connecting.
      if (!mounted || _selected?.id != entry.id) {
        await source.dispose();
        return;
      }
      setState(() {
        _previewSource = source;
        _connectingPreview = false;
      });
      _previewSampleSub = source.samples.listen((sample) {
        if (!mounted) return;
        setState(() => _previewBpm = sample.bpm);
      });
      // Honor a Start that was tapped before the connection was ready.
      if (_startRequested) {
        _startRequested = false;
        await _commitStart();
      }
    } catch (e) {
      if (!mounted || _selected?.id != entry.id) return;
      setState(() {
        _error = 'Could not connect: $e';
        _selected = null;
        _connectingPreview = false;
        _startRequested = false;
      });
      await _startScan();
    }
  }

  Future<void> _deselect() async {
    await _disposePreview();
    if (!mounted) return;
    setState(() {
      _selected = null;
      _previewBpm = null;
      _connectingPreview = false;
      _startRequested = false;
    });
    _startScan();
  }

  void _onStart() {
    final entry = _selected;
    if (entry == null || _starting || _startRequested) return;
    if (_connectingPreview || _previewSource == null) {
      // Don't make the user wait for pairing — remember the intent and fire as
      // soon as the preview connection is ready.
      setState(() => _startRequested = true);
      return;
    }
    _commitStart();
  }

  Future<void> _commitStart() async {
    final entry = _selected;
    final source = _previewSource;
    if (entry == null || source == null) return;
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      // Do all the fallible prep while we still own the source, so a failure
      // here leaves the live preview connection intact and Start retryable.
      await _scanner?.stop();
      final db = ref.read(databaseProvider);
      if (!entry.isFake) {
        await db.upsertDevice(platformId: entry.id, name: source.deviceName);
      }
      final athlete = await db.ensureDefaultAthlete();
      final activityId = await _createActivity(athlete.id);
      // Handoff: from here the recording controller owns the connection — no
      // disconnect, no reconnect. Stop listening before relinquishing.
      await _previewSampleSub?.cancel();
      _previewSampleSub = null;
      // If the screen is gone, keep ownership (dispose() will tear it down).
      if (!mounted) return;
      _previewSource = null;
      ref.read(pendingHrSourceProvider.notifier).state = source;
      ref.read(activeRecordingIdProvider.notifier).state = activityId;
      context.go('/record/recording/$activityId');
    } catch (e) {
      if (!mounted) return;
      // _previewSource is still held and connected; the user can press Start
      // again without reconnecting.
      setState(() {
        _error = 'Could not start: $e';
        _starting = false;
      });
    }
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

  @override
  void dispose() {
    _scanTimer?.cancel();
    _scanResultsSub?.cancel();
    _previewSampleSub?.cancel();
    _previewSource?.dispose(); // fire-and-forget; dispose() can't await
    _sportTypeController.dispose();
    _sportTypeFocus.dispose();
    _scanner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Start recording')),
      // Tapping outside the sport-type field dismisses its autocomplete overlay
      // and the keyboard by dropping focus.
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSportTypeField(),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start'),
              onPressed: (_selected == null || _starting || _startRequested)
                  ? null
                  : _onStart,
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
            if (_starting || _startRequested)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSportTypeField() {
    return RawAutocomplete<String>(
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
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Sport type (optional)',
            hintText: 'e.g. BJJ, Treadmill, Bike',
            border: OutlineInputBorder(),
          ),
        );
      },
    );
  }

  List<_Entry> _displayedEntries() {
    return [
      if (_showFakeStrap)
        const _Entry(
          id: _fakeId,
          name: 'Simulated Bluetooth strap',
          isFake: true,
        ),
      for (final id in _orderedIds)
        if (_devicesById[id] case final d?)
          _Entry(
            id: id,
            name: d.name,
            rssi: d.rssi,
            isKnown: _knownPlatformIds.contains(id),
          ),
    ];
  }

  List<Widget> _buildDevicePicker(BuildContext context) {
    final entries = _displayedEntries();

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
              onPressed: (_busy || _selected != null) ? null : _startScan,
            ),
        ],
      ),
      const SizedBox(height: 8),
      if (entries.isEmpty && !_scanning)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Text(
            'No heart-rate straps found yet.\n'
            'Make sure your strap is on and within range.',
            textAlign: TextAlign.center,
          ),
        )
      else
        ...entries.map((entry) {
          final isSelected = _selected?.id == entry.id;
          // While a device is selected, scanning is paused, so the other rows
          // are stale — dim them.
          final stale = _selected != null && !isSelected;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Opacity(
              opacity: stale ? 0.4 : 1.0,
              child: _PickerCard(
                title: entry.name,
                rssi: entry.rssi,
                isKnown: entry.isKnown,
                isFake: entry.isFake,
                isSelected: isSelected,
                connecting: isSelected && _connectingPreview,
                bpm: isSelected ? _previewBpm : null,
                onTap: (_starting || _startRequested)
                    ? null
                    : () => _select(entry),
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
    this.isFake = false,
    this.isSelected = false,
    this.connecting = false,
    this.bpm,
    required this.onTap,
  });

  final String title;
  final int? rssi;
  final bool isKnown;
  final bool isFake;
  final bool isSelected;
  final bool connecting;
  final int? bpm;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final IconData iconData;
    if (isFake) {
      iconData = Icons.bug_report_outlined;
    } else if (isKnown) {
      iconData = Icons.favorite;
    } else {
      iconData = Icons.favorite_border;
    }

    Widget subtitle;
    if (isSelected) {
      subtitle = Text(
        connecting || bpm == null ? 'Connecting…' : '$bpm BPM',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    } else if (isFake) {
      subtitle = Text(
        'Debug heart-rate stream',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    } else {
      subtitle = _SignalBars(rssi: rssi ?? -90);
    }

    // Recognition is shown by icon shape + "Last used", never by zone color.
    final Widget? trailing;
    if (isSelected) {
      trailing = Icon(Icons.check_circle, color: scheme.primary);
    } else if (isKnown) {
      trailing = Text(
        'Last used',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      );
    } else {
      trailing = null;
    }

    return Card(
      color: isSelected ? scheme.primaryContainer : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                iconData,
                color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    subtitle,
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                trailing,
              ],
            ],
          ),
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
          _SignalBar(height: 4.0 + i * 3.0, active: i < _bars, color: color),
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
