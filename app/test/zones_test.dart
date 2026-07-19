import 'package:cardio/core/zones/zones.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ZoneSetup effort math', () {
    const setup = ZoneSetup(maxHr: 160, restingHr: 60);

    test('computes HR Load percent between resting and max HR', () {
      expect(setup.hrLoadPercentFor(60), 0);
      expect(setup.hrLoadPercentFor(110), 50);
      expect(setup.hrLoadPercentFor(160), 100);
    });

    test('clamps displayed HR Load percent outside the profile range', () {
      expect(setup.hrLoadPercentFor(50), 0);
      expect(setup.hrLoadPercentFor(170), 100);
    });

    test('computes a floating zone value inside the active zone', () {
      expect(setup.floatingZoneFor(60), 1.0);
      expect(setup.floatingZoneFor(120), 2.0);
      expect(setup.floatingZoneFor(125), closeTo(2.5, 0.0001));
      expect(setup.floatingZoneFor(130), 3.0);
      expect(setup.floatingZoneFor(160), 6.0);
    });
  });
}
