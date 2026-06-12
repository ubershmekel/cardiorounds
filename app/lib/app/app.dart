import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/db/providers.dart';
import 'router.dart';
import 'theme.dart';

class CardioRoundsApp extends ConsumerStatefulWidget {
  const CardioRoundsApp({super.key});

  @override
  ConsumerState<CardioRoundsApp> createState() => _CardioRoundsAppState();
}

class _CardioRoundsAppState extends ConsumerState<CardioRoundsApp> {
  late final _router = buildRouter();

  @override
  Widget build(BuildContext context) {
    final startup = ref.watch(startupProvider);
    return MaterialApp.router(
      title: 'Cardio Rounds',
      theme: buildDarkTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.dark,
      routerConfig: _router,
      builder: (context, child) {
        return startup.when(
          loading: () => const _SplashScaffold(),
          error: (e, _) => _ErrorScaffold(error: e),
          data: (_) => child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

class _SplashScaffold extends StatelessWidget {
  const _SplashScaffold();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _ErrorScaffold extends StatelessWidget {
  const _ErrorScaffold({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Failed to start: $error',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
