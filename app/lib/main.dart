import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/app_logger.dart';
import 'core/settings/app_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _configureBluetoothBackgroundRestore();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const CardioRoundsApp(),
    ),
  );
}

Future<void> _configureBluetoothBackgroundRestore() async {
  try {
    // Recording-time BLE restoration is handled by the native CoreBluetooth
    // central. FlutterBluePlus is still used for foreground scan/preview, so
    // keep its power alert without asking it to own background restoration too.
    await FlutterBluePlus.setOptions(showPowerAlert: true, restoreState: false);
    appLog('BT', 'FlutterBluePlus foreground options configured');
  } catch (e) {
    appLog('BT', 'FlutterBluePlus option setup failed: $e');
  }
}
