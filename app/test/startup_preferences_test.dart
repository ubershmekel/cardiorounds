import 'dart:async';

import 'package:cardio/core/settings/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

/// Hangs on the first load, answers every later one — a platform reply that
/// was lost once.
class _HangsOnceStore extends SharedPreferencesStorePlatform {
  int loads = 0;

  Future<Map<String, Object>> _load() {
    loads++;
    if (loads == 1) return Completer<Map<String, Object>>().future;
    return Future.value({'flutter.answer': 42});
  }

  @override
  Future<Map<String, Object>> getAll() => _load();

  @override
  Future<Map<String, Object>> getAllWithPrefix(String prefix) => _load();

  @override
  Future<Map<String, Object>> getAllWithParameters(
    GetAllParameters parameters,
  ) => _load();

  @override
  Future<bool> clear() async => true;

  @override
  Future<bool> remove(String key) async => true;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      true;
}

void main() {
  test('retry after a timeout issues a fresh platform request', () async {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.resetStatic();
    final store = _HangsOnceStore();
    SharedPreferencesStorePlatform.instance = store;
    const timeout = Duration(milliseconds: 100);

    await expectLater(
      loadStartupPreferences(timeout: timeout),
      throwsA(isA<TimeoutException>()),
    );
    final prefs = await loadStartupPreferences(timeout: timeout);

    expect(store.loads, 2);
    expect(prefs.getInt('answer'), 42);
  });
}
