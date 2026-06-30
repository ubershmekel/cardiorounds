import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/build_info.dart';
import '../../core/db/database.dart';
import '../../core/db/providers.dart';
import '../../core/settings/app_settings.dart';
import '../../core/support_logs.dart';

final Uri _sourceCodeUrl = Uri.parse(
  'https://github.com/ubershmekel/cardiorounds',
);

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
      name: _nameController.text.trim(),
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

  bool get _isHRSwapped {
    final max = int.tryParse(_maxHrController.text.trim());
    final resting = int.tryParse(_restingHrController.text.trim());
    return max != null && resting != null && max <= resting;
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
            hintText: 'Your name (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _restingHrController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Resting heart rate (bpm)',
            helperText: 'Leave empty if unknown',
            border: OutlineInputBorder(),
            suffixIcon: Tooltip(
              message: 'Measure first thing in the morning, lying still.',
              child: Icon(Icons.help_outline),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _maxHrController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'MAX heart rate (bpm)',
            helperText: 'Leave empty if unknown',
            border: OutlineInputBorder(),
            suffixIcon: Tooltip(
              message:
                  'Used for zone thresholds. Estimate: 220 minus your age; or measure with an increasingly hard interval session for accuracy.',
              child: Icon(Icons.help_outline),
            ),
          ),
        ),
        if (_isHRSwapped) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 18,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Max HR must be greater than resting HR - are they swapped?',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _saving || _isHRSwapped ? null : _save,
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
          subtitle: Text(appBuildLabel()),
        ),
        ...[
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 8),
          Text(
            'Advanced',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.open_in_new),
            label: const Text('Source on GitHub'),
            onPressed: () => _openSourceCode(context),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.download_outlined),
            label: const Text('Export database'),
            onPressed: () => shareSupportFile(
              context,
              getFile: AppDatabase.databaseFile,
              subject: 'Cardio Rounds database',
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.upload_outlined),
            label: const Text('Restore from database'),
            onPressed: () => _restoreDatabase(context),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.article_outlined),
            label: const Text('Export logs'),
            onPressed: () => exportSupportLogs(context),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.bug_report_outlined),
            title: const Text('Fake heart-rate device'),
            subtitle: const Text(
              'Offer a simulated strap when starting a recording for testing the app.',
            ),
            value: ref.watch(fakeHrDeviceEnabledProvider),
            onChanged: (enabled) =>
                ref.read(fakeHrDeviceEnabledProvider.notifier).set(enabled),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.groups_outlined),
            title: const Text('Record from multiple devices'),
            subtitle: const Text(
              'Track more than one heart-rate strap in a single session.',
            ),
            value: ref.watch(multiDeviceRecordingEnabledProvider),
            onChanged: (enabled) => ref
                .read(multiDeviceRecordingEnabledProvider.notifier)
                .set(enabled),
          ),
        ],
      ],
    );
  }

  Future<void> _restoreDatabase(BuildContext context) async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Restore not available on web')),
      );
      return;
    }

    final result = await FilePicker.pickFiles(withData: false);
    final path = result?.files.single.path;
    if (path == null) return; // cancelled

    final source = File(path);
    final bytes = await source.readAsBytes();
    // A SQLite file starts with the 16-byte magic header "SQLite format 3\0".
    // Reject anything else so we don't overwrite the live DB with garbage.
    const header = 'SQLite format 3\x00';
    final looksLikeSqlite =
        bytes.length >= header.length &&
        String.fromCharCodes(bytes.take(header.length)) == header;
    if (!looksLikeSqlite) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not a valid SQLite database file')),
      );
      return;
    }

    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore from database?'),
        content: const Text(
          'This will permanently delete all your current data and replace it '
          'with the contents of the selected file. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete and restore'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final target = await AppDatabase.databaseFile();
    // Close the live connection before overwriting the file on disk, then
    // remove drift's WAL sidecar files so they can't corrupt the new DB.
    await ref.read(databaseProvider).close();
    await target.writeAsBytes(bytes, flush: true);
    for (final suffix in const ['-wal', '-shm']) {
      final sidecar = File('${target.path}$suffix');
      if (await sidecar.exists()) await sidecar.delete();
    }
    // Rebuild the database singleton; every data provider watches it, so the
    // UI reloads from the restored file.
    ref.invalidate(databaseProvider);

    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Database restored')));
  }

  Future<void> _openSourceCode(BuildContext context) async {
    if (await launchUrl(_sourceCodeUrl, mode: LaunchMode.externalApplication)) {
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open GitHub source')),
    );
  }
}
