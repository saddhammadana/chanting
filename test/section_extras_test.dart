import 'package:chanting/data/models/prayer.dart';
import 'package:chanting/features/prayer_list/prayer_list_controller.dart';
import 'package:chanting/features/prayer_list/section_extras_controller.dart';
import 'package:chanting/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test.dart'
    show pumpApp, pumpUntilFound, prayerTitle, tapCategoryMenu;

/// Prayer the test adds to morning chanting. It must be in **one category** and
/// that category must not be morning/evening chanting, because the picker opens
/// from both. The first `bot-thuapai` prayer fits; the old fixture was merged into
/// `pubba-bhaga-namakara`.
const _extraId = 'bucha-phra-rattanatrai';

/// User-added prayers for a category, supporting "add one more prayer after
/// morning chanting every day" **without forking the whole category**. The base
/// category remains shipped content and can still update normally.
void main() {
  setUp(() {
    rootBundle.evict('assets/data/prayers-th.json');
    rootBundle.evict('assets/data/sections-th.json');
    appRouter.go('/');
  });

  group('withExtras', () {
    Prayer p(String id) => Prayer(id: id, title: id, text: 't');
    final byId = {
      for (final id in ['a', 'b', 'x', 'y']) id: p(id),
    };

    test('extra prayers append in the order they were added', () {
      expect(withExtras([p('a'), p('b')], ['y', 'x'], byId).map((e) => e.id), [
        'a',
        'b',
        'y',
        'x',
      ]);
    });

    test('no extras returns the original prayer list', () {
      expect(withExtras([p('a')], null, byId).map((e) => e.id), ['a']);
      expect(withExtras([p('a')], const [], byId).map((e) => e.id), ['a']);
    });

    test(
      'missing extra ids are skipped when prayers were removed or unavailable in an edition',
      () {
        expect(
          withExtras([p('a')], ['ไม่มีจริง', 'x'], byId).map((e) => e.id),
          ['a', 'x'],
        );
      },
    );

    test(
      'extra ids already present in the category are skipped to avoid duplicates',
      () {
        expect(
          withExtras([p('a'), p('x')], ['x'], byId).map((e) => e.id),
          ['a', 'x'],
          reason: 'ผู้ใช้เติม x ไว้ แล้วต่อมาหมวดใส่ x เอง — ต้องเหลือใบเดียว',
        );
      },
    );
  });

  testWidgets(
    'added category prayers appear at the end with a user-added badge',
    (tester) async {
      await pumpApp(tester, openAll: false);
      await tester.tap(find.byKey(const ValueKey('home_morning')));
      await pumpUntilFound(tester, find.text('บทกราบพระรัตนตรัย'));
      await tester.pumpAndSettle();

      expect(find.text('เพิ่มเอง'), findsNothing);

      await tapCategoryMenu(tester, 'section_add_prayer');
      // Choose a prayer from another category; this one is in general prayers.
      await tester.tap(
        find.byKey(const ValueKey('pick_bot-thuapai_$_extraId')),
      );
      await tester.pumpAndSettle();

      expect(find.text('เพิ่มเอง'), findsOneWidget);
      expect(find.byKey(const ValueKey('card_$_extraId')), findsOneWidget);
    },
  );

  testWidgets('prayers already in the category are hidden from the add list', (
    tester,
  ) async {
    await pumpApp(tester, openAll: false);
    await tester.tap(find.byKey(const ValueKey('home_morning')));
    await pumpUntilFound(tester, find.text('บทกราบพระรัตนตรัย'));
    await tester.pumpAndSettle();

    await tapCategoryMenu(tester, 'section_add_prayer');

    // ratanattaya-vandana is already the first prayer in this category.
    expect(
      find.byKey(const ValueKey('pick_tham-wat-chao_ratanattaya-vandana')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('pick_bot-thuapai_$_extraId')),
      findsOneWidget,
    );
  });

  testWidgets('prayers in multiple categories appear only once in the add list', (
    tester,
  ) async {
    await pumpApp(tester, openAll: false);
    await tester.tap(find.byKey(const ValueKey('home_morning')));
    await pumpUntilFound(tester, find.text('บทกราบพระรัตนตรัย'));
    await tester.pumpAndSettle();

    // Add a general-prayer item to morning chanting; it now appears in two categories.
    await tapCategoryMenu(tester, 'section_add_prayer');
    await tester.tap(find.byKey(const ValueKey('pick_bot-thuapai_$_extraId')));
    await tester.pumpAndSettle();

    // Open the picker again from another category; that prayer must appear once.
    appRouter.go('/category/tham-wat-yen');
    await pumpUntilFound(tester, find.byKey(const ValueKey('category_menu')));
    await tester.pumpAndSettle();
    await tapCategoryMenu(tester, 'section_add_prayer');

    expect(
      find.text(prayerTitle(_extraId)),
      findsOneWidget,
      reason: 'กำลังเลือกบท ไม่ใช่คู่ (หมวด, บท) — ซ้ำจะดูเหมือนบั๊ก',
    );
  });

  testWidgets(
    'removing an extra prayer hides it from the category while shipped prayers remain fixed',
    (tester) async {
      await pumpApp(
        tester,
        openAll: false,
        extraPrefs: {
          'section_extras': <String>['tham-wat-chao:$_extraId'],
        },
      );
      await tester.tap(find.byKey(const ValueKey('home_morning')));
      await pumpUntilFound(tester, find.text('บทกราบพระรัตนตรัย'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('card_$_extraId')), findsOneWidget);
      // Items shipped with the category have no remove button.
      expect(
        find.byKey(const ValueKey('remove_extra_ratanattaya-vandana')),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey('remove_extra_$_extraId')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('card_$_extraId')), findsNothing);

      // The remove button sits where other rows have the ">" arrow, so mis-taps are
      // easy. Since it removes user settings, recovery must not require reselecting prayers.
      await tester.tap(find.text('เลิกทำ'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('card_$_extraId')),
        findsOneWidget,
        reason: 'add ต่อท้ายเสมอ และบทที่เติมก็แสดงต่อท้าย — ตำแหน่งเดิมเป๊ะ',
      );
    },
  );

  testWidgets(
    'continuous reading includes user-added category prayers consistently',
    (tester) async {
      await pumpApp(
        tester,
        openAll: false,
        extraPrefs: {
          'section_extras': <String>['tham-wat-chao:$_extraId'],
          'continuous_reading': true,
        },
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byKey(const ValueKey('home_scroll'))),
        listen: false,
      );
      final list = container
          .read(prayerListControllerProvider)
          .value!
          .firstWhere((e) => e.section.id == 'tham-wat-chao');
      expect(list.prayers.last.id, _extraId);
    },
  );
}
