import 'dart:convert';
import 'dart:io';

import 'package:chanting/app.dart';
import 'package:chanting/data/local/prefs_service.dart';
import 'package:chanting/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The first [n] prayer ids of the shipped book, so the test follows the
/// data instead of naming prayers.
List<String> _firstIds(int n) {
  final raw = jsonDecode(
    File('assets/data/prayers-th.json').readAsStringSync(),
  );
  final list = (raw is List ? raw : raw['prayers']) as List;
  return [for (final p in list.take(n)) (p as Map)['id'] as String];
}

/// Lets a popup menu finish opening; it ignores taps until then.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<PrefsService> openSet(WidgetTester tester, List<String> ids) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'welcome_seen_version': 999,
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
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    appRouter.go('/playlists/p1');
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    return prefs;
  }

  List<String> storedIds(PrefsService prefs) {
    final raw = prefs.getPlaylistsRaw();
    if (raw.isEmpty) return const [];
    return ((jsonDecode(raw.single) as Map)['prayerIds'] as List)
        .cast<String>();
  }

  testWidgets('"จัดลำดับ" opens the edit page on the chosen prayers', (
    tester,
  ) async {
    final ids = _firstIds(3);
    await openSet(tester, ids);

    await tester.tap(find.byKey(const ValueKey('playlist_reorder_button')));
    await settle(tester);

    expect(find.text('กดค้างแล้วลากเพื่อจัดลำดับ'), findsOneWidget);
    expect(find.text('บทสวดที่เลือก (3)'), findsOneWidget);
  });

  testWidgets('shows the set with play-only rows', (tester) async {
    final ids = _firstIds(3);
    await openSet(tester, ids);

    expect(find.text('ชุดทดสอบ'), findsOneWidget);
    expect(find.text('เริ่มสวดทั้งชุด'), findsOneWidget);
    expect(find.text('รายการบทสวด (3)'), findsOneWidget);
    expect(find.byTooltip('เริ่มสวด'), findsNWidgets(3));
    // Reordering and removing live on the edit page; this page only links
    // to it, with no per-row controls of its own.
    expect(find.text('จัดลำดับ'), findsOneWidget);
    for (final id in ids) {
      expect(
        find.descendant(
          of: find.byKey(ValueKey(id)),
          matching: find.byTooltip('ตัวเลือก'),
        ),
        findsNothing,
      );
    }
  });

  testWidgets('edit page saves name, description, order and removals', (
    tester,
  ) async {
    final ids = _firstIds(3);
    final prefs = await openSet(tester, ids);

    await tester.tap(find.text('แก้ไข'));
    await settle(tester);
    await tester.enterText(
      find.byKey(const ValueKey('playlist_name_field')),
      'ชุดใหม่',
    );
    await tester.enterText(
      find.byKey(const ValueKey('playlist_description_field')),
      'คำอธิบายของชุด',
    );
    await tester.tap(find.byKey(const ValueKey('edit_tab_selected')));
    await tester.pump();

    // Drag the first prayer below the second, in steps: the first move is
    // eaten by touch slop.
    final gesture = await tester.startGesture(
      tester.getCenter(
        find.byKey(const ValueKey('selected_drag_handle')).first,
      ),
    );
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 12));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await gesture.up();
    await settle(tester);

    // Remove the last one.
    await tester.tap(
      find.descendant(
        of: find.byKey(ValueKey(ids[2])),
        matching: find.byTooltip('เอาออกจากชุด'),
      ),
    );
    await tester.pump();
    expect(find.text('บทสวดที่เลือก (2)'), findsOneWidget);
    // Still a draft.
    expect(storedIds(prefs), ids);

    await tester.tap(find.byKey(const ValueKey('playlist_save_button')));
    await settle(tester);

    expect(storedIds(prefs), [ids[1], ids[0]]);
    final stored = jsonDecode(prefs.getPlaylistsRaw().single) as Map;
    expect(stored['name'], 'ชุดใหม่');
    expect(stored['description'], 'คำอธิบายของชุด');
    // Back on the set page, which shows both.
    expect(find.text('ชุดใหม่'), findsOneWidget);
    expect(find.text('คำอธิบายของชุด'), findsOneWidget);
  });

  testWidgets('leaving the edit page with changes asks before discarding', (
    tester,
  ) async {
    final ids = _firstIds(1);
    final prefs = await openSet(tester, ids);

    await tester.tap(find.text('แก้ไข'));
    await settle(tester);
    await tester.enterText(
      find.byKey(const ValueKey('playlist_name_field')),
      'ไม่บันทึก',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('app_back_button')));
    await settle(tester);
    expect(find.text('ทิ้งการแก้ไข?'), findsOneWidget);

    await tester.tap(find.text('แก้ไขต่อ'));
    await settle(tester);
    expect(find.text('แก้ไขชุดสวด'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('app_back_button')));
    await settle(tester);
    await tester.tap(find.text('ทิ้ง'));
    await settle(tester);
    expect(find.text('รายละเอียดชุดสวด'), findsOneWidget);
    expect(
      (jsonDecode(prefs.getPlaylistsRaw().single) as Map)['name'],
      'ชุดทดสอบ',
    );
  });

  testWidgets('saving without a name is refused with a message', (
    tester,
  ) async {
    await openSet(tester, _firstIds(1));
    await tester.tap(find.text('แก้ไข'));
    await settle(tester);
    await tester.enterText(
      find.byKey(const ValueKey('playlist_name_field')),
      '  ',
    );
    await tester.tap(find.byKey(const ValueKey('playlist_save_button')));
    await tester.pump();
    expect(find.text('ตั้งชื่อชุดสวดก่อนบันทึก'), findsOneWidget);
    expect(find.text('แก้ไขชุดสวด'), findsOneWidget);
  });

  testWidgets('pin toggles its label, and delete leaves the page', (
    tester,
  ) async {
    final prefs = await openSet(tester, _firstIds(1));

    await tester.tap(find.text('ปักหมุด'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('ถอดหมุด'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byTooltip('ตัวเลือก'),
      ),
    );
    await settle(tester);
    await tester.tap(find.text('ลบชุด'));
    await settle(tester);
    expect(prefs.getPlaylistsRaw(), isEmpty);
    expect(find.text('ไม่พบชุดสวดนี้'), findsNothing);

    // "เลิกทำ" brings it back, still pinned.
    expect(find.text('ลบชุด “ชุดทดสอบ” แล้ว'), findsOneWidget);
    await tester.tap(find.text('เลิกทำ'));
    await settle(tester);
    expect(prefs.getPlaylistsRaw(), hasLength(1));
    expect(find.text('ชุดทดสอบ'), findsOneWidget);
    // The list no longer draws a pin mark, so read the pin where it lives.
    final id = (jsonDecode(prefs.getPlaylistsRaw().single) as Map)['id'];
    expect(prefs.getPinnedRaw(), contains('playlist:$id'));
  });

  testWidgets('list search filters the sets; sort orders them', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final ids = _firstIds(3);
    SharedPreferences.setMockInitialValues({
      'welcome_seen_version': 999,
      'playlists': [
        for (final (id, name, n) in [
          ('a', 'ชุดเช้า', 1),
          ('b', 'ชุดเย็น', 3),
          ('c', 'ก่อนนอน', 2),
        ])
          jsonEncode({
            'id': id,
            'name': name,
            'prayerIds': ids.take(n).toList(),
          }),
      ],
    });
    final prefs = await PrefsService.init();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [prefsServiceProvider.overrideWithValue(prefs)],
        child: const ChantingApp(),
      ),
    );
    await settle(tester);
    appRouter.go('/playlists');
    await settle(tester);

    List<String> order() {
      final cards = ['a', 'b', 'c']
          .where(
            (id) =>
                find.byKey(ValueKey('playlist_card_$id')).evaluate().isNotEmpty,
          )
          .toList();
      cards.sort(
        (x, y) => tester
            .getTopLeft(find.byKey(ValueKey('playlist_card_$x')))
            .dy
            .compareTo(
              tester.getTopLeft(find.byKey(ValueKey('playlist_card_$y'))).dy,
            ),
      );
      return cards;
    }

    expect(order(), ['a', 'b', 'c']);

    await tester.enterText(
      find.byKey(const ValueKey('playlists_search')),
      'ชุด',
    );
    await tester.pump();
    expect(order(), ['a', 'b']);
    // The match is marked in the name.
    var marked = false;
    for (final text in tester.widgetList<RichText>(
      find.descendant(
        of: find.byKey(const ValueKey('playlist_card_a')),
        matching: find.byType(RichText),
      ),
    )) {
      text.text.visitChildren((span) {
        if (span.style?.backgroundColor != null) marked = true;
        return true;
      });
    }
    expect(marked, isTrue);

    await tester.enterText(find.byKey(const ValueKey('playlists_search')), '');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('playlists_sort')));
    await settle(tester);
    await tester.tap(find.text('จำนวนบทมากที่สุด'));
    await settle(tester);
    expect(order(), ['b', 'c', 'a']);
    // Remembered as a view setting; the sets' own order is untouched.
    expect(prefs.getPlaylistsSort(), 'count');
    expect(
      [
        for (final raw in prefs.getPlaylistsRaw())
          (jsonDecode(raw) as Map)['id'],
      ],
      ['a', 'b', 'c'],
    );
  });

  testWidgets('list cards have no menu; deleting a set from its page undoes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final ids = _firstIds(1);
    SharedPreferences.setMockInitialValues({
      'welcome_seen_version': 999,
      'playlists': [
        for (final (id, name) in [('a', 'ชุดแรก'), ('b', 'ชุดสอง')])
          jsonEncode({
            'id': id,
            'name': name,
            'description': 'คำอธิบาย$name',
            'prayerIds': ids,
          }),
      ],
    });
    final prefs = await PrefsService.init();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [prefsServiceProvider.overrideWithValue(prefs)],
        child: const ChantingApp(),
      ),
    );
    await settle(tester);
    appRouter.go('/playlists');
    await settle(tester);

    expect(find.text('คำอธิบายชุดแรก'), findsOneWidget);
    expect(find.byKey(const ValueKey('app_back_button')), findsNothing);

    // The list only opens and plays; the options live on the set's page.
    expect(find.byTooltip('ตัวเลือก'), findsNothing);

    // Delete the first set from its page, then undo: it returns to the
    // first place.
    await tester.tap(find.text('ชุดแรก'));
    await settle(tester);
    await tester.tap(find.byTooltip('ตัวเลือก'));
    await settle(tester);
    await tester.tap(find.text('ลบชุด'));
    await settle(tester);
    expect(find.text('ชุดแรก'), findsNothing);
    await tester.tap(find.text('เลิกทำ'));
    await settle(tester);
    final names = [
      for (final raw in prefs.getPlaylistsRaw())
        (jsonDecode(raw) as Map)['name'],
    ];
    expect(names, ['ชุดแรก', 'ชุดสอง']);
  });

  testWidgets('each edit tab keeps its own scroll position', (tester) async {
    await openSet(tester, _firstIds(1));
    await tester.tap(find.text('แก้ไข'));
    await settle(tester);

    ScrollPosition page() => tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position;

    page().jumpTo(900);
    await tester.pump();
    final chooseOffset = page().pixels;
    expect(chooseOffset, greaterThan(0));

    // The chosen tab is short: it opens at its top, not at 900.
    await tester.tap(find.byKey(const ValueKey('edit_tab_selected')));
    await settle(tester);
    expect(page().pixels, lessThan(chooseOffset));

    await tester.tap(find.byKey(const ValueKey('edit_tab_choose')));
    await settle(tester);
    expect(page().pixels, chooseOffset);
  });
}
