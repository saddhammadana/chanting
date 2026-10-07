import 'dart:convert';
import 'dart:io';

import 'package:chanting/data/models/prayer.dart';
import 'package:chanting/features/prayer_list/daily_recommendation.dart';
import 'package:flutter_test/flutter_test.dart';

/// The pool as the home screen builds it, read from the real data files.
List<Prayer> _pool() {
  final prayers = {
    for (final raw
        in jsonDecode(File('assets/data/prayers-th.json').readAsStringSync())
            as List)
      (raw as Map<String, dynamic>)['id'] as String: Prayer.fromJson(raw),
  };
  final sections =
      jsonDecode(File('assets/data/sections-th.json').readAsStringSync())
          as List;
  return [
    for (final id in kRecommendationSectionIds)
      for (final prayerId
          in sections.firstWhere((s) => s['id'] == id)['prayerIds'] as List)
        prayers[prayerId]!,
  ];
}

void main() {
  test(
    'the sections the recommendation draws from exist and are not empty',
    () {
      expect(_pool(), isNotEmpty);
    },
  );

  test('one prayer all day, a different one the next day', () {
    final pool = _pool();
    final morning = recommendedPrayerOn(DateTime(2026, 10, 3, 5), pool);
    final night = recommendedPrayerOn(DateTime(2026, 10, 3, 23, 59), pool);
    final tomorrow = recommendedPrayerOn(DateTime(2026, 10, 4, 0, 1), pool);

    expect(morning!.id, night!.id);
    expect(tomorrow!.id, isNot(morning.id));
  });

  test('every prayer in the pool comes up once before any repeats', () {
    final pool = _pool();
    final seen = {
      for (var i = 0; i < pool.length; i++)
        recommendedPrayerOn(DateTime(2026, 10, 3 + i), pool)!.id,
    };
    expect(seen.length, pool.length);
  });

  test('an empty pool recommends nothing and a date before 2026 is fine', () {
    expect(recommendedPrayerOn(DateTime(2026, 10, 3), const []), isNull);
    expect(recommendedPrayerOn(DateTime(2020, 1, 1), _pool()), isNotNull);
  });
}
