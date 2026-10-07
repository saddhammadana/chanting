import 'package:flutter/widgets.dart';

/// Languages users can select in settings.
///
/// Adding a language means adding a value here and `lib/l10n/app_<code>.arb`.
/// `test/l10n_test.dart` keeps those in sync and requires every ARB key to be
/// translated.
///
/// `languageCode` must be a two-letter ISO 639-1 code matching Flutter's
/// `Locale.languageCode`; `eng` would not find the ARB file.
///
/// Bundled fonts cover only Latin and Thai scripts. Languages using other scripts
/// need additional bundled fonts; the app does not download fonts at runtime.
enum AppLocale {
  /// Follow the device language; Flutter falls back to the first supported
  /// locale, Thai, when the device locale is unsupported.
  system(null, null),
  th('th', 'ไทย'),
  en('en', 'English');

  const AppLocale(this.languageCode, this.endonym);

  /// Null means system locale.
  final String? languageCode;

  /// Language name in that language. This is an endonym, not translatable copy.
  ///
  /// Language choices must be readable by speakers of that language regardless of
  /// the current UI locale. Unlike "system", this can safely live in a const
  /// constructor because it does not depend on locale.
  final String? endonym;

  Locale? get locale {
    final code = languageCode;
    return code == null ? null : Locale(code);
  }

  /// SharedPreferences stores `name` (`system`/`th`/`en`), not visible labels.
  static AppLocale fromName(String? name) => values.firstWhere(
    (e) => e.name == name,
    // Default to Thai, not system. This is a Thai app with Thai-only content, so
    // English devices should not get English UI unless the user asks for it.
    orElse: () => AppLocale.th,
  );

  /// Locales the app actually supports; passed to `MaterialApp.supportedLocales`.
  static List<Locale> get supported =>
      values.map((e) => e.locale).whereType<Locale>().toList(growable: false);

  /// Concrete locale to use; resolves `system` into an actual supported locale.
  ///
  /// Needed by code without `BuildContext`, such as reminders_controller.dart.
  /// Widgets should use `AppLocalizations.of(context)` instead.
  ///
  /// Uses the same `basicLocaleListResolution` as `MaterialApp`, so results match
  /// what users see on screen.
  Locale resolve() =>
      locale ??
      basicLocaleListResolution(
        WidgetsBinding.instance.platformDispatcher.locales,
        supported,
      );
}
