import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/activity/activity_screen.dart';
import '../features/home/home_screen.dart';
import '../features/recording/confirm_record_screen.dart';
import '../features/recording/recording_screen.dart';
import '../features/settings/settings_screen.dart';
import 'shell.dart';

// Route structure notes:
// - StatefulShellRoute owns /home, /record, and /settings. Its IndexedStack
//   keeps all three branch widget trees alive when switching tabs.
// - The recording screen lives at /record/recording/:id (nested under /record)
//   so go_router assigns it to the Record branch. This is what keeps the
//   RecordingController alive while the user browses other tabs — if recording
//   were a root-level route it would replace the shell entirely.
// - /activity/:id is a root-level route so it overlays the full screen. It is
//   pushed (not go'd) from the home list so the shell stays alive underneath.
GoRouter buildRouter() {
  final rootKey = GlobalKey<NavigatorState>();

  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/record',
                builder: (_, _) => const ConfirmRecordScreen(),
                routes: [
                  GoRoute(
                    path: 'recording/:activityId',
                    builder: (_, state) {
                      final activityId = int.parse(
                        state.pathParameters['activityId']!,
                      );
                      return RecordingScreen(activityId: activityId);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (_, _) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/activity/:activityId',
        parentNavigatorKey: rootKey,
        builder: (_, state) {
          final activityId = int.parse(state.pathParameters['activityId']!);
          return ActivityScreen(activityId: activityId);
        },
      ),
    ],
  );
}
