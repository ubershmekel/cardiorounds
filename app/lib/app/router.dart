import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/activity/activity_screen.dart';
import '../features/home/home_screen.dart';
import '../features/recording/confirm_record_screen.dart';
import '../features/recording/recording_screen.dart';
import '../features/settings/settings_screen.dart';
import 'shell.dart';

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
        path: '/recording/:activityId',
        parentNavigatorKey: rootKey,
        builder: (_, state) {
          final activityId = int.parse(state.pathParameters['activityId']!);
          return RecordingScreen(activityId: activityId);
        },
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
