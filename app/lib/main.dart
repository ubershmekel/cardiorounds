import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/app_logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _configureBluetoothBackgroundRestore();
  runApp(const ProviderScope(child: CardioRoundsApp()));
}

Future<void> _configureBluetoothBackgroundRestore() async {
  try {
    // Flutter Blue Plus requires restoreState before any scan/connect work.
    // Together with Info.plist bluetooth-central, this gives iOS a way to wake
    // the app for restored BLE events; Dart still only gets a short background
    // window, so the reconnect logs show whether recovery actually ran.
    appLog('BT', '_configureBluetoothBackgroundRestore');
    await FlutterBluePlus.setOptions(restoreState: true);
    appLog('BT', 'FlutterBluePlus restoreState enabled');
  } catch (e) {
    appLog('BT', 'FlutterBluePlus restoreState setup failed: $e');
  }
}
