import 'dart:convert';
import 'dart:io';

import 'package:chanting/app.dart';
import 'package:chanting/data/local/prefs_service.dart';
import 'package:chanting/data/models/playlist.dart';
import 'package:chanting/features/playlists/playlist_share.dart';
import 'package:chanting/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Every screen that can be opened on its own, and one way to open it.
///
/// Shared by the checks that have to cover the whole app rather than one
/// feature — `accessibility_test.dart` and `text_scaling_test.dart` — so a new
/// page joins both by being added here once.
///
/// **Adding a screen means adding its route here.** Nothing else notices a new
/// page, and an unchecked page is where the next too-small control or
/// overflowing row lands.
///
/// Screens that take an id read it from the shipped data or from the prayer set
/// [openScreen] seeds, so a content edit cannot break them.
typedef AppScreen = ({String path, Object? extra});

/// Id of the prayer set [openScreen] stores before opening a screen.
const seededSetId = 'p1';

List<dynamic> _decodeList(String path) {
  final raw = jsonDecode(File(path).readAsStringSync());
  return (raw is List ? raw : raw['prayers'] as List);
}

String _firstPrayerId() =>
    (_decodeList('assets/data/prayers-th.json').first as Map)['id'] as String;

String _firstSectionId() =>
    (_decodeList('assets/data/sections-th.json').first as Map)['id'] as String;

List<String> _seededSetIds() => [
  for (final p in _decodeList('assets/data/prayers-th.json').take(3))
    (p as Map)['id'] as String,
];

Map<String, AppScreen> appScreens() {
  final prayerId = _firstPrayerId();
  final sectionId = _firstSectionId();
  return {
    'home': (path: '/', extra: null),
    'all prayers': (path: '/all', extra: null),
    'service of the hour': (path: '/start', extra: null),
    'categories': (path: '/categories', extra: null),
    'category': (path: '/category/$sectionId', extra: null),
    'reading': (path: '/prayer/$prayerId', extra: null),
    'favorites': (path: '/favorites', extra: null),
    'prayer sets': (path: '/playlists', extra: null),
    'prayer set': (path: '/playlists/$seededSetId', extra: null),
    'new prayer set': (path: '/playlists/new', extra: null),
    'edit prayer set': (path: '/playlists/$seededSetId/edit', extra: null),
    'share prayer set': (path: '/playlists/$seededSetId/share', extra: null),
    'receive a set': (path: '/playlists/receive', extra: null),
    'paste a code': (path: '/playlists/paste', extra: null),
    'scan a code': (path: '/playlists/scan', extra: null),
    'preview a received set': (
      path: '/playlists/preview',
      extra: encodePlaylistShare(
        Playlist(
          id: 'incoming',
          name: 'ชุดที่ได้รับ',
          prayerIds: _seededSetIds(),
        ),
      ),
    ),
    'meditation': (path: '/meditation', extra: null),
    'settings hub': (path: '/settings', extra: null),
    'settings search': (path: '/settings/search', extra: null),
    'reading settings': (path: '/settings/reading', extra: null),
    'goal and reminders': (path: '/settings/goal', extra: null),
    'sound': (path: '/settings/sound', extra: null),
    'prayer updates': (path: '/settings/content', extra: null),
    'language': (path: '/settings/language', extra: null),
    'theme': (path: '/settings/theme', extra: null),
    'about': (path: '/about', extra: null),
    'legal': (path: '/legal', extra: null),
    'script': (path: '/script', extra: null),
  };
}

/// Opens [screen] on a phone-sized view with a stored prayer set.
///
/// The route is opened directly rather than tapped through, so a layout change
/// on the way to a screen cannot fail the check for the screen itself.
/// [textScale] renders it at the reader's chosen text size.
Future<void> openScreen(
  WidgetTester tester,
  AppScreen screen, {
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({
    'welcome_seen_version': 999,
    'goal_prompt_seen': true,
    // A stored set, so the set pages have something to render.
    'playlists': [
      jsonEncode({
        'id': seededSetId,
        'name': 'ชุดทดสอบ',
        'prayerIds': _seededSetIds(),
      }),
    ],
  });
  final prefsService = await PrefsService.init();
  const app = ChantingApp();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [prefsServiceProvider.overrideWithValue(prefsService)],
      child: textScale == 1
          ? app
          : MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
              child: app,
            ),
    ),
  );
  appRouter.go(screen.path, extra: screen.extra);
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
