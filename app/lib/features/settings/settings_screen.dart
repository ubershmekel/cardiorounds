import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/build_info.dart';
import '../../core/db/database.dart';
import '../../core/db/providers.dart';
import '../../core/settings/app_settings.dart';
import '../../core/support_logs.dart';
import '../athletes/athlete_profile_fields.dart';

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

class _SettingsForm extends ConsumerWidget {
  const _SettingsForm({required this.athlete});

  final Athlete athlete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final maxHrUnset = athlete.maxHeartrate == null;
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
        // Auto-saves on blur; there is no Save button. Shared with the athlete
        // pager (Advanced → Manage athletes).
        AthleteProfileFields(athlete: athlete),
        const SizedBox(height: 32),
        const Divider(),
        _SettingsActionTile(
          icon: Icons.people_alt_outlined,
          title: 'Manage athletes',
          subtitle: 'Add people and edit their heart-rate zones.',
          // The only tile that opens a sub-screen, so it's the only one that
          // earns a navigation chevron.
          navigates: true,
          onTap: () => context.push('/settings/athletes'),
        ),
        const _SettingsSectionTitle('Backup'),
        _SettingsActionTile(
          icon: Icons.download_outlined,
          title: 'Export database',
          subtitle: 'Save a full backup of workouts, athletes, and settings.',
          onTap: () => shareSupportFile(
            context,
            getFile: AppDatabase.databaseFile,
            subject: 'Cardio Rounds database',
          ),
        ),
        _SettingsActionTile(
          icon: Icons.upload_outlined,
          title: 'Restore from database',
          subtitle: 'Replace this device\'s data with a saved backup file.',
          onTap: () => _restoreDatabase(context, ref),
        ),
        const _SettingsSectionTitle('Advanced'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.groups_outlined),
          title: const Text('Record from multiple devices'),
          subtitle: const Text(
            'Select several heart-rate straps for the same session.',
          ),
          value: ref.watch(multiDeviceRecordingEnabledProvider),
          onChanged: (enabled) => ref
              .read(multiDeviceRecordingEnabledProvider.notifier)
              .set(enabled),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.bug_report_outlined),
          title: const Text('Fake heart-rate device'),
          subtitle: const Text(
            'Use a simulated strap to test recording without hardware.',
          ),
          value: ref.watch(fakeHrDeviceEnabledProvider),
          onChanged: (enabled) =>
              ref.read(fakeHrDeviceEnabledProvider.notifier).set(enabled),
        ),
        _SettingsActionTile(
          icon: Icons.article_outlined,
          title: 'Export logs',
          subtitle: 'Share troubleshooting details after a recording problem.',
          onTap: () => exportSupportLogs(context),
        ),
        const _SettingsSectionTitle('About'),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.info_outline),
          title: const Text('App version'),
          subtitle: Text(appBuildLabel()),
        ),
        _SettingsActionTile(
          icon: Icons.open_in_new,
          title: 'Source on GitHub',
          subtitle: 'File feedback as an issue, or change the code.',
          onTap: () => _openSourceCode(context),
        ),
      ],
    );
  }

  Future<void> _restoreDatabase(BuildContext context, WidgetRef ref) async {
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

class _SettingsSectionTitle extends StatelessWidget {
  const _SettingsSectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      // Spacing lives here so section headers self-separate; call sites don't
      // sprinkle SizedBoxes around them.
      margin: const EdgeInsets.only(top: 24, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SettingsActionTile extends StatelessWidget {
  const _SettingsActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.navigates = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// Whether tapping opens another screen. Only navigation tiles show the
  /// trailing chevron; action tiles (export, restore, open a link) don't, so
  /// the chevron keeps meaning "go to a sub-page".
  final bool navigates;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: navigates ? const Icon(Icons.chevron_right) : null,
      onTap: onTap,
    );
  }
}
