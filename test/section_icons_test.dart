import 'dart:io';

import 'package:chanting/data/models/prayer_section.dart';
import 'package:chanting/data/repositories/prayer_repository.dart';
import 'package:chanting/features/prayer_list/section_icon_overrides.dart';
import 'package:chanting/features/prayer_list/section_icons.dart';
import 'package:chanting/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test.dart' show pumpApp, pumpUntilFound;

/// Section icons come from `sections-*.json`, not a Dart switch.
///
/// **Do not store codePoints and create `IconData` at runtime**. Release builds
/// fail icon tree-shaking with "It has non-constant instances of IconData".
/// Store **names** and map them to const values in [kSectionIcons].
void main() {
  setUp(() {
    rootBundle.evict('assets/data/prayers-th.json');
    rootBundle.evict('assets/data/sections-th.json');
    appRouter.go('/');
  });

  List<PrayerSection> sourceSections() => PrayerRepository.decodeSections(
    File('assets/data/sections-th.json').readAsStringSync(),
  );

  test(
    'every real category references an icon name available in the registry',
    () {
      for (final s in sourceSections()) {
        expect(
          kSectionIcons.keys,
          contains(s.icon),
          reason:
              'หมวด ${s.id} ใช้ไอคอน "${s.icon}" ซึ่งไม่มีในคลัง — '
              'จะร่วงไปไอคอนสำรองเงียบ ๆ',
        );
      }
    },
  );

  test('full section editions keep ids, icons, and prayer ids aligned', () {
    final source = {for (final s in sourceSections()) s.id: s};
    for (final lang in kContentLanguages) {
      if (lang == kDefaultContentLanguage) continue;
      final edition = PrayerRepository.decodeSections(
        File('assets/data/sections-$lang.json').readAsStringSync(),
      );
      expect(edition.map((s) => s.id).toSet(), source.keys.toSet());
      for (final s in edition) {
        final base = source[s.id]!;
        expect(s.icon, base.icon, reason: '${s.id}: icon drift in $lang');
        expect(
          s.prayerIds,
          base.prayerIds,
          reason: '${s.id}: prayerIds drift in $lang',
        );
      }
    }
  });

  test('icon registry includes a real fallback icon for sectionIcon', () {
    expect(kSectionIcons.keys, contains(kDefaultSectionIcon));
  });

  test('unknown and null icon names fall back without throwing', () {
    final fallback = kSectionIcons[kDefaultSectionIcon];
    expect(sectionIcon(null), fallback);
    expect(sectionIcon('ไอคอนจากอนาคต'), fallback);
    expect(sectionIcon('sunrise'), kSectionIcons['sunrise']);
  });

  test('icon writes to JSON only when set and round-trips correctly', () {
    const withIcon = PrayerSection(
      id: 'a',
      title: 't',
      prayerIds: ['x'],
      icon: 'lotus',
    );
    expect(withIcon.toJson()['icon'], 'lotus');
    expect(PrayerSection.fromJson(withIcon.toJson()).icon, 'lotus');

    const noIcon = PrayerSection(id: 'a', title: 't', prayerIds: ['x']);
    expect(noIcon.toJson().containsKey('icon'), isFalse);
    expect(PrayerSection.fromJson(noIcon.toJson()).icon, isNull);
  });

  testWidgets('home page uses icons from data instead of hardcoded values', (
    tester,
  ) async {
    await pumpApp(tester, openAll: false);
    // Morning chanting is pinned by default, and the file sets icon to sunrise.
    expect(sourceSections().first.icon, 'sunrise');
    expect(find.byIcon(kSectionIcons['sunrise']!), findsOneWidget);
  });

  testWidgets('all categories page shows each category icon', (tester) async {
    await pumpApp(tester, openAll: false);
    await tester.tap(find.byKey(const ValueKey('home_all_categories')));
    await tester.pumpAndSettle();
    await pumpUntilFound(tester, find.text('บทธรรมคำสอน'));

    // school is the icon for the dhamma-teachings section in the file.
    expect(find.byIcon(kSectionIcons['school']!), findsOneWidget);
  });

  test('reset-to-source sentinel does not collide with a real icon name', () {
    expect(kSectionIcons.keys, isNot(contains(kResetSectionIcon)));
  });

  testWidgets(
    'user category icon override appears on both all-categories and home pages',
    (tester) async {
      await pumpApp(tester, openAll: false);
      // Morning chanting is pinned by default, and the file sets sunrise.
      expect(find.byIcon(kSectionIcons['sunrise']!), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('home_all_categories')));
      await tester.pumpAndSettle();
      // Icon changes now live in the row menu, not the leading icon button. The
      // leading icon is only a label, so tapping the row only opens the category.
      await tester.tap(
        find.byKey(const ValueKey('category_menu_tham-wat-chao')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('section_icon_tham-wat-chao')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('icon_choice_lotus')));
      await tester.pumpAndSettle();

      // Every category page uses the new icon.
      expect(find.byIcon(kSectionIcons['lotus']!), findsOneWidget);

      appRouter.go('/');
      await pumpUntilFound(
        tester,
        find.byKey(const ValueKey('home_practice_hero')),
      );
      await tester.pumpAndSettle();
      // The pinned home tile follows the change too.
      expect(find.byIcon(kSectionIcons['lotus']!), findsOneWidget);
      expect(find.byIcon(kSectionIcons['sunrise']!), findsNothing);
    },
  );

  testWidgets(
    'reset icon action removes the override instead of writing the current icon',
    (tester) async {
      await pumpApp(
        tester,
        openAll: false,
        extraPrefs: {
          'section_icons': <String>['tham-wat-chao:lotus'],
        },
      );
      expect(find.byIcon(kSectionIcons['lotus']!), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('home_all_categories')));
      await tester.pumpAndSettle();
      // Icon changes now live in the row menu, not the leading icon button. The
      // leading icon is only a label, so tapping the row only opens the category.
      await tester.tap(
        find.byKey(const ValueKey('category_menu_tham-wat-chao')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('section_icon_tham-wat-chao')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('icon_reset')));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.text('ทำวัตรเช้า').first),
        listen: false,
      );
      expect(
        container.read(sectionIconOverridesProvider),
        isEmpty,
        reason: 'ต้องลบคีย์ทิ้ง หมวดจะได้รับไอคอนใหม่ถ้าฉบับหน้าเปลี่ยน',
      );
      expect(find.byIcon(kSectionIcons['sunrise']!), findsOneWidget);
    },
  );

  testWidgets('unknown override icon falls back to the shipped value', (
    tester,
  ) async {
    await pumpApp(
      tester,
      openAll: false,
      extraPrefs: {
        'section_icons': <String>['tham-wat-chao:ไอคอนจากอนาคต'],
      },
    );
    expect(find.byIcon(kSectionIcons['sunrise']!), findsOneWidget);
  });
}
