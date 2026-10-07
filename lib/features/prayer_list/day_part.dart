import '../../l10n/app_localizations.dart';

/// The part of the day the home header greets: morning 05:00–10:59, midday
/// 11:00–15:59, evening 16:00–18:59, night 19:00–04:59.
///
/// Its own enum rather than `ReminderSlot`, whose four slots are times a
/// person chants at and whose boundaries are theirs to set; these are fixed
/// clock ranges for a greeting.
enum DayPart {
  morning,
  midday,
  evening,
  night;

  /// Pure, with the clock passed in, so the boundaries can be tested.
  static DayPart of(DateTime time) => switch (time.hour) {
    >= 5 && < 11 => morning,
    >= 11 && < 16 => midday,
    >= 16 && < 19 => evening,
    _ => night,
  };

  /// The service the home card offers and the Start tab opens: the morning
  /// one until 16:00, the evening one from there through the night.
  ///
  /// Section ids, which are permanent; the title comes from the data.
  String get serviceSectionId => switch (this) {
    morning || midday => 'tham-wat-chao',
    evening || night => 'tham-wat-yen',
  };

  String greeting(AppLocalizations l10n) => switch (this) {
    morning => l10n.homeGreetingMorning,
    midday => l10n.homeGreetingMidday,
    evening => l10n.homeGreetingEvening,
    night => l10n.homeGreetingNight,
  };

  String subtitle(AppLocalizations l10n) => switch (this) {
    morning => l10n.homeGreetingMorningSubtitle,
    midday => l10n.homeGreetingMiddaySubtitle,
    evening => l10n.homeGreetingEveningSubtitle,
    night => l10n.homeGreetingNightSubtitle,
  };
}
