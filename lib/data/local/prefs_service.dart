import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden with the real instance in `main()` before `runApp`.
final prefsServiceProvider = Provider<PrefsService>((ref) {
  throw UnimplementedError('override prefsServiceProvider in main()');
});

/// SharedPreferences wrapper for favorites, settings, and small local state.
class PrefsService {
  static const _kFavoriteIds = 'favorite_ids';
  static const _kFontSize = 'font_size'; // Legacy level key; migration only.
  static const _kFontScale = 'font_scale';
  static const _kTextColor = 'text_color'; // Legacy single-lane key; seed only.
  static const _kTextColorPrefix = 'text_color_';
  static const _kDarkMode = 'dark_mode'; // Legacy bool key; migration only.
  static const _kThemeMode = 'theme_mode';
  static const _kLocale = 'locale';
  static const _kLastReadId = 'last_read_id';
  static const _kLastReadOffset = 'last_read_offset';
  static const _kLastReadContinuous = 'last_read_continuous';
  static const _kLastReadPlaylist = 'last_read_playlist';
  static const _kInlineTranslation = 'inline_translation';
  static const _kShowPartTitles = 'show_part_titles';
  static const _kLineSpacing = 'line_spacing';
  static const _kJustifyText = 'justify_text';
  static const _kContinuousReading = 'continuous_reading';
  static const _kAutoScrollEnabled = 'auto_scroll_enabled';
  static const _kAutoScrollLevel = 'auto_scroll_level';
  static const _kAutoScrollAutoStart = 'auto_scroll_auto_start';
  static const _kAutoScrollDelay = 'auto_scroll_delay';
  static const _kReadingBackground = 'reading_background';
  static const _kShowRomanDefault = 'show_roman_default';
  static const _kShowMeaningDefault = 'show_meaning_default';
  static const _kKeepScreenOn = 'keep_screen_on';
  static const _kStartImmersive = 'start_immersive';
  static const _kPlaylists = 'playlists';
  static const _kPlaylistsSort = 'playlists_sort';
  static const _kSearchHistory = 'search_history';
  static const _kPinned = 'pinned';
  static const _kSectionExtras = 'section_extras';
  static const _kSectionIcons = 'section_icons';
  static const _kWelcomeSeenVersion = 'welcome_seen_version';
  static const _kGoalPromptSeen = 'goal_prompt_seen';
  static const _kRemindersMaster = 'reminders_master';
  static const _kReminderEnabledPrefix = 'reminder_enabled_';
  static const _kReminderTimePrefix = 'reminder_time_';
  static const _kReminderDaysPrefix = 'reminder_days_';
  static const _kMeditationMinutes = 'meditation_minutes';
  static const _kCompletionSignal = 'completion_signal';
  static const _kCompletionVolume = 'completion_volume';
  static const _kMeditationStartSignal = 'meditation_start_signal';
  static const _kMeditationAmbient = 'meditation_ambient';
  static const _kMeditationAmbientVolume = 'meditation_ambient_volume';
  static const _kMalaCount = 'mala_count';
  static const _kMalaTarget = 'mala_target';
  static const _kRetiredReadingDates = 'reading_dates';
  static const _kPracticeSeconds = 'practice_seconds';
  static const _kPracticeGoalMinutes = 'practice_goal_minutes';
  static const _kContentAutoUpdate = 'content_auto_update';
  static const _kContentLastCheck = 'content_last_check';

  final SharedPreferences _prefs;

  PrefsService(this._prefs);

  static Future<PrefsService> init() async {
    final prefs = await SharedPreferences.getInstance();
    // The chanting streak was retired in October 2026; its list of dates is
    // no longer read, so it is not left behind on the device either.
    if (prefs.containsKey(_kRetiredReadingDates)) {
      prefs.remove(_kRetiredReadingDates).ignore();
    }
    return PrefsService(prefs);
  }

  // ---- Favorites ----

  List<String> getFavoriteIds() => _prefs.getStringList(_kFavoriteIds) ?? [];

  Future<void> setFavoriteIds(List<String> ids) =>
      _prefs.setStringList(_kFavoriteIds, ids);

  // ---- Settings ----

  /// Font-size multiplier. Migrates from legacy level values when present.
  double getFontScale() {
    final saved = _prefs.getDouble(_kFontScale);
    if (saved != null) return saved;
    switch (_prefs.getString(_kFontSize)) {
      case 'small':
        return 0.85;
      case 'large':
        return 1.2;
      case 'extraLarge':
        return 1.4;
    }
    return 1.0;
  }

  Future<void> setFontScale(double scale) =>
      _prefs.setDouble(_kFontScale, scale);

  /// Text color for one reading lane, keyed by `ReadingLane.name`.
  String getLaneColor(String lane) =>
      _prefs.getString('$_kTextColorPrefix$lane') ??
      _prefs.getString(_kTextColor) ??
      'auto';

  Future<void> setLaneColor(String lane, String value) =>
      _prefs.setString('$_kTextColorPrefix$lane', value);

  /// Stored value: light | dark | system. Migrates from legacy dark_mode bool.
  String getThemeMode() {
    final saved = _prefs.getString(_kThemeMode);
    if (saved != null) return saved;
    final legacyDark = _prefs.getBool(_kDarkMode);
    if (legacyDark != null) return legacyDark ? 'dark' : 'light';
    return 'system';
  }

  Future<void> setThemeMode(String mode) => _prefs.setString(_kThemeMode, mode);

  /// Stored value: `AppLocale.name`, or null if never set.
  String? getLocale() => _prefs.getString(_kLocale);

  Future<void> setLocale(String name) => _prefs.setString(_kLocale, name);

  /// How "ชุดสวดของฉัน" orders its cards, by the order's name; null is the
  /// order the sets were made in.
  String? getPlaylistsSort() => _prefs.getString(_kPlaylistsSort);

  Future<void> setPlaylistsSort(String name) =>
      _prefs.setString(_kPlaylistsSort, name);

  /// Whether Pali/translation appears inline under each verse.
  bool getInlineTranslation() => _prefs.getBool(_kInlineTranslation) ?? false;

  Future<void> setInlineTranslation(bool value) =>
      _prefs.setBool(_kInlineTranslation, value);

  /// Whether block headings show above each part on the reading screen.
  bool getShowPartTitles() => _prefs.getBool(_kShowPartTitles) ?? true;

  Future<void> setShowPartTitles(bool value) =>
      _prefs.setBool(_kShowPartTitles, value);

  /// Stored value: compact | normal | loose.
  String getLineSpacing() => _prefs.getString(_kLineSpacing) ?? 'normal';

  Future<void> setLineSpacing(String value) =>
      _prefs.setString(_kLineSpacing, value);

  /// Whether reader text is justified instead of left-aligned.
  bool getJustifyText() => _prefs.getBool(_kJustifyText) ?? false;

  Future<void> setJustifyText(bool value) =>
      _prefs.setBool(_kJustifyText, value);

  /// Whether the reader uses continuous mode instead of one prayer per page.
  bool getContinuousReading() => _prefs.getBool(_kContinuousReading) ?? false;

  Future<void> setContinuousReading(bool value) =>
      _prefs.setBool(_kContinuousReading, value);

  /// Whether auto-scroll is enabled; disabling it hides the reader's play button.
  bool getAutoScrollEnabled() => _prefs.getBool(_kAutoScrollEnabled) ?? true;

  Future<void> setAutoScrollEnabled(bool value) =>
      _prefs.setBool(_kAutoScrollEnabled, value);

  /// Auto-scroll speed level, 1-10.
  int getAutoScrollLevel() => _prefs.getInt(_kAutoScrollLevel) ?? 3;

  Future<void> setAutoScrollLevel(int level) =>
      _prefs.setInt(_kAutoScrollLevel, level);

  /// Whether auto-scroll starts as soon as a prayer opens.
  bool getAutoScrollAutoStart() =>
      _prefs.getBool(_kAutoScrollAutoStart) ?? false;

  Future<void> setAutoScrollAutoStart(bool value) =>
      _prefs.setBool(_kAutoScrollAutoStart, value);

  /// How a finished meditation session is announced: sound | haptic | silent.
  String getCompletionSignal() =>
      _prefs.getString(_kCompletionSignal) ?? 'haptic';

  Future<void> setCompletionSignal(String name) =>
      _prefs.setString(_kCompletionSignal, name);

  /// Bell volume, 0-1; null until the slider is first moved.
  double? getCompletionVolume() => _prefs.getDouble(_kCompletionVolume);

  Future<void> setCompletionVolume(double volume) =>
      _prefs.setDouble(_kCompletionVolume, volume);

  /// Latest welcome-sheet version the user has seen.
  int getWelcomeSeenVersion() => _prefs.getInt(_kWelcomeSeenVersion) ?? 0;

  Future<void> setWelcomeSeenVersion(int version) =>
      _prefs.setInt(_kWelcomeSeenVersion, version);

  // ---- Playlists ----

  /// Each entry is one playlist encoded as a JSON string.
  List<String> getPlaylistsRaw() => _prefs.getStringList(_kPlaylists) ?? [];

  Future<void> setPlaylistsRaw(List<String> raw) =>
      _prefs.setStringList(_kPlaylists, raw);

  // ---- Home pins ----

  /// `null` means the key has never existed, which differs from `[]`.
  List<String>? getPinnedRaw() => _prefs.getStringList(_kPinned);

  Future<void> setPinnedRaw(List<String> raw) =>
      _prefs.setStringList(_kPinned, raw);

  // ---- User-added prayers in shipped sections ----

  /// `["<sectionId>:<prayerId>", ...]`; list order is append order.
  List<String> getSectionExtrasRaw() =>
      _prefs.getStringList(_kSectionExtras) ?? [];

  Future<void> setSectionExtrasRaw(List<String> raw) =>
      _prefs.setStringList(_kSectionExtras, raw);

  // ---- User section icon overrides ----

  /// `["<sectionId>:<iconName>", ...]`; only changed sections are stored.
  /// Missing sections use the shipped `icon` field.
  List<String> getSectionIconsRaw() =>
      _prefs.getStringList(_kSectionIcons) ?? [];

  Future<void> setSectionIconsRaw(List<String> raw) =>
      _prefs.setStringList(_kSectionIcons, raw);

  /// Seconds to wait before auto-scroll actually starts moving. 0 = no wait.
  int getAutoScrollDelay() => _prefs.getInt(_kAutoScrollDelay) ?? 0;

  Future<void> setAutoScrollDelay(int value) =>
      _prefs.setInt(_kAutoScrollDelay, value);

  /// `ReadingBackground.name`; null falls back to the app's own page color.
  String? getReadingBackground() => _prefs.getString(_kReadingBackground);

  Future<void> setReadingBackground(String value) =>
      _prefs.setString(_kReadingBackground, value);

  /// Whether the reader opens with the Romanized Pali lane already shown.
  ///
  /// Defaults to off, which is how the reader's own chips have always started;
  /// this only lets a user make their habit the default.
  bool getShowRomanDefault() => _prefs.getBool(_kShowRomanDefault) ?? false;

  Future<void> setShowRomanDefault(bool value) =>
      _prefs.setBool(_kShowRomanDefault, value);

  bool getShowMeaningDefault() => _prefs.getBool(_kShowMeaningDefault) ?? false;

  Future<void> setShowMeaningDefault(bool value) =>
      _prefs.setBool(_kShowMeaningDefault, value);

  /// Defaults to on: the reader has always held the screen awake, so this
  /// starts as a way to turn that off rather than a new thing to turn on.
  bool getKeepScreenOn() => _prefs.getBool(_kKeepScreenOn) ?? true;

  Future<void> setKeepScreenOn(bool value) =>
      _prefs.setBool(_kKeepScreenOn, value);

  /// Whether the reader opens with its bars already hidden.
  bool getStartImmersive() => _prefs.getBool(_kStartImmersive) ?? false;

  Future<void> setStartImmersive(bool value) =>
      _prefs.setBool(_kStartImmersive, value);

  /// Whether the goal page has already been offered after install.
  ///
  /// Separate from the welcome version so bumping that to announce a feature
  /// does not ask an existing user to set a goal all over again.
  bool getGoalPromptSeen() => _prefs.getBool(_kGoalPromptSeen) ?? false;

  Future<void> setGoalPromptSeen(bool value) =>
      _prefs.setBool(_kGoalPromptSeen, value);

  // ---- Prayer-time reminders (slot: morning | evening) ----

  /// Master switch for every reminder slot.
  ///
  /// Defaults to on: every slot already defaults to off, so a fresh install
  /// schedules nothing either way and the switch reads as "reminders are
  /// allowed" rather than as a second thing to remember to turn on.
  bool getRemindersMaster() => _prefs.getBool(_kRemindersMaster) ?? true;

  Future<void> setRemindersMaster(bool value) =>
      _prefs.setBool(_kRemindersMaster, value);

  bool getReminderEnabled(String slot) =>
      _prefs.getBool('$_kReminderEnabledPrefix$slot') ?? false;

  Future<void> setReminderEnabled(String slot, bool value) =>
      _prefs.setBool('$_kReminderEnabledPrefix$slot', value);

  /// Time in "HH:mm" format.
  ///
  /// The per-slot default comes from the caller: which times suit morning,
  /// midday, evening and bedtime is `ReminderSlot`'s business, and this layer
  /// must not import a feature to answer it.
  String getReminderTime(String slot, {required String fallback}) =>
      _prefs.getString('$_kReminderTimePrefix$slot') ?? fallback;

  Future<void> setReminderTime(String slot, String value) =>
      _prefs.setString('$_kReminderTimePrefix$slot', value);

  /// Weekdays as `DateTime.monday`..`sunday` digits, e.g. `"135"`.
  ///
  /// A string of digits rather than a list because it is at most seven
  /// characters and reads correctly in a prefs dump. Missing means every day,
  /// which is what reminders did before days could be chosen.
  String getReminderDays(String slot) =>
      _prefs.getString('$_kReminderDaysPrefix$slot') ?? '1234567';

  Future<void> setReminderDays(String slot, String value) =>
      _prefs.setString('$_kReminderDaysPrefix$slot', value);

  // ---- Search history ----

  /// Recent queries, newest first. SearchHistoryController owns the size limit.
  List<String> getSearchHistory() =>
      _prefs.getStringList(_kSearchHistory) ?? [];

  Future<void> setSearchHistory(List<String> queries) =>
      _prefs.setStringList(_kSearchHistory, queries);

  // ---- Last-read position ----

  String? getLastReadId() => _prefs.getString(_kLastReadId);

  Future<void> setLastReadId(String id) => _prefs.setString(_kLastReadId, id);

  /// Last scroll offset in px, restored only with the same reader context.
  double getLastReadOffset() => _prefs.getDouble(_kLastReadOffset) ?? 0;

  bool getLastReadContinuous() => _prefs.getBool(_kLastReadContinuous) ?? false;

  /// Playlist id at save time; empty string means category reading.
  String getLastReadPlaylist() => _prefs.getString(_kLastReadPlaylist) ?? '';

  Future<void> setLastReadPosition(
    double offset, {
    required bool continuous,
    required String playlistId,
  }) async {
    await _prefs.setDouble(_kLastReadOffset, offset);
    await _prefs.setBool(_kLastReadContinuous, continuous);
    await _prefs.setString(_kLastReadPlaylist, playlistId);
  }

  // ---- Meditation ----

  /// Last selected meditation-timer duration in minutes.
  int getMeditationMinutes() => _prefs.getInt(_kMeditationMinutes) ?? 10;

  Future<void> setMeditationMinutes(int minutes) =>
      _prefs.setInt(_kMeditationMinutes, minutes);

  /// How a sitting is announced when it starts; a `CompletionSignal` name.
  ///
  /// Null until chosen, so the screen can default it to silence rather than
  /// surprising anyone already using the timer with a new sound.
  String? getMeditationStartSignal() =>
      _prefs.getString(_kMeditationStartSignal);

  Future<void> setMeditationStartSignal(String name) =>
      _prefs.setString(_kMeditationStartSignal, name);

  /// Name of the nature sound played under a sitting; null until one is
  /// chosen, which reads as none so an update adds no sound by itself.
  String? getMeditationAmbient() => _prefs.getString(_kMeditationAmbient);

  Future<void> setMeditationAmbient(String name) =>
      _prefs.setString(_kMeditationAmbient, name);

  /// Nature-sound volume, 0-1; null until the slider is first moved.
  double? getMeditationAmbientVolume() =>
      _prefs.getDouble(_kMeditationAmbientVolume);

  Future<void> setMeditationAmbientVolume(double volume) =>
      _prefs.setDouble(_kMeditationAmbientVolume, volume);

  // ---- Mala counter ----

  /// Persisted count so chanting can resume after the app is closed.
  // ---- Prayer updates (docs/architecture/content-updates.md) ----

  /// Whether the app looks for a newer prayer book by itself. On by default:
  /// a correction nobody receives is the problem this exists to solve.
  bool getContentAutoUpdate() => _prefs.getBool(_kContentAutoUpdate) ?? true;

  Future<void> setContentAutoUpdate(bool value) =>
      _prefs.setBool(_kContentAutoUpdate, value);

  /// When the app last asked, in milliseconds since the epoch; 0 for never.
  int getContentLastCheck() => _prefs.getInt(_kContentLastCheck) ?? 0;

  Future<void> setContentLastCheck(int millis) =>
      _prefs.setInt(_kContentLastCheck, millis);

  int getMalaCount() => _prefs.getInt(_kMalaCount) ?? 0;

  Future<void> setMalaCount(int count) => _prefs.setInt(_kMalaCount, count);

  /// Target count; 108 is one traditional mala round.
  int getMalaTarget() => _prefs.getInt(_kMalaTarget) ?? 108;

  Future<void> setMalaTarget(int target) => _prefs.setInt(_kMalaTarget, target);

  // ---- Practice time ----

  /// Practice seconds per day as `yyyy-MM-dd:seconds` entries.
  List<String> getPracticeSeconds() =>
      _prefs.getStringList(_kPracticeSeconds) ?? [];

  Future<void> setPracticeSeconds(List<String> entries) =>
      _prefs.setStringList(_kPracticeSeconds, entries);

  /// Daily chanting goal in minutes; null until the user picks one.
  int? getPracticeGoalMinutes() => _prefs.getInt(_kPracticeGoalMinutes);

  Future<void> setPracticeGoalMinutes(int minutes) =>
      _prefs.setInt(_kPracticeGoalMinutes, minutes);
}
