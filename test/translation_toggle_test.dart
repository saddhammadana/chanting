import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:chanting/app.dart';
import 'package:chanting/data/local/prefs_service.dart';
import 'package:chanting/data/models/playlist.dart';
import 'package:chanting/data/repositories/prayer_repository.dart';
import 'package:chanting/features/prayer_detail/widgets/prayer_content.dart';
import 'package:chanting/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Serve a fake prayers-th.json instead of the real asset for incomplete-data cases.
///
/// The real asset now has Pali/translations for all 19 prayers, so no prayer can
/// represent "missing Pali". The white-screen bug this guards can return as soon
/// as a new incomplete prayer is added, so keep the case and stop depending on a
/// gap in real data. PrayerRepository is concrete and has no interface to stub
/// under CLAUDE.md rules, so intercept at the asset layer instead.
void mockPrayersAsset(List<Map<String, dynamic>> prayers) {
  final fake = Uint8List.fromList(utf8.encode(jsonEncode(prayers)));
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMessageHandler('flutter/assets', (ByteData? message) async {
    final key = utf8.decode(message!.buffer.asUint8List());
    if (key == 'assets/data/prayers-th.json') return ByteData.view(fake.buffer);
    // Forward other assets (fonts/icons) to the real bundle. Read synchronously
    // because real I/O does not complete under tester.pump()'s FakeAsync.
    final file = File(key);
    if (!file.existsSync()) return null;
    return ByteData.view(Uint8List.fromList(file.readAsBytesSync()).buffer);
  });
  addTearDown(() {
    messenger.setMockMessageHandler('flutter/assets', null);
    rootBundle.evict('assets/data/prayers-th.json');
  });
  rootBundle.evict('assets/data/prayers-th.json');
}

/// Prayer for the fake asset: specify only fields the case cares about.
Map<String, dynamic> fakePrayer({
  required String id,
  required String title,
  required int order,
  String category = 'หมวดทดสอบ',
  String? text,
  String? paliText,
  String? meaning,
}) => {
  'id': id,
  'title': title,
  'category': category,
  // Default to **one block** with no blank line; cases that care about block
  // counting (`PrayerContent.blocks`) must pass [text] explicitly.
  'text': text ?? 'เนื้อบท$id บรรทัดหนึ่ง\nเนื้อบท$id บรรทัดสอง',
  'paliText': paliText,
  'meaning': meaning,
  'order': order,
};

/// Pump until the finder appears to tolerate async asset loading timing.
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxTries = 50,
}) async {
  for (var i = 0; i < maxTries; i++) {
    if (tester.any(finder)) return;
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsWidgets);
}

/// Open the reading page directly for this prayer and wait until chips are tappable.
/// Set the route before pumpWidget: appRouter is global, so pumping first can leave
/// the old page in place and let the finder hit stale widgets before navigation.
Future<void> openPrayer(
  WidgetTester tester,
  String path, {
  required bool continuousReading,
  List<String> playlists = const [],
  bool? inlineTranslation,
}) async {
  rootBundle.evict('assets/data/prayers-th.json');
  SharedPreferences.setMockInitialValues({
    'continuous_reading': continuousReading,
    'welcome_seen_version': 999,
    'inline_translation': ?inlineTranslation,
    if (playlists.isNotEmpty) 'playlists': playlists,
  });
  final prefsService = await PrefsService.init();
  appRouter.go(path);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [prefsServiceProvider.overrideWithValue(prefsService)],
      child: const ChantingApp(),
    ),
  );
  await pumpUntilFound(tester, find.byType(FilterChip));
  await tester.pump(const Duration(seconds: 1));
}

/// Tapping a chip must not throw. Continuous mode shows global chips when any
/// prayer has Pali/translation, then passes the same flag to every prayer; prayers
/// without that data used to crash the whole page. Scope to the chip because card
/// headers use the exact same translation label.
Future<void> tapChipExpectNoCrash(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(FilterChip), matching: find.text(label)),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  expect(
    tester.takeException(),
    isNull,
    reason: 'กดชิป "$label" แล้วไม่ควร throw',
  );
}

Future<void> main() async {
  // Read real data during collection to create one test per category. New
  // incomplete prayers are then caught without editing this test. Separate tests
  // give each category a clean tree; repeated pumpWidget calls in one test
  // collide with the global appRouter.
  TestWidgetsFlutterBinding.ensureInitialized();
  final grouped = await PrayerRepository().getPrayersByCategory();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    // rootBundle cache is tied to the previous test's FakeAsync zone.
    rootBundle.evict('assets/data/prayers-th.json');
    appRouter.go('/');
  });

  for (final entry in grouped.entries) {
    final category = entry.key;
    final prayers = entry.value;
    final anyPali = prayers.any((p) => p.paliText != null);
    final anyMeaning = prayers.any((p) => p.meaning != null);
    if (!anyPali && !anyMeaning) continue; // No chips to tap.

    testWidgets(
      'continuous mode category $category can show Pali and translations without crashing',
      (WidgetTester tester) async {
        // Very tall screen so every prayer in the category fits without scrolling.
        tester.view.physicalSize = const Size(800, 6000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await openPrayer(
          tester,
          '/prayer/${prayers.first.id}',
          continuousReading: true,
        );

        // Open each chip so both Pali and translation cards are covered.
        if (anyPali) await tapChipExpectNoCrash(tester, 'บาลี');
        if (anyMeaning) await tapChipExpectNoCrash(tester, 'คำแปล');

        // Also switch to inline mode; non-inlineable prayers fall back to end
        // cards, which is the path that used to fail.
        final swapChip = find.text('แทรกใต้บรรทัด');
        if (tester.any(swapChip)) {
          await tester.tap(swapChip.first);
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
          expect(
            tester.takeException(),
            isNull,
            reason: 'สลับแทรกใต้บรรทัดแล้วไม่ควร throw',
          );
        }

        // Every prayer in the category should still be visible, not a white screen.
        for (final p in prayers) {
          expect(
            find.text(p.title),
            findsWidgets,
            reason: 'บท "${p.title}" ควรยังแสดงอยู่หลังเปิดบาลี/คำแปล',
          );
        }
      },
    );
  }

  testWidgets(
    'mixed playlist with and without Pali or translations survives enabling chips',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // User case: a playlist can mix prayers across categories; one has
      // Pali/translation and another has neither. Global chips show if any prayer
      // has data, then send the flag to all prayers.
      mockPrayersAsset([
        fakePrayer(
          id: 'มีครบ',
          title: 'บทมีบาลีและคำแปล',
          order: 1,
          paliText: 'Pali line one\nPali line two',
          meaning: 'คำแปลบรรทัดหนึ่ง\nคำแปลบรรทัดสอง',
        ),
        fakePrayer(id: 'ไม่มีเลย', title: 'บทไม่มีบาลีไม่มีคำแปล', order: 2),
      ]);

      await openPrayer(
        tester,
        '/prayer/มีครบ?pl=pl1',
        continuousReading: true,
        // Playlists are stored as a StringList, one JSON per playlist, not one array.
        playlists: [
          const Playlist(
            id: 'pl1',
            name: 'ชุดคละ',
            prayerIds: ['มีครบ', 'ไม่มีเลย'],
          ).toJsonString(),
        ],
      );

      await tapChipExpectNoCrash(tester, 'บาลี');
      await tapChipExpectNoCrash(tester, 'คำแปล');

      // Both prayers remain; the one without Pali/translation skips cards only.
      expect(find.text('บทมีบาลีและคำแปล'), findsWidgets);
      expect(find.text('บทไม่มีบาลีไม่มีคำแปล'), findsWidgets);
    },
  );

  testWidgets('paged mode displays prayers without Pali normally', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // This mode already checks chips per prayer and does not carry state across
    // prayers, so it never crashed. Pin that behavior against future regressions.
    mockPrayersAsset([
      fakePrayer(
        id: 'มีแต่คำแปล',
        title: 'บทมีคำแปลแต่ไม่มีบาลี',
        order: 1,
        meaning: 'คำแปลบรรทัดหนึ่ง\nคำแปลบรรทัดสอง',
      ),
    ]);

    await openPrayer(tester, '/prayer/มีแต่คำแปล', continuousReading: false);

    // No Pali chip for this prayer, but it does have a translation.
    expect(
      find.descendant(of: find.byType(FilterChip), matching: find.text('บาลี')),
      findsNothing,
    );
    await tapChipExpectNoCrash(tester, 'คำแปล');
    expect(find.text('บทมีคำแปลแต่ไม่มีบาลี'), findsWidgets);
  });

  testWidgets('edition where Pali is main text does not show an extra Pali chip', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Simulate an "English edition" prayer: text = romanized Pali. Pali is the
    // main chant content, so the extra Pali chip must disappear instead of
    // duplicating the main content. Multi-language behavior depends on hasDistinctPali.
    const pali =
        'Arahaṃ sammāsambuddho bhagavā\nBuddhaṃ bhagavantaṃ abhivādemi';
    mockPrayersAsset([
      {
        'id': 'en-style',
        'title': 'Homage to the Triple Gem',
        'category': 'Morning Chanting',
        'text': pali, // Equals paliText, so hasDistinctPali is false.
        'paliText': pali,
        'paliVerified': false,
        'meaning': 'By this act of homage…',
        'order': 1,
      },
    ]);

    await openPrayer(tester, '/prayer/en-style', continuousReading: false);

    // Pali must be shown as the main content.
    expect(find.textContaining('Arahaṃ'), findsWidgets);
    // But there must be no extra Pali chip, which would duplicate the content.
    expect(
      find.descendant(of: find.byType(FilterChip), matching: find.text('บาลี')),
      findsNothing,
    );
    // Translation still has the normal chip.
    await tapChipExpectNoCrash(tester, 'คำแปล');
  });

  testWidgets('position chip is disabled when inline translation is unavailable', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // This used to use a real prayer (`phae-metta` when its translation was a
    // one-paragraph summary), but the data was reorganized and now no real prayer
    // is non-inlineable. Keep the case because a new prayer can hit it tomorrow;
    // serve a fake asset for the same reason [mockPrayersAsset] exists.
    mockPrayersAsset([
      fakePrayer(
        id: 'sarup-block',
        title: 'บทที่คำแปลเป็นบทสรุป',
        order: 1,
        // Two blocks separated by a blank line.
        text:
            'ท่อนหนึ่ง บรรทัดหนึ่ง\nท่อนหนึ่ง บรรทัดสอง\n\nท่อนสอง บรรทัดหนึ่ง',
        // One block, so it cannot align with the two content blocks.
        meaning: 'คำแปลสรุปทั้งบทเป็นย่อหน้าเดียว',
      ),
    ]);

    await openPrayer(tester, '/prayer/sarup-block', continuousReading: false);
    await tapChipExpectNoCrash(tester, 'คำแปล');

    final chip = tester.widget<ActionChip>(
      find.widgetWithText(ActionChip, 'แยกท้ายบท'),
    );
    expect(chip.onPressed, isNull);
  });

  /// A `rubric` block, such as a posture cue like "prostrate", naturally has no
  /// Pali or translation but still counts as one paragraph so both sides align.
  /// Guard against an **empty gray box** under that line and mismatched paragraph
  /// counts that can index past the end.
  Map<String, dynamic> withRubric({required bool rubricFirst}) {
    Map<String, dynamic> line(String t, {String? r, String? tr}) => {
      'id': '$t-line',
      'text': t,
      'roman': ?r,
      'translation': ?tr,
    };
    final rubric = {
      'id': 'bow',
      'type': 'rubric',
      'lines': [line('(หมอบกราบ)')],
    };
    final chant = {
      'id': 'main',
      'type': 'main',
      'lines': [line('อะระหัง', r: 'Arahaṃ', tr: 'ผู้ไกลจากกิเลส')],
    };
    return {
      'id': 'มีคำกำกับ',
      'title': 'บทที่มีคำกำกับ',
      'category': 'หมวดทดสอบ',
      'sections': rubricFirst ? [rubric, chant] : [chant, rubric],
    };
  }

  for (final first in [true, false]) {
    testWidgets(
      'rubric section does not receive empty Pali or translation boxes',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        mockPrayersAsset([withRubric(rubricFirst: first)]);
        // Inline mode is where the empty box appeared; end-card mode renders the
        // whole text as one piece, with no per-block box.
        await openPrayer(
          tester,
          '/prayer/มีคำกำกับ',
          continuousReading: false,
          inlineTranslation: true,
        );

        await tapChipExpectNoCrash(tester, 'บาลี');
        await tapChipExpectNoCrash(tester, 'คำแปล');

        expect(find.textContaining('(หมอบกราบ)'), findsWidgets);
        expect(find.textContaining('Arahaṃ'), findsWidgets);
        // Supplement boxes must not be empty; empty boxes are what users see as
        // blank gray slots under rubric text.
        expect(
          find.descendant(
            of: find.byType(PrayerContent),
            matching: find.text(''),
          ),
          findsNothing,
          reason: 'มีกล่องบาลี/คำแปลว่างเปล่าโผล่มา',
        );
      },
    );
  }
}
