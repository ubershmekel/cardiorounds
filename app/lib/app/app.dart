import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_logger.dart';
import '../core/db/providers.dart';
import '../core/support_logs.dart';
import 'router.dart';
import 'theme.dart';

class CardioRoundsApp extends ConsumerStatefulWidget {
  const CardioRoundsApp({super.key});

  @override
  ConsumerState<CardioRoundsApp> createState() => _CardioRoundsAppState();
}

class _CardioRoundsAppState extends ConsumerState<CardioRoundsApp> {
  late final _router = ref.read(routerProvider);

  Widget _maybePortraitFrame(Widget? child) {
    final inner = child ?? const SizedBox.shrink();
    if (kIsWeb && Uri.base.path.contains('/try')) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: inner,
        ),
      );
    }
    return inner;
  }

  @override
  Widget build(BuildContext context) {
    final startup = ref.watch(startupProvider);
    return MaterialApp.router(
      title: 'Cardio Rounds',
      debugShowCheckedModeBanner: false,
      theme: buildDarkTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.dark,
      routerConfig: _router,
      builder: (context, child) {
        return startup.when(
          loading: () => const _SplashScaffold(),
          error: (error, stackTrace) => _StartupErrorScaffold(
            error: error,
            stackTrace: stackTrace,
            onRetry: () {
              ref.invalidate(databaseProvider);
              ref.invalidate(startupProvider);
            },
          ),
          data: (_) => _maybePortraitFrame(child),
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

class _StartupErrorScaffold extends StatefulWidget {
  const _StartupErrorScaffold({
    required this.error,
    required this.stackTrace,
    required this.onRetry,
  });

  final Object error;
  final StackTrace stackTrace;
  final VoidCallback onRetry;

  @override
  State<_StartupErrorScaffold> createState() => _StartupErrorScaffoldState();
}

class _StartupErrorScaffoldState extends State<_StartupErrorScaffold> {
  @override
  void initState() {
    super.initState();
    appLog('Startup', 'Failed to start: ${widget.error}\n${widget.stackTrace}');
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.error_outline, size: 48, color: scheme.error),
                  const SizedBox(height: 20),
                  Text(
                    "Couldn't start Cardio Rounds",
                    style: textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'The app hit a startup problem. Download the logs and send '
                    'them for support.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => exportSupportLogs(context),
                    icon: const Icon(Icons.article_outlined),
                    label: const Text('Download logs'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: widget.onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                  const SizedBox(height: 16),
                  _ErrorDetails(
                    error: widget.error,
                    stackTrace: widget.stackTrace,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Collapsed-by-default technical error text. Hidden behind a disclosure so the
/// screen stays calm for users, but the real error is one tap away (and
/// selectable) without exporting the whole log.
class _ErrorDetails extends StatelessWidget {
  const _ErrorDetails({required this.error, required this.stackTrace});

  final Object error;
  final StackTrace stackTrace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Theme(
      // ExpansionTile draws its own dividers; drop them for a cleaner look.
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 8),
        title: Text('Details', style: theme.textTheme.labelLarge),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            constraints: const BoxConstraints(maxHeight: 240),
            child: SingleChildScrollView(
              child: SelectableText(
                '$error\n\n$stackTrace',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
