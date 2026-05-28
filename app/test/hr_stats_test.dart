import 'package:cardio/features/activity/hr_stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HrStats.fromHeartRates', () {
    test('empty input yields empty stats', () {
      final stats = HrStats.fromHeartRates(const []);
      expect(stats.isEmpty, isTrue);
      expect(stats.min, isNull);
      expect(stats.avg, isNull);
      expect(stats.max, isNull);
    });

    test('all-null input is treated as empty', () {
      final stats = HrStats.fromHeartRates(const [null, null]);
      expect(stats.isEmpty, isTrue);
      expect(stats.sampleCount, 0);
    });

    test('computes min/avg/max over non-null values', () {
      final stats = HrStats.fromHeartRates(const [100, 120, 140]);
      expect(stats.min, 100);
      expect(stats.max, 140);
      expect(stats.avg, 120);
      expect(stats.sampleCount, 3);
    });

    test('skips null gaps without counting them', () {
      final stats = HrStats.fromHeartRates(const [100, null, 200]);
      expect(stats.min, 100);
      expect(stats.max, 200);
      expect(stats.avg, 150);
      expect(stats.sampleCount, 2);
    });

    test('rounds the average to the nearest integer', () {
      final stats = HrStats.fromHeartRates(const [100, 101]);
      expect(stats.avg, 101);
    });
  });

  group('HrAxisRange.forStats', () {
    test('falls back to a default range without data', () {
      final range = HrAxisRange.forStats();
      expect(range.minY, 40);
      expect(range.maxY, 200);
    });

    test('floor rounds down to a multiple of ten below the min', () {
      expect(HrAxisRange.forStats(minHr: 44, maxHr: 180).minY, 40);
      expect(HrAxisRange.forStats(minHr: 50, maxHr: 180).minY, 40);
      expect(HrAxisRange.forStats(minHr: 41, maxHr: 180).minY, 40);
    });

    test('ceiling rounds up to a multiple of ten above the max', () {
      expect(HrAxisRange.forStats(minHr: 60, maxHr: 181).maxY, 190);
      expect(HrAxisRange.forStats(minHr: 60, maxHr: 180).maxY, 190);
    });

    test('span is the difference between bounds', () {
      final range = HrAxisRange.forStats(minHr: 60, maxHr: 180);
      expect(range.span, range.maxY - range.minY);
    });
  });
}
