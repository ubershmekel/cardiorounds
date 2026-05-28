import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/providers.dart';

class ConfirmRecordScreen extends ConsumerStatefulWidget {
  const ConfirmRecordScreen({super.key});

  @override
  ConsumerState<ConfirmRecordScreen> createState() =>
      _ConfirmRecordScreenState();
}

class _ConfirmRecordScreenState extends ConsumerState<ConfirmRecordScreen> {
  final _sportTypeController = TextEditingController();
  bool _starting = false;

  @override
  void dispose() {
    _sportTypeController.dispose();
    super.dispose();
  }

  Future<void> _startFakeRecording() async {
    if (_starting) return;
    setState(() => _starting = true);
    final db = ref.read(databaseProvider);
    final athlete = await db.ensureDefaultAthlete();
    final now = DateTime.now().millisecondsSinceEpoch;
    final sport = _sportTypeController.text.trim();
    final activityId = await db.startActivity(
      athleteId: athlete.id,
      startedAtMs: now,
      sportType: sport.isEmpty ? null : sport,
    );
    if (!mounted) return;
    context.go('/recording/$activityId');
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
          if (kIsWeb)
            _DevicePicker(
              title: 'Synthetic strap (debug)',
              subtitle:
                  'Generates a fake heart-rate stream for UI testing on web.',
              icon: Icons.bug_report_outlined,
              onTap: _starting ? null : _startFakeRecording,
            )
          else
            Card(
              child: ListTile(
                leading: const Icon(Icons.bluetooth_searching),
                title: const Text('Bluetooth device picker'),
                subtitle: const Text(
                  'Real BT pairing arrives in the next slice. '
                  'For now run on web to use the synthetic strap.',
                ),
              ),
            ),
          if (_starting)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _DevicePicker extends StatelessWidget {
  const _DevicePicker({
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
