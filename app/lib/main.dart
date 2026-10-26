import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/app_logger.dart';
import 'core/build_info.dart';
import 'core/settings/app_settings.dart';
import 'core/startup_diagnostics.dart';
import 'core/startup_sequence.dart';

Future<void> main() async {
  startStartupClock();
  WidgetsFlutterBinding.ensureInitialized();
  installStartupErrorLogging();
  // The lifecycle state tells a user launch (resumed/inactive) apart from iOS
  // waking the app in the background, where no frame is expected.
  appLog(
    'App',
    'Launched ${appBuildLabel()} '
        '(lifecycle: ${WidgetsBinding.instance.lifecycleState})',
  );
  watchFirstFrame();
  await _configureBluetoothBackgroundRestore();
  await _startup.start();
}

/// Everything from here must end in a `runApp`: if it doesn't, iOS keeps the
/// native splash up forever.
final _startup = StartupSequence<SharedPreferences>(
  load: () => startupStep(
    'SharedPreferences',
    () => loadStartupPreferences(timeout: kStartupPlatformCallTimeout),
  ),
  showApp: (prefs) {
    startupCheckpoint('runApp');
    runApp(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const CardioRoundsApp(),
      ),
    );
  },
  showFailure: (error, stackTrace, retry) {
    startupCheckpoint('runApp (startup failure screen)');
    runApp(
      StartupFailureApp(error: error, stackTrace: stackTrace, onRetry: retry),
    );
  },
);

Future<void> _configureBluetoothBackgroundRestore() async {
  try {
    // Recording-time BLE restoration is handled by the native CoreBluetooth
    // central. FlutterBluePlus is still used for foreground scan/preview, so
    // keep its power alert without asking it to own background restoration too.
    await startupStep(
      'FlutterBluePlus.setOptions',
      () =>
          FlutterBluePlus.setOptions(showPowerAlert: true, restoreState: false),
      timeout: kStartupPlatformCallTimeout,
    );
    appLog('BT', 'FlutterBluePlus foreground options configured');
  } catch (e) {
    // Optional: the app works without the power alert, so never block on it.
    appLog('BT', 'FlutterBluePlus option setup failed: $e');
  }
}
