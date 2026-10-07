import 'dart:convert';
import 'dart:io';

import 'package:chanting/app.dart';
import 'package:chanting/data/local/prefs_service.dart';
import 'package:chanting/features/playlists/playlist_edit_screen.dart';
import 'package:chanting/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Every prayer in the shipped book as (id, title), so the test follows the
/// data instead of naming prayers.
List<({String id, String title})> _prayers() {
  final raw = jsonDecode(
    File('assets/data/prayers-th.json').readAsStringSync(),
  );
  final list = (raw is List ? raw : raw['prayers']) as List;
  return [
    for (final p in list.cast<Map<String, dynamic>>())
      (id: p['id'] as String, title: p['title'] as String),
  ];
}

Future<void> _settle(WidgetTester tester, [int frames = 10]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Drags the page up by [distance] in steps; the first move is eaten by
/// touch slop.
Future<void> _scrollUp(WidgetTester tester, double distance) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.byType(CustomScrollView)),
  );
  const steps = 20;
  for (var i = 0; i < steps; i++) {
    await gesture.moveBy(Offset(0, -distance / steps));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  await _settle(tester);
}

/// The fill a row paints behind itself.
Color? _rowFill(WidgetTester tester, String id) {
  final box = tester.widget<DecoratedBox>(
    find
        .descendant(
          of: find.byKey(ValueKey('choose_$id')),
          matching: find.byType(DecoratedBox),
        )
        .first,
  );
  return (box.decoration as BoxDecoration).color;
}

/// Whether any span of the row's title is painted on a highlight.
bool _titleMarked(WidgetTester tester, String id) {
  var marked = false;
  for (final text in tester.widgetList<RichText>(
    find.descendant(
      of: find.byKey(ValueKey('choose_$id')),
      matching: find.byType(RichText),
    ),
  )) {
    text.text.visitChildren((span) {
      if (span.style?.backgroundColor != null) marked = true;
      return true;
    });
  }
  return marked;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() => appRouter.go('/'));

  /// Opens the edit page on a phone-sized view, so the lists scroll.
  Future<void> openEditor(
    WidgetTester tester, {
    List<String> ids = const [],
  }) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'welcome_seen_version': 999,
      'goal_prompt_seen': true,
      if (ids.isNotEmpty)
        'playlists': [
          jsonEncode({'id': 'p1', 'name': 'ชุดทดสอบ', 'prayerIds': ids}),
        ],
    });
    final prefs = await PrefsService.init();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [prefsServiceProvider.overrideWithValue(prefs)],
        child: const ChantingApp(),
      ),
    );
    await _settle(tester, 30);
    appRouter.go(ids.isEmpty ? '/playlists/new' : '/playlists/p1/edit');
    await _settle(tester, 20);
  }

  testWidgets('the header stays put while the list scrolls under it', (
    tester,
  ) async {
    await openEditor(tester);
    final title = find.text('สร้างชุดสวด');
    final before = tester.getTopLeft(title);

    await _scrollUp(tester, 600);

    expect(title, findsOneWidget);
    expect(tester.getTopLeft(title), before);
  });

  testWidgets('a chosen prayer is washed in gold, and unwashed when removed', (
    tester,
  ) async {
    await openEditor(tester);
    final id = _prayers().first.id;
    final plain = _rowFill(tester, id);

    await tester.tap(
      find.descendant(
        of: find.byKey(ValueKey('choose_$id')),
        matching: find.byTooltip('เพิ่มเข้าชุด'),
      ),
    );
    await tester.pump();
    expect(_rowFill(tester, id), isNot(plain));

    await tester.tap(
      find.descendant(
        of: find.byKey(ValueKey('choose_$id')),
        matching: find.byTooltip('เอาออกจากชุด'),
      ),
    );
    await tester.pump();
    expect(_rowFill(tester, id), plain);
  });

  testWidgets('the "added" message belongs to the editor, not the app', (
    tester,
  ) async {
    // In the app-wide messenger it outlived the page and showed over the
    // list the editor popped back to.
    await openEditor(tester);
    final id = _prayers().first.id;
    await tester.tap(
      find.descendant(
        of: find.byKey(ValueKey('choose_$id')),
        matching: find.byTooltip('เพิ่มเข้าชุด'),
      ),
    );
    await _settle(tester, 3);

    final snack = find.widgetWithText(SnackBar, 'เพิ่มบทสวดแล้ว');
    expect(snack, findsOneWidget);
    final editor = tester.element(find.byType(PlaylistEditScreen));
    expect(
      ScaffoldMessenger.of(tester.element(snack)),
      isNot(same(ScaffoldMessenger.of(editor))),
    );
    await _settle(tester, 20);

    // Taking it out again says so too.
    await tester.tap(
      find.descendant(
        of: find.byKey(ValueKey('choose_$id')),
        matching: find.byTooltip('เอาออกจากชุด'),
      ),
    );
    await _settle(tester, 3);
    expect(find.widgetWithText(SnackBar, 'เอาบทสวดออกแล้ว'), findsOneWidget);
    await _settle(tester, 20);
  });

  testWidgets('search marks the match in the title and clears with ✕', (
    tester,
  ) async {
    await openEditor(tester);
    final prayer = _prayers().first;
    final query = prayer.title.substring(0, prayer.title.length.clamp(0, 4));

    expect(
      find.byKey(const ValueKey('playlist_edit_search_clear')),
      findsNothing,
    );
    await tester.enterText(
      find.byKey(const ValueKey('playlist_edit_search')),
      query,
    );
    await tester.pump();
    expect(_titleMarked(tester, prayer.id), isTrue);

    await tester.tap(find.byKey(const ValueKey('playlist_edit_search_clear')));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('playlist_edit_search')))
          .controller!
          .text,
      isEmpty,
    );
    expect(_titleMarked(tester, prayer.id), isFalse);
    expect(
      find.byKey(const ValueKey('playlist_edit_search_clear')),
      findsNothing,
    );
  });

  testWidgets('a tab opened for the first time starts below the pinned tabs', (
    tester,
  ) async {
    // Long enough that the selected tab scrolls on its own, so the offset it
    // opens at is not simply clamped to the end.
    final ids = [for (final p in _prayers().take(30)) p.id];
    await openEditor(tester, ids: ids);

    await _scrollUp(tester, 1200);
    await tester.tap(find.byKey(const ValueKey('edit_tab_selected')));
    await _settle(tester, 3);

    final tabsBottom = tester
        .getBottomLeft(find.byKey(const ValueKey('edit_tab_choose')))
        .dy;
    final hint = find.text('กดค้างแล้วลากเพื่อจัดลำดับ');
    expect(hint, findsOneWidget);
    expect(tester.getTopLeft(hint).dy, greaterThanOrEqualTo(tabsBottom));
  });
}
