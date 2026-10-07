import 'dart:async';

import 'package:flutter/foundation.dart'
    show LicenseEntryWithLineBreaks, LicenseRegistry, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/local/notification_service.dart';
import 'data/local/prefs_service.dart';
import 'features/settings/reminders_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Bundled OFL fonts; register their licenses for the system licenses page.
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'google_fonts',
    ], await rootBundle.loadString('assets/google_fonts/OFL_Sarabun.txt'));
    yield LicenseEntryWithLineBreaks([
      'google_fonts',
    ], await rootBundle.loadString('assets/google_fonts/OFL_Pridi.txt'));
  });
  final prefsService = await PrefsService.init();
  // Reschedule saved reminders without blocking app startup.
  unawaited(rescheduleRemindersOnStartup(prefsService, NotificationService()));
  runApp(
    ProviderScope(
      overrides: [prefsServiceProvider.overrideWithValue(prefsService)],
      child: const ChantingApp(splash: !kIsWeb),
    ),
  );
}
