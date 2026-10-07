import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/completion_signal.dart';
import '../../data/local/prefs_service.dart';
import '../../l10n/app_locale.dart';
import '../../theme/app_theme.dart';

/// Auto-scroll speed range and conversion factor to pixels per second.
///
/// 6 px/s a level: 6 at the slowest, 60 at the fastest. It was 12 (12–120)
/// until September 2026, when the owner found even level 1 too quick to chant
/// along with; the ten levels stay, so a saved level keeps its place on the
/// slider and simply moves at half the speed.
const kAutoScrollLevelMin = 1;
const kAutoScrollLevelMax = 10;
const kAutoScrollPxPerLevel = 6.0;

/// Daily chanting goal shown by the home card's progress ring, in minutes.
const kPracticeGoalMin = 1;
const kPracticeGoalMax = 120;
const kPracticeGoalDefault = 10;

/// Choices offered for the pause before auto-scroll starts moving, in seconds.
///
/// A short list rather than a slider: this is "let me find my place first",
/// which nobody needs to tune to the second.
const kAutoScrollDelayChoices = [0, 3, 5, 10];

/// Every user setting, as one immutable value.
class SettingsState {
  /// Prayer content font-size multiplier; 1.0 is 100%.
  final double fontScale;
  final AppLineSpacing lineSpacing;
  final ThemeMode themeMode;

  /// Per-lane reader text colors: chant, Romanized Pali, translation.
  final ReadingColors readingColors;

  /// UI language; does not change content language.
  final AppLocale locale;

  /// Whether Pali/translation appears inline under each verse.
  final bool inlineTranslation;

  /// Whether block headings appear above each part while reading.
  final bool showPartTitles;

  /// How the meditation timer announces that a session has finished.
  final CompletionSignal completionSignal;

  /// How loud the completion bell rings, 0-1.
  final double completionVolume;

  /// Whether reader text is justified instead of left-aligned.
  final bool justifyText;

  /// Whether reading uses continuous category/playlist mode.
  final bool continuousReading;

  /// Whether auto-scroll is enabled; disabling hides the reader play button.
  final bool autoScrollEnabled;

  /// Auto-scroll speed level.
  final int autoScrollLevel;

  /// Whether auto-scroll starts immediately when a prayer opens.
  final bool autoScrollAutoStart;

  /// Seconds to wait before auto-scroll starts moving; 0 waits not at all.
  final int autoScrollDelaySeconds;

  /// The paper the reading screen is printed on.
  final ReadingBackground pageBackground;

  /// Whether the reader opens with the Romanized Pali lane shown.
  final bool showRomanDefault;

  /// Whether the reader opens with the translation shown.
  final bool showMeaningDefault;

  /// Whether the screen is held awake while a prayer is open.
  final bool keepScreenOn;

  /// Whether the reader opens with its bars already hidden.
  final bool startImmersive;

  /// Minutes of chanting the home card counts as a full day.
  final int practiceGoalMinutes;

  /// Effective scroll speed in pixels per second.
  double get autoScrollPxPerSec => autoScrollLevel * kAutoScrollPxPerLevel;

  const SettingsState({
    required this.fontScale,
    required this.lineSpacing,
    required this.themeMode,
    required this.readingColors,
    required this.locale,
    required this.inlineTranslation,
    required this.showPartTitles,
    required this.completionSignal,
    required this.completionVolume,
    required this.justifyText,
    required this.continuousReading,
    required this.autoScrollEnabled,
    required this.autoScrollLevel,
    required this.autoScrollAutoStart,
    required this.autoScrollDelaySeconds,
    required this.pageBackground,
    required this.showRomanDefault,
    required this.showMeaningDefault,
    required this.keepScreenOn,
    required this.startImmersive,
    required this.practiceGoalMinutes,
  });

  SettingsState copyWith({
    double? fontScale,
    AppLineSpacing? lineSpacing,
    ThemeMode? themeMode,
    ReadingColors? readingColors,
    AppLocale? locale,
    bool? inlineTranslation,
    bool? showPartTitles,
    CompletionSignal? completionSignal,
    double? completionVolume,
    bool? justifyText,
    bool? continuousReading,
    bool? autoScrollEnabled,
    int? autoScrollLevel,
    bool? autoScrollAutoStart,
    int? autoScrollDelaySeconds,
    ReadingBackground? pageBackground,
    bool? showRomanDefault,
    bool? showMeaningDefault,
    bool? keepScreenOn,
    bool? startImmersive,
    int? practiceGoalMinutes,
  }) {
    return SettingsState(
      fontScale: fontScale ?? this.fontScale,
      lineSpacing: lineSpacing ?? this.lineSpacing,
      themeMode: themeMode ?? this.themeMode,
      readingColors: readingColors ?? this.readingColors,
      locale: locale ?? this.locale,
      inlineTranslation: inlineTranslation ?? this.inlineTranslation,
      showPartTitles: showPartTitles ?? this.showPartTitles,
      completionSignal: completionSignal ?? this.completionSignal,
      completionVolume: completionVolume ?? this.completionVolume,
      justifyText: justifyText ?? this.justifyText,
      continuousReading: continuousReading ?? this.continuousReading,
      autoScrollEnabled: autoScrollEnabled ?? this.autoScrollEnabled,
      autoScrollLevel: autoScrollLevel ?? this.autoScrollLevel,
      autoScrollAutoStart: autoScrollAutoStart ?? this.autoScrollAutoStart,
      autoScrollDelaySeconds:
          autoScrollDelaySeconds ?? this.autoScrollDelaySeconds,
      pageBackground: pageBackground ?? this.pageBackground,
      showRomanDefault: showRomanDefault ?? this.showRomanDefault,
      showMeaningDefault: showMeaningDefault ?? this.showMeaningDefault,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      startImmersive: startImmersive ?? this.startImmersive,
      practiceGoalMinutes: practiceGoalMinutes ?? this.practiceGoalMinutes,
    );
  }
}

/// Settings state and logic, persisted to SharedPreferences on every change.
class SettingsController extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    final prefs = ref.read(prefsServiceProvider);
    return SettingsState(
      fontScale: prefs.getFontScale().clamp(kFontScaleMin, kFontScaleMax),
      lineSpacing: AppLineSpacing.fromName(prefs.getLineSpacing()),
      themeMode: ThemeMode.values.firstWhere(
        (m) => m.name == prefs.getThemeMode(),
        orElse: () => ThemeMode.system,
      ),
      readingColors: ReadingColors(
        chant: ReadingColor.parse(prefs.getLaneColor(ReadingLane.chant.name)),
        roman: ReadingColor.parse(prefs.getLaneColor(ReadingLane.roman.name)),
        meaning: ReadingColor.parse(
          prefs.getLaneColor(ReadingLane.meaning.name),
        ),
      ),
      locale: AppLocale.fromName(prefs.getLocale()),
      inlineTranslation: prefs.getInlineTranslation(),
      showPartTitles: prefs.getShowPartTitles(),
      completionSignal: CompletionSignal.fromName(prefs.getCompletionSignal()),
      completionVolume: prefs.getCompletionVolume() ?? 1.0,
      justifyText: prefs.getJustifyText(),
      continuousReading: prefs.getContinuousReading(),
      autoScrollEnabled: prefs.getAutoScrollEnabled(),
      autoScrollLevel: prefs.getAutoScrollLevel().clamp(
        kAutoScrollLevelMin,
        kAutoScrollLevelMax,
      ),
      autoScrollAutoStart: prefs.getAutoScrollAutoStart(),
      autoScrollDelaySeconds:
          kAutoScrollDelayChoices.contains(prefs.getAutoScrollDelay())
          ? prefs.getAutoScrollDelay()
          : 0,
      pageBackground: ReadingBackground.fromName(prefs.getReadingBackground()),
      showRomanDefault: prefs.getShowRomanDefault(),
      showMeaningDefault: prefs.getShowMeaningDefault(),
      keepScreenOn: prefs.getKeepScreenOn(),
      startImmersive: prefs.getStartImmersive(),
      practiceGoalMinutes:
          (prefs.getPracticeGoalMinutes() ?? kPracticeGoalDefault).clamp(
            kPracticeGoalMin,
            kPracticeGoalMax,
          ),
    );
  }

  void setFontScale(double scale) {
    // Round to two decimals to avoid slider floating-point noise.
    final rounded =
        (scale.clamp(kFontScaleMin, kFontScaleMax) * 100).round() / 100;
    state = state.copyWith(fontScale: rounded);
    ref.read(prefsServiceProvider).setFontScale(rounded);
  }

  /// Moves font size by one button step for reader A-/A+ controls.
  void stepFontSize(int delta) {
    setFontScale(state.fontScale + delta * kFontScaleButtonStep);
  }

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    ref.read(prefsServiceProvider).setThemeMode(mode.name);
  }

  /// Changes UI language; `MaterialApp` reads this state into `locale`.
  ///
  /// Scheduled notification text is stored by the OS at schedule time, so the
  /// reminders controller reschedules enabled reminders when this changes.
  void setLocale(AppLocale locale) {
    state = state.copyWith(locale: locale);
    ref.read(prefsServiceProvider).setLocale(locale.name);
  }

  /// Sets one lane's color; the other two lanes are untouched.
  void setLaneColor(ReadingLane lane, ReadingColor color) {
    state = state.copyWith(
      readingColors: state.readingColors.withLane(lane, color),
    );
    ref.read(prefsServiceProvider).setLaneColor(lane.name, color.storage);
  }

  void setLineSpacing(AppLineSpacing spacing) {
    state = state.copyWith(lineSpacing: spacing);
    ref.read(prefsServiceProvider).setLineSpacing(spacing.name);
  }

  void setInlineTranslation(bool value) {
    state = state.copyWith(inlineTranslation: value);
    ref.read(prefsServiceProvider).setInlineTranslation(value);
  }

  void setShowPartTitles(bool value) {
    state = state.copyWith(showPartTitles: value);
    ref.read(prefsServiceProvider).setShowPartTitles(value);
  }

  void setCompletionVolume(double value) {
    state = state.copyWith(completionVolume: value);
    ref.read(prefsServiceProvider).setCompletionVolume(value);
  }

  void setCompletionSignal(CompletionSignal value) {
    state = state.copyWith(completionSignal: value);
    ref.read(prefsServiceProvider).setCompletionSignal(value.name);
  }

  void setJustifyText(bool value) {
    state = state.copyWith(justifyText: value);
    ref.read(prefsServiceProvider).setJustifyText(value);
  }

  void setContinuousReading(bool value) {
    state = state.copyWith(continuousReading: value);
    ref.read(prefsServiceProvider).setContinuousReading(value);
  }

  void setAutoScrollEnabled(bool value) {
    state = state.copyWith(autoScrollEnabled: value);
    ref.read(prefsServiceProvider).setAutoScrollEnabled(value);
  }

  void setAutoScrollLevel(int level) {
    final clamped = level.clamp(kAutoScrollLevelMin, kAutoScrollLevelMax);
    state = state.copyWith(autoScrollLevel: clamped);
    ref.read(prefsServiceProvider).setAutoScrollLevel(clamped);
  }

  void setAutoScrollAutoStart(bool value) {
    state = state.copyWith(autoScrollAutoStart: value);
    ref.read(prefsServiceProvider).setAutoScrollAutoStart(value);
  }

  void setAutoScrollDelaySeconds(int seconds) {
    if (!kAutoScrollDelayChoices.contains(seconds)) return;
    state = state.copyWith(autoScrollDelaySeconds: seconds);
    ref.read(prefsServiceProvider).setAutoScrollDelay(seconds);
  }

  void setPageBackground(ReadingBackground background) {
    state = state.copyWith(pageBackground: background);
    ref.read(prefsServiceProvider).setReadingBackground(background.name);
  }

  void setShowRomanDefault(bool value) {
    state = state.copyWith(showRomanDefault: value);
    ref.read(prefsServiceProvider).setShowRomanDefault(value);
  }

  void setShowMeaningDefault(bool value) {
    state = state.copyWith(showMeaningDefault: value);
    ref.read(prefsServiceProvider).setShowMeaningDefault(value);
  }

  void setKeepScreenOn(bool value) {
    state = state.copyWith(keepScreenOn: value);
    ref.read(prefsServiceProvider).setKeepScreenOn(value);
  }

  void setStartImmersive(bool value) {
    state = state.copyWith(startImmersive: value);
    ref.read(prefsServiceProvider).setStartImmersive(value);
  }

  /// Puts every reading setting back to its shipped default.
  ///
  /// Deliberately reading-only: theme and language are chosen once and live on
  /// other pages, so a button on the reading page must not reach them. It goes
  /// through the ordinary setters so each value is persisted the same way it
  /// would be by hand — there is no second write path to keep in step.
  void resetReadingDefaults() {
    setFontScale(1.0);
    setLineSpacing(AppLineSpacing.normal);
    setJustifyText(false);
    setShowPartTitles(true);
    setContinuousReading(false);
    setInlineTranslation(false);
    setPageBackground(ReadingBackground.ivory);
    setShowRomanDefault(false);
    setShowMeaningDefault(false);
    setKeepScreenOn(true);
    setStartImmersive(false);
    setAutoScrollEnabled(true);
    setAutoScrollLevel(3);
    setAutoScrollAutoStart(false);
    setAutoScrollDelaySeconds(0);
    setPracticeGoalMinutes(kPracticeGoalDefault);
    for (final lane in ReadingLane.values) {
      setLaneColor(lane, ReadingColor.auto);
    }
  }

  void setPracticeGoalMinutes(int minutes) {
    final clamped = minutes.clamp(kPracticeGoalMin, kPracticeGoalMax);
    state = state.copyWith(practiceGoalMinutes: clamped);
    ref.read(prefsServiceProvider).setPracticeGoalMinutes(clamped);
  }
}

final settingsControllerProvider =
    NotifierProvider<SettingsController, SettingsState>(SettingsController.new);
