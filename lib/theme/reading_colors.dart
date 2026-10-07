import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'app_colors.dart';

/// Prayer content text colors.
///
/// See docs/architecture/reader-colors.md for lanes, presets, and custom colors.
enum AppTextColor {
  auto(null, null),
  brown(Color(0xFF6D4C2F), Color(0xFFD9C3A3)),
  // Darkened so the preset itself passes the picker's AA contrast warning.
  gold(Color(0xFF7F6410), Color(0xFFD9B84A)),
  blue(Color(0xFF3A5A8C), Color(0xFF9FB9E3)),
  green(Color(0xFF3E6B4F), Color(0xFFA3C9A8));

  const AppTextColor(this._light, this._dark);

  final Color? _light;
  final Color? _dark;

  /// Color for the current theme; null means use normal theme text color.
  Color? resolve(Brightness brightness) =>
      brightness == Brightness.dark ? _dark : _light;

  static AppTextColor fromName(String name) => AppTextColor.values.firstWhere(
    (e) => e.name == name,
    orElse: () => AppTextColor.auto,
  );
}

/// The user-visible name of a text colour.
extension AppTextColorLabel on AppTextColor {
  /// User-visible color label.
  String label(AppLocalizations l10n) => switch (this) {
    AppTextColor.auto => l10n.textColorAuto,
    AppTextColor.brown => l10n.textColorBrown,
    AppTextColor.gold => l10n.textColorGold,
    AppTextColor.blue => l10n.textColorBlue,
    AppTextColor.green => l10n.textColorGreen,
  };
}

/// The three text layers of a prayer page, each colored independently.
enum ReadingLane { chant, roman, meaning }

/// The user-visible name of a reading lane.
extension ReadingLaneLabel on ReadingLane {
  String label(AppLocalizations l10n) => switch (this) {
    ReadingLane.chant => l10n.textLaneChant,
    ReadingLane.roman => l10n.paliSectionTitle,
    ReadingLane.meaning => l10n.labelMeaning,
  };
}

/// One lane's color: either a named preset or a light/dark custom pair.
@immutable
class ReadingColor {
  const ReadingColor._(this._preset, this._light, this._dark);

  const ReadingColor.preset(AppTextColor preset) : this._(preset, null, null);

  const ReadingColor.custom({required Color light, required Color dark})
    : this._(null, light, dark);

  /// Follow the theme's own text color.
  static const auto = ReadingColor.preset(AppTextColor.auto);

  final AppTextColor? _preset;
  final Color? _light;
  final Color? _dark;

  /// The preset this lane uses, or null when the color is custom.
  AppTextColor? get preset => _preset;

  bool get isCustom => _preset == null;

  /// Whether this lane just follows the theme, i.e. the user has chosen nothing.
  bool get isAuto => _preset == AppTextColor.auto;

  /// Color for [brightness]; null means use normal theme text color.
  Color? resolve(Brightness brightness) => _preset != null
      ? _preset.resolve(brightness)
      : (brightness == Brightness.dark ? _dark : _light);

  static const _customPrefix = 'custom:';

  /// Value written to SharedPreferences.
  String get storage {
    final preset = _preset;
    if (preset != null) return preset.name;
    return '$_customPrefix${_hex(_light!)}:${_hex(_dark!)}';
  }

  /// Parses a stored value, falling back to [auto] for anything unrecognized.
  static ReadingColor parse(String? raw) {
    if (raw == null || raw.isEmpty) return auto;
    if (!raw.startsWith(_customPrefix)) {
      return ReadingColor.preset(AppTextColor.fromName(raw));
    }
    final parts = raw.substring(_customPrefix.length).split(':');
    if (parts.length != 2) return auto;
    final light = parseHex(parts[0]);
    final dark = parseHex(parts[1]);
    if (light == null || dark == null) return auto;
    return ReadingColor.custom(light: light, dark: dark);
  }

  /// This lane with [color] applied to [brightness] only.
  ///
  /// The other theme keeps its current resolved color.
  ReadingColor withCustomFor(
    Brightness brightness,
    Color color, {
    required Color otherFallback,
  }) {
    final otherBrightness = brightness == Brightness.dark
        ? Brightness.light
        : Brightness.dark;
    final other = resolve(otherBrightness) ?? otherFallback;
    return brightness == Brightness.dark
        ? ReadingColor.custom(light: other, dark: color)
        : ReadingColor.custom(light: color, dark: other);
  }

  /// Six-digit hex for [brightness], for the picker's text field.
  String? hexFor(Brightness brightness) {
    final color = resolve(brightness);
    return color == null ? null : _hex(color);
  }

  String label(AppLocalizations l10n) =>
      _preset?.label(l10n) ?? l10n.textColorCustom;

  /// `RRGGBB`, uppercase. Alpha is dropped because reading text is opaque.
  static String _hex(Color color) => (color.toARGB32() & 0xFFFFFF)
      .toRadixString(16)
      .padLeft(6, '0')
      .toUpperCase();

  /// Parses `RRGGBB`, `#RRGGBB`, or three-digit shorthand.
  static Color? parseHex(String raw) {
    var value = raw.trim();
    if (value.startsWith('#')) value = value.substring(1);
    if (value.length == 3) {
      value = value.split('').map((c) => '$c$c').join();
    }
    if (value.length != 6) return null;
    final parsed = int.tryParse(value, radix: 16);
    if (parsed == null) return null;
    return Color(0xFF000000 | parsed);
  }

  @override
  bool operator ==(Object other) =>
      other is ReadingColor &&
      other._preset == _preset &&
      other._light == _light &&
      other._dark == _dark;

  @override
  int get hashCode => Object.hash(_preset, _light, _dark);
}

/// The reader's three lane colors.
@immutable
class ReadingColors {
  const ReadingColors({
    required this.chant,
    required this.roman,
    required this.meaning,
  });

  /// Every lane following the theme; the shipped default.
  static const auto = ReadingColors(
    chant: ReadingColor.auto,
    roman: ReadingColor.auto,
    meaning: ReadingColor.auto,
  );

  final ReadingColor chant;
  final ReadingColor roman;
  final ReadingColor meaning;

  ReadingColor of(ReadingLane lane) => switch (lane) {
    ReadingLane.chant => chant,
    ReadingLane.roman => roman,
    ReadingLane.meaning => meaning,
  };

  ReadingColors withLane(ReadingLane lane, ReadingColor color) =>
      switch (lane) {
        ReadingLane.chant => ReadingColors(
          chant: color,
          roman: roman,
          meaning: meaning,
        ),
        ReadingLane.roman => ReadingColors(
          chant: chant,
          roman: color,
          meaning: meaning,
        ),
        ReadingLane.meaning => ReadingColors(
          chant: chant,
          roman: roman,
          meaning: color,
        ),
      };

  @override
  bool operator ==(Object other) =>
      other is ReadingColors &&
      other.chant == chant &&
      other.roman == roman &&
      other.meaning == meaning;

  @override
  int get hashCode => Object.hash(chant, roman, meaning);
}

/// The theme's own reader text color for [brightness].
///
/// This is what an `auto` lane renders as. The picker also opens on it, so
/// fine-tuning from `auto` starts where the text already is instead of jumping
/// to an unrelated color. It mirrors `ColorScheme.onSurface` in [AppTheme]; the
/// two must stay in step, which is why both read the same [AppColors] constant.
Color defaultReadingText(Brightness brightness) =>
    brightness == Brightness.dark ? AppColors.darkCream : AppColors.brownDark;

/// The page color prayer text is read against, used for the contrast check.
///
/// The scaffold background, not the card surface: reading screens paint text
/// straight onto the page.
Color readingBackground(Brightness brightness) =>
    brightness == Brightness.dark ? AppColors.darkBackground : AppColors.cream;

/// The paper the reading screen is printed on.
///
/// Separate from the app theme because it is a reading choice, not a system
/// one: the same person reads on ivory by day and wants the page — not the
/// whole app — to go dark at night. Each option therefore carries the
/// [brightness] its text must be resolved against, which is what
/// `ReadingColor.resolve` needs and what an `auto` lane follows.
enum ReadingBackground {
  ivory(AppColors.cream, Brightness.light),
  white(Color(0xFFFFFFFF), Brightness.light),
  // Warm paper. Light enough for the dark presets to keep their contrast.
  sepia(Color(0xFFF3E4CB), Brightness.light),
  night(AppColors.darkBackground, Brightness.dark);

  const ReadingBackground(this.color, this.brightness);

  final Color color;

  /// Whether text on this page should be resolved as light-theme or dark-theme
  /// text. `night` is the only dark one.
  final Brightness brightness;

  /// SharedPreferences stores `name`; anything unrecognized reads as [ivory],
  /// which is the app's own page color and therefore the safe fallback.
  static ReadingBackground fromName(String? name) => values.firstWhere(
    (e) => e.name == name,
    orElse: () => ReadingBackground.ivory,
  );
}

/// The user-visible name of a page colour.
extension ReadingBackgroundLabel on ReadingBackground {
  String label(AppLocalizations l10n) => switch (this) {
    ReadingBackground.ivory => l10n.readingBackgroundIvory,
    ReadingBackground.white => l10n.readingBackgroundWhite,
    ReadingBackground.sepia => l10n.readingBackgroundSepia,
    ReadingBackground.night => l10n.readingBackgroundNight,
  };
}

/// The page actually used, given the app theme.
///
/// A dark app theme forces [ReadingBackground.night]: the reader's own chrome
/// is painted in the page color, so a cream page under a dark app would put a
/// light island in the middle of a dark screen. The choice still governs the
/// light theme, which is where all four options differ.
ReadingBackground effectiveReadingBackground(
  ReadingBackground chosen,
  Brightness themeBrightness,
) => themeBrightness == Brightness.dark ? ReadingBackground.night : chosen;

/// WCAG contrast ratio between two opaque colors, from 1 (identical) to 21.
///
/// `Color.computeLuminance` is already WCAG relative luminance, so this is the
/// ratio formula on top of it.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

/// WCAG AA for body text. Prayer text is read for long stretches at whatever
/// size the user chose, so the picker warns below this rather than at the
/// looser large-text threshold.
///
/// Note this is a **warning** threshold, not a floor: the shipped `gold` preset
/// measures 3.63 on the light background and therefore trips it. That is real
/// information rather than a bug in the check — gold on cream genuinely is the
/// hardest preset to read — so it is left to say so instead of being suppressed.
const kMinReadableContrast = 4.5;

/// WCAG AA for large text, and the floor a shipped preset must clear.
///
/// Presets are offered as safe choices, so `reading_colors_test` holds them to
/// this. It is the looser tier because of `gold` above; a new preset below even
/// this would be unreadable at any size.
const kMinLargeTextContrast = 3.0;

bool hasLowContrast(Color foreground, Color background) =>
    contrastRatio(foreground, background) < kMinReadableContrast;
