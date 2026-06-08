import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  final _sportTypeController = TextEditingController();
  BluetoothHrScanner? _scanner;
  List<ScanResult> _results = const [];
  bool _scanning = false;
  bool _connecting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) _startScan();
  }

  Future<void> _startScan() async {
    if (_scanning) return;
    setState(() {
      _scanning = true;
      _error = null;
    });
    final scanner = BluetoothHrScanner();
    _scanner = scanner;
    scanner.results.listen((r) {
      if (!mounted) return;
      setState(() => _results = r);
    });
    try {
      await scanner.start();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Scan failed: $e');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  @override
  void dispose() {
    _sportTypeController.dispose();
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
    if (!mounted) return;
    context.go('/recording/$activityId');
  }

  Future<void> _onSyntheticTap() async {
    if (_connecting) return;
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
    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      await _scanner?.stop();
      final source = await BluetoothHeartRateSource.connect(result.device);
      await ref.read(databaseProvider).upsertDevice(
            platformId: result.device.remoteId.str,
            name: source.deviceName,
          );
      await _startWith(source);
    } catch (e) {
      if (!mounted) return;
      await _scanner?.start();
      setState(() {
        _error = 'Could not connect: $e';
        _connecting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Start recording')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _sportTypeController,
            decoration: const InputDecoration(
              labelText: 'Sport type (optional)',
              hintText: 'e.g. BJJ, Treadmill, Bike',
              border: OutlineInputBorder(),
            ),
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
          if (kIsWeb)
            _PickerCard(
              title: 'Synthetic strap (debug)',
              subtitle:
                  'Generates a fake heart-rate stream for UI testing on web.',
              icon: Icons.bug_report_outlined,
              onTap: _connecting ? null : _onSyntheticTap,
            )
          else
            ..._buildMobilePicker(context),
          if (_connecting)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildMobilePicker(BuildContext context) {
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
            onTap: _connecting ? null : () => _onDeviceTap(r),
          ),
        ),
    ];
  }
}

class _PickerCard extends StatelessWidget {
  const _PickerCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
