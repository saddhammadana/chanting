import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/prayer_list/prayer_list_controller.dart';
import 'features/settings/settings_controller.dart';
import 'l10n/app_locale.dart';
import 'l10n/app_localizations.dart';
import 'router/app_router.dart';
import 'shared/widgets/startup_splash.dart';
import 'theme/app_theme.dart';

/// The root widget: theme, locale, and the router, all driven by settings.
class ChantingApp extends ConsumerWidget {
  const ChantingApp({super.key, this.splash = false});

  /// Covers the app with the lotus loader while it starts. Only `main` asks
  /// for it: on the web `index.html` already draws the same splash before
  /// Flutter boots, and a widget test has no start-up to cover.
  final bool splash;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(
      settingsControllerProvider.select((s) => s.themeMode),
    );
    final appLocale = ref.watch(
      settingsControllerProvider.select((s) => s.locale),
    );

    // Riverpod 3 pauses subscriptions for widgets covered by another route. The
    // prayer list under settings would miss locale changes, then invalidate
    // during the return-frame build and crash with "setState() called during
    // build". The root widget is never covered, so keep these home-content
    // providers listened to here and let them rebuild as soon as locale changes.
    ref.listen(prayerListControllerProvider, (_, _) {});
    ref.listen(filteredPrayersProvider, (_, _) {});
    ref.listen(lastReadPrayerProvider, (_, _) {});

    return MaterialApp.router(
      // Use onGenerateTitle rather than title so the OS-visible app name, such as
      // in the task switcher, follows localization. `title` is const and cannot
      // read l10n.
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      // Without an explicit locale, Flutter may run as en_US and built-in
      // Material widgets such as the reminder time picker show English
      // Cancel/OK/AM/PM inside the Thai app; see test/locale_test.dart.
      //
      // `locale` is null when users select "system"; Flutter then chooses from
      // supportedLocales using the device locale and falls back to the first
      // supported locale, Thai, when unsupported.
      locale: appLocale.locale,
      supportedLocales: AppLocale.supported,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Thai writes time on a 24-hour clock. Flutter's own `th` localization
      // has a 12-hour pattern and renders 06:00 as "AM 6:00" — the marker
      // first, in Latin letters — which is not a form any Thai reader expects,
      // and the app's artwork says "06:00 น.". So the device's 12-hour setting
      // is overridden for Thai only; English keeps whatever the device says.
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        final page = Localizations.localeOf(context).languageCode != 'th'
            ? child
            : MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(alwaysUse24HourFormat: true),
                child: child,
              );
        return splash ? StartupSplash(child: page) : page;
      },
      routerConfig: appRouter,
    );
  }
}
