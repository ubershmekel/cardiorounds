import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/db/providers.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(int index, int? activeRecordingId) {
    // When recording is active and user taps the Record tab, always restore the
    // recording screen rather than going to the branch's initial location.
    final initialLocation = activeRecordingId != null && index == 1
        ? false
        : index == navigationShell.currentIndex;
    navigationShell.goBranch(index, initialLocation: initialLocation);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeRecordingId = ref.watch(activeRecordingIdProvider);
    final isRecording = activeRecordingId != null;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => _onTap(index, activeRecordingId),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: isRecording,
              child: const Icon(Icons.fiber_manual_record_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: isRecording,
              child: const Icon(Icons.fiber_manual_record),
            ),
            label: 'Record',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
