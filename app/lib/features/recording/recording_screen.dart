import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'recording_controller.dart';

class RecordingScreen extends ConsumerWidget {
  const RecordingScreen({super.key, required this.activityId});

  final int activityId;

  String _formatElapsed(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  Future<void> _onStop(BuildContext context, WidgetRef ref) async {
    await ref.read(recordingControllerProvider(activityId).notifier).stop();
    if (!context.mounted) return;
    context.go('/home');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recordingControllerProvider(activityId));
    final scheme = Theme.of(context).colorScheme;
    final bpmText = state.currentBpm?.toString() ?? '--';

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: Text(state.deviceName),
          automaticallyImplyLeading: false,
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Center(
                child: Text(
                  bpmText,
                  style: TextStyle(
                    fontSize: 128,
                    fontWeight: FontWeight.w600,
                    color: scheme.error,
                    height: 1.0,
                  ),
                ),
              ),
              Center(
                child: Text('bpm',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              const SizedBox(height: 32),
              Center(
                child: Text(
                  _formatElapsed(state.elapsed),
                  style: Theme.of(context).textTheme.displaySmall,
                ),
              ),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: state.stopped ? null : () => _onStop(context, ref),
                icon: const Icon(Icons.stop_circle_outlined),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    state.stopped ? 'Stopping…' : 'Stop',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
