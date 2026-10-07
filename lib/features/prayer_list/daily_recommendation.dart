import '../../data/models/prayer.dart';

/// Sections the home screen's daily recommendation is drawn from: chants a
/// lay person recites on their own, outside the two daily services.
const kRecommendationSectionIds = [
  'bot-suat-phiset',
  'charoen-phra-phuttha-mon',
];

/// The prayer recommended on [day], or null when [pool] is empty.
///
/// A rotation rather than a draw: the same prayer all day, the next one
/// tomorrow, and every prayer in [pool] once before any repeats. Pure, with
/// the date passed in, so it can be tested without waiting a day.
Prayer? recommendedPrayerOn(DateTime day, List<Prayer> pool) {
  if (pool.isEmpty) return null;
  // Counted from the local calendar date, so it turns over at midnight here
  // rather than at midnight UTC.
  final days = DateTime.utc(
    day.year,
    day.month,
    day.day,
  ).difference(DateTime.utc(2026)).inDays;
  return pool[days % pool.length];
}
