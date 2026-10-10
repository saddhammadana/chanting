import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart'
    show LicenseEntryWithLineBreaks, LicenseRegistry, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/local/content_store.dart';
import 'data/local/notification_service.dart';
import 'data/local/prefs_service.dart';
import 'features/content_update/content_update_controller.dart';
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
  final container = ProviderContainer(
    overrides: [
      prefsServiceProvider.overrideWithValue(prefsService),
      contentStoreProvider.overrideWithValue(
        await openContentStore(bundledVersion: await _bundledRelease()),
      ),
    ],
  );
  // Look for a newer prayer book without blocking startup. Whatever it finds
  // is read from the next launch; see docs/architecture/content-updates.md.
  unawaited(
    container.read(contentUpdateControllerProvider.notifier).checkOnStartup(),
  );
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const ChantingApp(splash: !kIsWeb),
    ),
  );
}

/// The release the bundled prayer files were cut from, or 0 when unknown.
Future<int> _bundledRelease() async {
  try {
    final stamp =
        jsonDecode(await rootBundle.loadString('assets/data/release.json'))
            as Map<String, dynamic>;
    return stamp['version'] as int;
  } catch (_) {
    return 0;
  }
}
