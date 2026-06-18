import 'package:cardio/core/build_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('appBuildLabel falls back to the package version', () {
    expect(appBuildLabel(version: '1.2.3'), '1.2.3');
  });

  test('appBuildLabel includes build date and hash when provided', () {
    expect(
      appBuildLabel(
        version: '1.2.3',
        buildDate: '2026-06-18T12:34:56Z',
        buildHash: 'abc1234',
      ),
      '1.2.3 (built 2026-06-18T12:34:56Z, abc1234)',
    );
  });
}
