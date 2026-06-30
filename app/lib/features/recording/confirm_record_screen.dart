import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_logger.dart';
import '../../core/db/database.dart';
import '../../core/db/providers.dart';
import '../../core/hr/fake_hr_source.dart';
import '../../core/hr/hr_providers.dart';
import '../../core/hr/hr_scanner.dart';
import '../../core/hr/hr_source.dart';
import '../../core/settings/app_settings.dart';
import 'sport_type_field.dart';

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
    this.fakeCenterBpm = 132,
  });

  final String id;
  final String name;
  final int? rssi;
  final bool isKnown;
  final bool isFake;
  // Distinct resting center per simulated strap so multiple fake lines differ.
  final int fakeCenterBpm;
}

/// A selected device's live preview connection (handed straight to recording on
/// Start). In single-device mode at most one of these exists; in multi-device
/// mode there is one per selected device.
class _Selection {
  _Selection(this.entry);

  final _Entry entry;
  Future<HeartRateSource>? sourceFuture;
  HeartRateSource? source;
  int? bpm;
  StreamSubscription<HrSample>? sampleSub;
  bool connecting = true;
  String? error;
  bool transferred = false;
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

  // Selected devices, keyed by entry id, each holding a live preview connection.
  // Single-device mode keeps at most one; multi-device mode keeps several.
  final Map<String, _Selection> _selections = {};
  // Start tapped while the (single) preview is still connecting; honored once
  // ready. Multi-device mode transfers any still-connecting selected devices to
  // the recording screen.
  bool _startRequested = false;
  // Committing the selected sources to a new recording (full-screen spinner).
  bool _starting = false;
  String? _error;

  bool get _showFakeStrap => ref.watch(fakeHrDeviceEnabledProvider);
  bool get _multiEnabled => ref.read(multiDeviceRecordingEnabledProvider);

  bool get _busy => _startRequested || _starting;
  bool get _hasSelection => _selections.isNotEmpty;
  bool get _canStartMulti =>
      _hasSelection &&
      _selections.values.every(
        (s) => s.source != null || (s.connecting && s.sourceFuture != null),
      );

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _scanner = ref.read(hrScannerFactoryProvider)();
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
    if (!useNativeBluetooth) {
      _scanTimer = Timer.periodic(_scanInterval, (_) => _startScan());
    }
  }

  Future<void> _startScan() async {
    // Multi-device mode keeps scanning while devices are selected (you need to
    // keep finding more); single-device mode pauses once a device is picked.
    if (_scanning || _busy) return;
    if (!_multiEnabled && _hasSelection) return;
    setState(() => _scanning = true);
    try {
      await _scanner?.start(timeout: _scanTimeout);
    } catch (e) {
      appLog('Scan', 'Scan failed: $e');
    } finally {
      if (mounted) setState(() => _scanning = false);
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
    if (_autoSelectConsumed || _hasSelection || _onlyKnownDevice == null) {
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

  Future<void> _disposeSelection(_Selection selection) async {
    await selection.sampleSub?.cancel();
    selection.sampleSub = null;
    final source = selection.source;
    selection.source = null;
    await source?.dispose();
  }

  Future<void> _disposeAllSelections() async {
    final all = _selections.values.toList();
    _selections.clear();
    for (final selection in all) {
      await _disposeSelection(selection);
    }
  }

  Future<void> _select(_Entry entry) async {
    if (_starting) return;
    // Selecting a device should also dismiss the sport-type keyboard/overlay.
    FocusScope.of(context).unfocus();
    // Any interaction consumes the one-shot auto-selection.
    _autoSelectConsumed = true;

    // Tapping a selected row deselects just that device.
    if (_selections.containsKey(entry.id)) {
      await _deselect(entry.id);
      return;
    }

    final multi = _multiEnabled;
    if (!multi) {
      // Single-device: replace any current selection and pause scanning.
      await _disposeAllSelections();
      await _scanner?.stop();
    }

    final selection = _Selection(entry);
    setState(() {
      _selections[entry.id] = selection;
      _error = null;
    });

    try {
      final sourceFuture = entry.isFake
          ? Future<HeartRateSource>.value(
              FakeHeartRateSource(
                deviceName: entry.name,
                centerBpm: entry.fakeCenterBpm,
              ),
            )
          : ref.read(hrConnectorProvider)(entry.id, entry.name);
      selection.sourceFuture = sourceFuture;
      if (mounted && _selections.containsKey(entry.id)) {
        setState(() {});
      }
      final source = await sourceFuture;
      // The selection may have been removed (or the screen closed) while
      // connecting.
      if (!mounted || !_selections.containsKey(entry.id)) {
        if (!selection.transferred) await source.dispose();
        return;
      }
      setState(() {
        selection.source = source;
        selection.connecting = false;
      });
      selection.sampleSub = source.samples.listen((sample) {
        if (!mounted) return;
        setState(() => selection.bpm = sample.bpm);
      });
      // Honor a single-device Start tapped before the connection was ready.
      if (_startRequested && !multi) {
        _startRequested = false;
        await _commitStart();
      }
    } catch (e) {
      if (!mounted || !_selections.containsKey(entry.id)) return;
      if (multi) {
        // Keep the row but show its error; the other devices are unaffected.
        setState(() {
          selection.connecting = false;
          selection.error = 'Could not connect';
        });
      } else {
        setState(() {
          _selections.remove(entry.id);
          _error = 'Could not connect: $e';
          _startRequested = false;
        });
        await _startScan();
      }
    }
  }

  Future<void> _deselect(String id) async {
    final selection = _selections.remove(id);
    if (selection != null) await _disposeSelection(selection);
    if (!mounted) return;
    setState(() {});
    // Single-device mode pauses scanning while selected; resume when cleared.
    if (!_multiEnabled && _selections.isEmpty) _startScan();
  }

  void _onStart() {
    if (_starting || _startRequested || !_hasSelection) return;
    if (_multiEnabled) {
      // Multi-device means every selected device is part of the recording. Any
      // still-connecting selections move forward and connect on the live screen.
      if (_canStartMulti) _commitStart();
      return;
    }
    // Single-device: don't make the user wait for pairing — remember the intent
    // and fire as soon as the preview connection is ready.
    final selection = _selections.values.first;
    if (selection.connecting || selection.source == null) {
      setState(() => _startRequested = true);
      return;
    }
    _commitStart();
  }

  Future<void> _commitStart() async {
    final selected = _multiEnabled
        ? _selections.values.toList()
        : _selections.values.where((s) => s.source != null).toList();
    if (selected.isEmpty) return;
    if (selected.any((s) => s.source == null && s.sourceFuture == null)) {
      return;
    }
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      // Do all the fallible prep while we still own the sources, so a failure
      // here leaves the live preview connections intact and Start retryable.
      await _scanner?.stop();
      final db = ref.read(databaseProvider);
      // One device id per selected source, in order, so the returned set ids
      // line up. Fake source -> null device.
      final deviceIds = <int?>[];
      for (final s in selected) {
        if (s.entry.isFake) {
          deviceIds.add(null);
        } else {
          final device = await db.upsertDevice(
            platformId: s.entry.id,
            name: s.source?.deviceName ?? s.entry.name,
          );
          deviceIds.add(device.id);
        }
      }
      final athlete = await db.ensureDefaultAthlete();
      final now = DateTime.now().millisecondsSinceEpoch;
      final sport = _sportTypeController.text.trim();
      final started = await db.startActivityWithDevices(
        athleteId: athlete.id,
        startedAtMs: now,
        sportType: sport.isEmpty ? null : sport,
        deviceIds: deviceIds,
      );
      // Handoff: from here the recording controller owns the connections — no
      // disconnect, no reconnect. Stop our preview listeners before relinquishing.
      final sources = <RecordingSource>[];
      for (var i = 0; i < selected.length; i++) {
        final selection = selected[i];
        await selection.sampleSub?.cancel();
        selection.sampleSub = null;
        final source = selection.source;
        sources.add(
          source == null
              ? RecordingSource.pending(
                  sourceFuture: selection.sourceFuture!,
                  setId: started.hrSetIds[i],
                  deviceName: selection.entry.name,
                  devicePlatformId: selection.entry.isFake
                      ? null
                      : selection.entry.id,
                )
              : RecordingSource(source: source, setId: started.hrSetIds[i]),
        );
      }
      // If the screen is gone, keep ownership (dispose() will tear it down).
      if (!mounted) return;
      // Ownership transferred — clear so dispose() doesn't tear these down.
      for (final selection in selected) {
        selection.transferred = true;
      }
      _selections.clear();
      ref.read(pendingRecordingProvider.notifier).state = sources;
      ref.read(activeRecordingIdProvider.notifier).state = started.activityId;
      context.go('/record/recording/${started.activityId}');
    } catch (e) {
      if (!mounted) return;
      // The sources are still held and connected; the user can press Start
      // again without reconnecting.
      setState(() {
        _error = 'Could not start: $e';
        _starting = false;
      });
    }
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _scanResultsSub?.cancel();
    for (final selection in _selections.values) {
      selection.sampleSub?.cancel();
      selection.source?.dispose(); // fire-and-forget; dispose() can't await
    }
    _sportTypeController.dispose();
    _sportTypeFocus.dispose();
    _scanner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch so toggling the setting (or selection changes) rebuilds the picker.
    ref.watch(multiDeviceRecordingEnabledProvider);
    final startEnabled =
        _hasSelection &&
        !_starting &&
        !_startRequested &&
        (!_multiEnabled || _canStartMulti);
    return Scaffold(
      appBar: AppBar(title: const Text('Start recording')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        // Dragging the list also dismisses the keyboard/overlay.
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          // Start sits above the sport-type field so the autocomplete overlay
          // (which drops down) can never cover it.
          FilledButton.icon(
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start'),
            onPressed: startEnabled ? _onStart : null,
          ),
          const SizedBox(height: 16),
          _buildSportTypeField(),
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
    );
  }

  Widget _buildSportTypeField() {
    return SportTypeField(
      controller: _sportTypeController,
      focusNode: _sportTypeFocus,
      prefillWithMostRecent: true,
      decoration: const InputDecoration(
        labelText: 'Sport type (optional)',
        hintText: 'e.g. BJJ, Treadmill, Bike',
        border: OutlineInputBorder(),
      ),
    );
  }

  /// Simulated straps offered when the fake-device toggle is on. Multi-device
  /// mode offers several (with distinct heart rates) so the flow can be tested
  /// without hardware; single-device mode keeps the lone strap.
  List<_Entry> _fakeEntries() {
    if (!_showFakeStrap) return const [];
    if (!_multiEnabled) {
      return const [
        _Entry(id: _fakeId, name: 'Simulated Bluetooth strap', isFake: true),
      ];
    }
    return const [
      _Entry(
        id: '__fake_1__',
        name: 'Simulated strap 1',
        isFake: true,
        fakeCenterBpm: 128,
      ),
      _Entry(
        id: '__fake_2__',
        name: 'Simulated strap 2',
        isFake: true,
        fakeCenterBpm: 148,
      ),
      _Entry(
        id: '__fake_3__',
        name: 'Simulated strap 3',
        isFake: true,
        fakeCenterBpm: 112,
      ),
    ];
  }

  List<_Entry> _displayedEntries() {
    return [
      ..._fakeEntries(),
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

  /// Returns an explicit message when the Bluetooth adapter can't be scanned
  /// (off, no permission, unsupported), or null when scanning is possible so
  /// the normal device list / "looking for straps" flow takes over. Web has no
  /// adapter, so it always falls through to null.
  Widget? _buildBluetoothNotice(BuildContext context) {
    if (kIsWeb) return null;
    final state = ref.watch(bluetoothAdapterStateProvider).valueOrNull;
    final String message;
    switch (state) {
      case BluetoothAdapterState.off:
      case BluetoothAdapterState.turningOff:
        message =
            'Bluetooth is off. Turn on Bluetooth to find your heart-rate strap.';
      case BluetoothAdapterState.unauthorized:
        message =
            'Cardio Rounds doesn\'t have permission to use Bluetooth. '
            'Enable Bluetooth access for the app in your device settings.';
      case BluetoothAdapterState.unavailable:
        message = 'This device doesn\'t support Bluetooth.';
      // on / turningOn / unknown / loading: let the normal flow proceed.
      default:
        return null;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.bluetooth_disabled,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDevicePicker(BuildContext context) {
    final entries = _displayedEntries();
    final multi = _multiEnabled;

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
              // Multi-device keeps scanning while selected, so refresh stays
              // available; single-device disables it while a device is picked.
              onPressed: (_busy || (!multi && _hasSelection))
                  ? null
                  : _startScan,
            ),
        ],
      ),
      const SizedBox(height: 8),
      if (_buildBluetoothNotice(context) case final notice?)
        notice
      else if (entries.isEmpty && !_scanning)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Text(
            'No heart-rate straps found yet.\n'
            'Make sure Bluetooth is on and your strap is on and within range.',
            textAlign: TextAlign.center,
          ),
        )
      else
        ...entries.map((entry) {
          final selection = _selections[entry.id];
          final isSelected = selection != null;
          // In single-device mode scanning pauses while selected, so the other
          // rows are stale — dim them. Multi-device keeps scanning, so no dimming.
          final stale = !multi && _hasSelection && !isSelected;
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
                connecting: selection?.connecting ?? false,
                bpm: selection?.bpm,
                error: selection?.error,
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
    this.error,
    required this.onTap,
  });

  final String title;
  final int? rssi;
  final bool isKnown;
  final bool isFake;
  final bool isSelected;
  final bool connecting;
  final int? bpm;
  final String? error;
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
    if (isSelected && error != null) {
      subtitle = Text(
        error!,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: scheme.error),
      );
    } else if (isSelected) {
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
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
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
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    subtitle,
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing],
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
