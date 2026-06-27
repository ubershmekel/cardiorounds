import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_logger.dart';
import '../../core/db/providers.dart';
import '../../core/hr/hr_providers.dart';
import '../../core/hr/hr_source.dart';
import '../../core/recording/interrupted_recording.dart';

/// Wraps the app shell and, once per launch, offers to recover a recording that
/// was interrupted (app crashed or killed mid-recording). On resume it
/// reconnects to the strap and continues the original activity; on finish it
/// saves what was already recorded as a completed workout (non-destructive).
class RecoveryPrompt extends ConsumerStatefulWidget {
  const RecoveryPrompt({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<RecoveryPrompt> createState() => _RecoveryPromptState();
}

enum _RecoveryChoice { resume, finish }

class _RecoveryPromptState extends ConsumerState<RecoveryPrompt> {
  // Guards against re-prompting on rebuilds; reset only if the prompt is
  // dismissed without a choice or a reconnect fails, so it can be retried.
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePrompt());
  }

  Future<void> _maybePrompt() async {
    if (_handled || !mounted) return;
    // A live recording already owns this session (e.g. iOS kept it alive across
    // a suspension); don't interrupt it.
    if (ref.read(activeRecordingIdProvider) != null) return;
    final recording = await ref.read(interruptedRecordingProvider.future);
    if (recording == null || !mounted) return;
    if (ref.read(activeRecordingIdProvider) != null) return;
    _handled = true;

    final choice = await showDialog<_RecoveryChoice>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Resume recording?'),
        content: Text(_describe(recording)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, _RecoveryChoice.finish),
            child: const Text('Save as finished'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, _RecoveryChoice.resume),
            child: const Text('Resume'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case _RecoveryChoice.resume:
        await _resume(recording);
      case _RecoveryChoice.finish:
        await _finish(recording);
      case null:
        _handled = false;
    }
  }

  String _describe(InterruptedRecording recording) {
    final started = DateTime.fromMillisecondsSinceEpoch(recording.startedAtMs);
    final ago = DateTime.now().difference(started);
    return 'A recording on ${recording.deviceName} was interrupted '
        '${_formatAgo(ago)}. Resume it, or save what was already recorded as a '
        'finished workout?';
  }

  String _formatAgo(Duration d) {
    if (d.inMinutes < 1) return 'moments ago';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) {
      final h = d.inHours;
      return '$h ${h == 1 ? 'hour' : 'hours'} ago';
    }
    final days = d.inDays;
    return '$days ${days == 1 ? 'day' : 'days'} ago';
  }

  /// Reconnects to the strap and hands the live source to a resumed recording.
  /// On failure the sentinel is left in place so the user can retry next launch.
  Future<void> _resume(InterruptedRecording recording) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ConnectingDialog(),
    );

    HeartRateSource? source;
    try {
      source = await ref.read(hrConnectorProvider)(
        recording.devicePlatformId,
        recording.deviceName,
      );
    } catch (e) {
      appLog('Recovery', 'Resume reconnect failed: $e');
    }

    if (!mounted) {
      await source?.dispose();
      return;
    }
    Navigator.of(context, rootNavigator: true).pop(); // dismiss connecting

    if (source == null) {
      _handled = false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn\'t reconnect to ${recording.deviceName}')),
      );
      return;
    }

    ref.read(pendingHrSourceProvider.notifier).state = source;
    ref.read(resumeStartedAtProvider.notifier).state =
        DateTime.fromMillisecondsSinceEpoch(recording.startedAtMs);
    ref.read(activeRecordingIdProvider.notifier).state = recording.activityId;
    if (!mounted) return;
    context.go('/record/recording/${recording.activityId}');
  }

  /// Closes out the interrupted activity as a finished workout: duration from
  /// the last sample, shape recomputed, sentinel cleared. Keeps the data.
  Future<void> _finish(InterruptedRecording recording) async {
    final db = ref.read(databaseProvider);
    try {
      final lastTMs = await db.lastSampleTMs(recording.activityId) ?? 0;
      await db.finalizeActivity(
        activityId: recording.activityId,
        durationMs: lastTMs,
      );
      await db.computeAndSaveShape(recording.activityId);
    } catch (e) {
      // Don't clear the sentinel: the activity is still unfinalized
      // (durationMs == 0), so leaving the file lets the user retry next launch.
      appLog('Recovery', 'Finishing interrupted activity failed: $e');
      _handled = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn\'t save the interrupted recording')),
        );
      }
      return;
    }
    await ref.read(recordingSentinelProvider).clear();
    if (mounted) ref.invalidate(interruptedRecordingProvider);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _ConnectingDialog extends StatelessWidget {
  const _ConnectingDialog();

  @override
  Widget build(BuildContext context) {
    return const AlertDialog(
      content: Row(
        children: [
          SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 20),
          Text('Reconnecting…'),
        ],
      ),
    );
  }
}
