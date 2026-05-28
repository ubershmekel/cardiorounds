import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/db/providers.dart';

const String kAppVersion = '0.1.0';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final athlete = ref.watch(defaultAthleteProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: athlete.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load profile: $e')),
        data: (a) => _SettingsForm(athlete: a),
      ),
    );
  }
}

class _SettingsForm extends ConsumerStatefulWidget {
  const _SettingsForm({required this.athlete});

  final Athlete athlete;

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  late final TextEditingController _nameController;
  late final TextEditingController _maxHrController;
  late final TextEditingController _restingHrController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.athlete.name);
    _maxHrController = TextEditingController(
      text: widget.athlete.maxHeartrate?.toString() ?? '',
    );
    _restingHrController = TextEditingController(
      text: widget.athlete.restingHeartrate?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _maxHrController.dispose();
    _restingHrController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    final maxText = _maxHrController.text.trim();
    final restingText = _restingHrController.text.trim();
    await db.updateAthlete(
      id: widget.athlete.id,
      name: _nameController.text.trim().isEmpty
          ? 'Athlete'
          : _nameController.text.trim(),
      maxHeartrate: maxText.isEmpty ? null : int.tryParse(maxText),
      clearMax: maxText.isEmpty,
      restingHeartrate: restingText.isEmpty ? null : int.tryParse(restingText),
      clearResting: restingText.isEmpty,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Saved')));
  }

  @override
  Widget build(BuildContext context) {
    final maxHrUnset = widget.athlete.maxHeartrate == null;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (maxHrUnset)
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Set your max heart rate to unlock zone colors on the chart.',
              ),
            ),
          ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Name',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _maxHrController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Max heart rate (bpm)',
            helperText: 'Leave empty if unknown',
            border: OutlineInputBorder(),
            suffixIcon: Tooltip(
              message:
                  'Used for zone thresholds. Estimate: 220 minus your age; measure with a hard interval session for accuracy.',
              child: Icon(Icons.help_outline),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _restingHrController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Resting heart rate (bpm)',
            helperText: 'Leave empty if unknown',
            border: OutlineInputBorder(),
            suffixIcon: Tooltip(
              message:
                  'Measure first thing in the morning, lying still, with a strap or fingertip.',
              child: Icon(Icons.help_outline),
            ),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
        const SizedBox(height: 32),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('App version'),
          subtitle: Text(kAppVersion),
        ),
      ],
    );
  }
}
