import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bluetooth_hr_scanner.dart';
import 'bluetooth_hr_source.dart';
import 'hr_scanner.dart';
import 'hr_source.dart';
import 'native_bluetooth_hr_source.dart';
import 'native_hr_scanner.dart';

/// True when the native CoreBluetooth central (iOS) handles scanning and
/// connecting, so a preview connection can be handed to recording without a
/// reconnect. Android (and anything else) stays on FlutterBluePlus.
bool get useNativeBluetooth => !kIsWeb && Platform.isIOS;

/// Builds the platform heart-rate scanner. Overridden in tests with a fake.
final hrScannerFactoryProvider = Provider<HrScanner Function()>((ref) {
  return () => useNativeBluetooth ? NativeHrScanner() : BluetoothHrScanner();
});

/// Connects to a heart-rate device by platform id, returning a live source.
/// Overridden in tests with a fake connector.
typedef HrConnector =
    Future<HeartRateSource> Function(String platformId, String name);

final hrConnectorProvider = Provider<HrConnector>((ref) {
  return (platformId, name) {
    if (useNativeBluetooth) {
      return NativeBluetoothHeartRateSource.start(
        remoteId: platformId,
        name: name,
      );
    }
    return BluetoothHeartRateSource.connect(platformId, name: name);
  };
});
