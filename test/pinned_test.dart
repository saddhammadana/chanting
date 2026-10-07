import 'package:chanting/data/models/pinned_ref.dart';
import 'package:chanting/features/playlists/playlists_controller.dart';
import 'package:chanting/features/prayer_list/prayer_list_controller.dart';
import 'package:chanting/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test.dart' show pumpApp, pumpUntilFound, tapCategoryMenu;

/// Home-screen pins: users choose which categories, playlists, or prayers appear.
///
/// The home screen no longer shows every category as its own tile. That layout
/// became too dense on mobile once fixed tiles were added. Unpinned categories live
/// behind the Home "view all" action.
Future<void> _openAllCategories(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('home_all_categories')));
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    rootBundle.evict('assets/data/prayers-th.json');
    rootBundle.evict('assets/data/sections-th.json');
    appRouter.go('/');
  });

  group('PinnedRef', () {
    test('round-trips encode and parse for every type', () {
      for (final type in PinnedType.values) {
        final pin = PinnedRef(type, 'some-id');
        expect(PinnedRef.tryParse(pin.encode()), pin);
      }
    });

    test('keeps colons inside ids intact', () {
      // No current id has this shape, but the parser should preserve it if one ever does.
      const pin = PinnedRef(PinnedType.prayer, 'a:b:c');
      expect(PinnedRef.tryParse(pin.encode()), pin);
    });

    test('returns null for malformed strings from future prefs', () {
      for (final bad in [
        '',
        'no-colon',
        ':missing-type',
        'section:',
        'unknown:x',
      ]) {
        expect(PinnedRef.tryParse(bad), isNull, reason: 'input: "$bad"');
      }
    });
  });

  testWidgets('migrated users get default morning and evening pins', (
    tester,
  ) async {
    // Missing `pinned` means the user has just updated from an older version.
    await pumpApp(tester, openAll: false);

    expect(find.byKey(const ValueKey('home_morning')), findsOneWidget);
    expect(find.byKey(const ValueKey('home_evening')), findsOneWidget);
    // Unpinned categories are not standalone tiles; they are behind "all categories".
    expect(find.text('บทธรรมคำสอน'), findsNothing);
    expect(find.text('ดูทั้งหมด'), findsOneWidget);
  });

  testWidgets('an explicit empty pin list does not restore default pins', (
    tester,
  ) async {
    // `[]` differs from a missing key: the user deliberately removed every pin.
    await pumpApp(tester, openAll: false, extraPrefs: {'pinned': <String>[]});

    expect(find.byKey(const ValueKey('home_morning')), findsNothing);
    expect(find.text('ดูทั้งหมด'), findsOneWidget);
  });

  testWidgets('pins pointing to missing targets are skipped silently', (
    tester,
  ) async {
    await pumpApp(
      tester,
      openAll: false,
      extraPrefs: {
        'pinned': <String>[
          'section:tham-wat-chao',
          'section:deleted-section',
          'playlist:deleted-playlist',
          'prayer:missing-prayer',
        ],
      },
    );

    expect(find.byKey(const ValueKey('home_morning')), findsOneWidget);
    expect(find.textContaining('deleted'), findsNothing);
    expect(find.textContaining('missing'), findsNothing);
  });

  testWidgets('a pinned prayer appears as a home shortcut', (tester) async {
    await pumpApp(
      tester,
      openAll: false,
      extraPrefs: {
        'pinned': <String>['prayer:ratanattaya-vandana'],
      },
    );

    expect(find.text('บทกราบพระรัตนตรัย'), findsOneWidget);
    await tester.tap(find.text('บทกราบพระรัตนตรัย'));
    await pumpUntilFound(tester, find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
  });

  testWidgets('pinning a category from all categories shows it on home', (
    tester,
  ) async {
    await pumpApp(tester, openAll: false, extraPrefs: {'pinned': <String>[]});
    expect(find.text('บทธรรมคำสอน'), findsNothing);

    await _openAllCategories(tester);
    await pumpUntilFound(tester, find.text('บทธรรมคำสอน'));
    // Wait for the transition; during the slide-in the app-bar button is off-screen.
    await tester.pumpAndSettle();

    // The pin command lives in the row menu to keep row tap targets unambiguous.
    await tester.tap(
      find.byKey(const ValueKey('category_menu_bot-tham-khamson')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('pin_section_bot-tham-khamson')),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Back on home, the category tile should already be present.
    appRouter.go('/');
    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey('home_practice_hero')),
    );
    await tester.pumpAndSettle();
    expect(find.text('บทธรรมคำสอน'), findsOneWidget);
  });

  testWidgets('home exposes a single view-all action for categories', (
    tester,
  ) async {
    await pumpApp(tester, openAll: false);
    expect(find.byKey(const ValueKey('home_all_categories')), findsOneWidget);
    expect(find.text('ดูทั้งหมด'), findsOneWidget);
  });

  testWidgets('the all-categories home tile opens the complete category list', (
    tester,
  ) async {
    await pumpApp(tester, openAll: false, extraPrefs: {'pinned': <String>[]});
    await _openAllCategories(tester);
    // The list includes both pinned and unpinned categories.
    expect(find.text('ทำวัตรเช้า'), findsOneWidget);
    expect(find.text('บทธรรมคำสอน'), findsOneWidget);
  });

  testWidgets('creating a playlist from a category leaves the source unchanged', (
    tester,
  ) async {
    await pumpApp(tester, openAll: false);

    await tester.tap(find.byKey(const ValueKey('home_morning')));
    await pumpUntilFound(tester, find.text('บทกราบพระรัตนตรัย'));
    await tester.pumpAndSettle();

    await tapCategoryMenu(tester, 'category_to_playlist');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('สร้างชุดสวด'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.text('บทกราบพระรัตนตรัย').first),
      listen: false,
    );
    final created = container.read(playlistsControllerProvider).single;
    expect(created.name, 'ทำวัตรเช้า');
    expect(created.prayerIds.first, 'ratanattaya-vandana');
    // The category file check below covers exact membership; this only prevents an empty copy.
    expect(created.prayerIds, isNotEmpty);

    // The shipped category stays untouched so future content updates still apply.
    final section =
        (await container.read(prayerRepositoryProvider).getSections())
            .firstWhere((s) => s.id == 'tham-wat-chao');
    expect(section.prayerIds, created.prayerIds);
  });

  testWidgets('duplicate category-to-playlist names get a numeric suffix', (
    tester,
  ) async {
    await pumpApp(tester, openAll: false);
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byKey(const ValueKey('home_morning')));
      await pumpUntilFound(tester, find.text('บทกราบพระรัตนตรัย'));
      await tester.pumpAndSettle();
      await tapCategoryMenu(tester, 'category_to_playlist');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      appRouter.go('/');
      await pumpUntilFound(
        tester,
        find.byKey(const ValueKey('home_practice_hero')),
      );
      await tester.pumpAndSettle();
    }
    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('home_practice_hero'))),
      listen: false,
    );
    expect(container.read(playlistsControllerProvider).map((p) => p.name), [
      'ทำวัตรเช้า',
      'ทำวัตรเช้า (2)',
    ]);
  });

  testWidgets('unpinning from a category screen removes it from home', (
    tester,
  ) async {
    await pumpApp(
      tester,
      openAll: false,
      extraPrefs: {
        'pinned': <String>['section:tham-wat-chao'],
      },
    );
    expect(find.byKey(const ValueKey('home_morning')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home_morning')));
    await pumpUntilFound(tester, find.text('บทกราบพระรัตนตรัย'));
    // Wait for the transition; during slide-in the app-bar button is off-screen.
    await tester.pumpAndSettle();
    // The category is currently pinned, so tapping the app-bar pin removes it.
    await tester.tap(find.byKey(const ValueKey('pin_section_appbar')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    appRouter.go('/');
    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey('home_practice_hero')),
    );
    // Wait for the outgoing category screen to leave the tree.
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home_morning')), findsNothing);
  });
}
