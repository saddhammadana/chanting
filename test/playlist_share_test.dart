import 'dart:convert';
import 'dart:typed_data';

import 'package:chanting/app.dart';
import 'package:chanting/data/local/prefs_service.dart';
import 'package:chanting/data/models/playlist.dart';
import 'package:chanting/features/playlists/playlist_scan_screen.dart';
import 'package:chanting/features/playlists/playlist_share.dart';
import 'package:chanting/features/playlists/playlists_controller.dart';
import 'package:chanting/router/app_router.dart';
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show
        EventChannel,
        MethodChannel,
        MissingPluginException,
        PlatformException,
        SystemChannels,
        rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

Playlist _playlist(String name, List<String> ids, {String? description}) =>
    Playlist(id: 'src', name: name, prayerIds: ids, description: description);

void main() {
  group('share code codec', () {
    test('description travels in the code, clipped to its limit', () {
      final decoded = decodePlaylistShare(
        encodePlaylistShare(
          _playlist('ชุด', ['a-1'], description: '  เริ่มต้นวันด้วยใจที่สงบ  '),
        ),
      );
      expect(decoded!.description, 'เริ่มต้นวันด้วยใจที่สงบ');

      final long = decodePlaylistShare(
        encodePlaylistShare(_playlist('ชุด', ['a-1'], description: 'ก' * 500)),
      );
      expect(long!.description!.length, kShareDescriptionMaxLength);
    });

    test('a set without description keeps the original payload shape', () {
      final code = encodePlaylistShare(_playlist('ชุด', ['a-1']));
      final json = utf8.decode(
        base64Url.decode(code.substring(kShareCodePrefix.length)),
      );
      expect(json, isNot(contains('desc')));
      expect(decodePlaylistShare(code)!.description, isNull);
    });

    test('a malformed description is dropped, the set still decodes', () {
      final payload = jsonEncode({
        'v': 1,
        'name': 'ชุด',
        'desc': 42,
        'ids': ['a-1'],
      });
      final code = '$kShareCodePrefix${base64UrlEncode(utf8.encode(payload))}';
      final decoded = decodePlaylistShare(code);
      expect(decoded, isNotNull);
      expect(decoded!.description, isNull);
    });

    test('encoded share code decodes with the same name and prayer order', () {
      final code = encodePlaylistShare(
        _playlist('สวดก่อนนอน', ['a-1', 'b-2', 'c-3']),
      );
      expect(code, startsWith(kShareCodePrefix));

      final decoded = decodePlaylistShare(code);
      expect(decoded, isNotNull);
      expect(decoded!.name, 'สวดก่อนนอน');
      expect(decoded.prayerIds, ['a-1', 'b-2', 'c-3']);
    });

    test(
      'decoder tolerates surrounding whitespace and missing copied padding',
      () {
        final code = encodePlaylistShare(_playlist('ชุด', ['a-1']));
        expect(decodePlaylistShare('  $code\n'), isNotNull);
        expect(decodePlaylistShare(code.replaceAll('=', '')), isNotNull);
      },
    );

    test('decoder rejects malformed input without leaking exceptions', () {
      for (final bad in [
        '',
        'สวัสดี',
        'https://example.com',
        'CHANTING1.', // Correct prefix but no content.
        'CHANTING1.!!!ไม่ใช่base64!!!',
        'CHANTING9.${base64UrlEncode(utf8.encode('{}'))}', // Unknown version.
        // Valid JSON format, invalid shape.
        'CHANTING1.${base64UrlEncode(utf8.encode('[]'))}',
        'CHANTING1.${base64UrlEncode(utf8.encode('{"name":"x"}'))}', // No ids.
        'CHANTING1.${base64UrlEncode(utf8.encode('{"ids":["a"]}'))}', // No name.
        'CHANTING1.${base64UrlEncode(utf8.encode('{"name":"","ids":["a"]}'))}',
        'CHANTING1.${base64UrlEncode(utf8.encode('{"name":"x","ids":[]}'))}',
        'CHANTING1.${base64UrlEncode(utf8.encode('{"name":"x","ids":[1,2]}'))}',
        'CHANTING1.${base64UrlEncode(utf8.encode('{"name":1,"ids":["a"]}'))}',
      ]) {
        expect(decodePlaylistShare(bad), isNull, reason: 'ต้องปฏิเสธ: $bad');
      }
    });

    test('decoder ignores unknown fields so newer app codes still work', () {
      final payload = jsonEncode({
        'v': 1,
        'name': 'ชุด',
        'ids': ['a-1'],
        'note': 'field อนาคต',
        'reorderable': true,
      });
      final code = '$kShareCodePrefix${base64UrlEncode(utf8.encode(payload))}';
      final decoded = decodePlaylistShare(code);
      expect(decoded, isNotNull);
      expect(decoded!.prayerIds, ['a-1']);
    });

    test(
      'decoder enforces id count limit trims long names and deduplicates ids',
      () {
        final tooMany = List.generate(kShareMaxPrayerIds + 1, (i) => 'id-$i');
        expect(
          decodePlaylistShare(encodePlaylistShare(_playlist('x', tooMany))),
          isNull,
        );

        final longName = 'ก' * (kShareNameMaxLength + 40);
        final decoded = decodePlaylistShare(
          encodePlaylistShare(_playlist(longName, ['a-1', 'a-1', 'b-2'])),
        );
        expect(decoded!.name.length, kShareNameMaxLength);
        expect(decoded.prayerIds, ['a-1', 'b-2']);
      },
    );
  });

  group('PlaylistsController.import', () {
    test('imported duplicate playlist names get numeric suffixes', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await PrefsService.init();
      final container = ProviderContainer(
        overrides: [prefsServiceProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(playlistsControllerProvider.notifier);
      expect(notifier.import('ชุดเย็น', ['a-1']).name, 'ชุดเย็น');
      expect(notifier.import('ชุดเย็น', ['a-1']).name, 'ชุดเย็น (2)');
      expect(notifier.import('ชุดเย็น', ['b-2']).name, 'ชุดเย็น (3)');

      // Persist all three playlists into real prefs.
      expect(prefs.getPlaylistsRaw(), hasLength(3));
    });
  });

  group('playlist share and import screen', () {
    setUpAll(() {
      GoogleFonts.config.allowRuntimeFetching = false;
    });

    setUp(() {
      // rootBundle cache is tied to the previous test's FakeAsync zone.
      rootBundle.evict('assets/data/prayers-th.json');
      rootBundle.evict('assets/data/prayers-en.json');
      appRouter.go('/');
    });

    /// No camera in tests: every scanner call answers null and its streams
    /// stay silent, so the scan page's panel settles on its camera-error state.
    void mockScanner(WidgetTester tester) {
      final messenger = tester.binding.defaultBinaryMessenger;
      const method = MethodChannel(
        'dev.steenbakker.mobile_scanner/scanner/method',
      );
      messenger.setMockMethodCallHandler(method, (call) async => null);
      for (final name in ['event', 'deviceOrientation']) {
        messenger.setMockStreamHandler(
          EventChannel('dev.steenbakker.mobile_scanner/scanner/$name'),
          MockStreamHandler.inline(onListen: (_, _) {}),
        );
      }
      addTearDown(() {
        messenger.setMockMethodCallHandler(method, null);
        for (final name in ['event', 'deviceOrientation']) {
          messenger.setMockStreamHandler(
            EventChannel('dev.steenbakker.mobile_scanner/scanner/$name'),
            null,
          );
        }
      });
    }

    /// Scan page with the image picker replaced by [pick].
    Future<void> openScanWithPicker(
      WidgetTester tester,
      Future<List<String>?> Function({required bool fromFiles}) pick,
    ) async {
      mockScanner(tester);
      debugPickQrImage = pick;
      addTearDown(() => debugPickQrImage = null);
    }

    /// Playlists → "รับชุดสวด" page → "วางโค้ด" card → paste page.
    Future<void> openPastePage(WidgetTester tester) async {
      await pumpUntilFound(tester, find.byTooltip('รับชุดสวด'));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byTooltip('รับชุดสวด'));
      await pumpUntilFound(tester, find.byKey(const ValueKey('receive_paste')));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byKey(const ValueKey('receive_paste')));
      await pumpUntilFound(
        tester,
        find.byKey(const ValueKey('paste_code_field')),
      );
      await tester.pump(const Duration(seconds: 1));
    }

    /// The paste page's "ดูชุดสวด" button, which opens the preview.
    FilledButton submitButton(WidgetTester tester) =>
        tester.widget<FilledButton>(find.byKey(const ValueKey('paste_submit')));

    Future<PrefsService> pumpApp(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final prefsService = await PrefsService.init();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [prefsServiceProvider.overrideWithValue(prefsService)],
          child: const ChantingApp(),
        ),
      );
      await pumpUntilFound(
        tester,
        find.byKey(const ValueKey('home_practice_hero')),
      );
      return prefsService;
    }

    testWidgets('share page saves the QR card to the photo gallery', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'welcome_seen_version': 999,
        'playlists': [
          '{"id":"p1","name":"ชุดทดสอบ","prayerIds":["ratanattaya-vandana"]}',
        ],
      });
      await pumpApp(tester);

      final calls = <String>[];
      Uint8List? saved;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('gal'),
        (call) async {
          calls.add(call.method);
          if (call.method == 'putImageBytes') {
            saved = (call.arguments as Map)['bytes'] as Uint8List;
          }
          return call.method == 'requestAccess' ? true : null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('gal'),
          null,
        ),
      );

      appRouter.go('/playlists/p1');
      await pumpUntilFound(tester, find.text('แชร์ชุดสวด'));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('แชร์ชุดสวด'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('คัดลอกโค้ด'), findsOneWidget);
      // Pinned bar title, and the QR reads as an image with the set's name.
      expect(find.widgetWithText(AppBar, 'แชร์ชุดสวด'), findsOneWidget);
      final semantics = tester.ensureSemantics();
      await tester.pump();
      // ignore: avoid_print
      expect(
        find.bySemanticsLabel('QR Code ของชุดสวด ชุดทดสอบ'),
        findsOneWidget,
      );
      semantics.dispose();

      // Rendering the card to PNG never completes under FakeAsync.
      await tester.runAsync(() async {
        await tester.tap(find.text('บันทึก QR Code'));
        for (var i = 0; i < 20 && saved == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(calls, contains('putImageBytes'));
      // PNG signature: the card was rendered, not an empty buffer.
      expect(saved!.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
      expect(find.text('บันทึก QR Code ลงคลังภาพแล้ว'), findsOneWidget);
    });

    testWidgets('refusing Photos access says so instead of claiming a save', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'welcome_seen_version': 999,
        'playlists': [
          '{"id":"p1","name":"ชุดทดสอบ","prayerIds":["ratanattaya-vandana"]}',
        ],
      });
      await pumpApp(tester);

      var attempted = false;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('gal'),
        (call) async {
          if (call.method == 'requestAccess') return false;
          if (call.method == 'putImageBytes') {
            attempted = true;
            throw PlatformException(code: 'ACCESS_DENIED');
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('gal'),
          null,
        ),
      );

      appRouter.go('/playlists/p1/share');
      await pumpUntilFound(tester, find.text('บันทึก QR Code'));
      await tester.pump(const Duration(seconds: 1));

      await tester.runAsync(() async {
        await tester.tap(find.text('บันทึก QR Code'));
        for (var i = 0; i < 20 && !attempted; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('ไม่ได้รับอนุญาต'), findsOneWidget);
      expect(find.text('บันทึก QR Code ลงคลังภาพแล้ว'), findsNothing);
      // The button is usable again for a retry after granting access.
      final button = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('บันทึก QR Code'),
          matching: find.byWidgetPredicate((w) => w is FilledButton),
        ),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('an unexpected save error re-enables the button', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'welcome_seen_version': 999,
        'playlists': [
          '{"id":"p1","name":"ชุดทดสอบ","prayerIds":["ratanattaya-vandana"]}',
        ],
      });
      await pumpApp(tester);

      // Not a PlatformException, so gal does not map it to a GalException;
      // before the fix this escaped and left the button disabled.
      var attempted = false;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('gal'),
        (call) async {
          if (call.method == 'requestAccess') return true;
          attempted = true;
          throw MissingPluginException();
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('gal'),
          null,
        ),
      );

      appRouter.go('/playlists/p1/share');
      await pumpUntilFound(tester, find.text('บันทึก QR Code'));
      await tester.pump(const Duration(seconds: 1));

      await tester.runAsync(() async {
        await tester.tap(find.text('บันทึก QR Code'));
        for (var i = 0; i < 20 && !attempted; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('บันทึก QR Code ไม่สำเร็จ ลองอีกครั้ง'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('บันทึก QR Code'),
          matching: find.byWidgetPredicate((w) => w is FilledButton),
        ),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('a set too long to scan as a QR offers only copy code', (
      tester,
    ) async {
      // Ids need not exist on this device: sharing encodes what is stored.
      final ids = List.generate(150, (i) => 'long-prayer-identifier-$i');
      final code = encodePlaylistShare(_playlist('ชุดยาว', ids));
      expect(code.length, greaterThan(kShareQrMaxChars));

      SharedPreferences.setMockInitialValues({
        'welcome_seen_version': 999,
        'playlists': [
          jsonEncode({'id': 'p1', 'name': 'ชุดยาว', 'prayerIds': ids}),
        ],
      });
      await pumpApp(tester);

      appRouter.go('/playlists/p1/share');
      await pumpUntilFound(tester, find.text('คัดลอกโค้ด'));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(QrImageView), findsNothing);
      expect(find.textContaining('ยาวเกินกว่าจะสแกน'), findsOneWidget);
      expect(find.text('บันทึก QR Code'), findsNothing);
    });

    testWidgets('share page offers only copy code where there is no gallery', (
      tester,
    ) async {
      // Linux has no gal support, so the save button gives way to copy-code.
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      SharedPreferences.setMockInitialValues({
        'welcome_seen_version': 999,
        'playlists': [
          '{"id":"p1","name":"ชุดทดสอบ","prayerIds":["ratanattaya-vandana"]}',
        ],
      });
      await pumpApp(tester);

      appRouter.go('/playlists/p1');
      await pumpUntilFound(tester, find.text('แชร์ชุดสวด'));
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('แชร์ชุดสวด'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(QrImageView), findsOneWidget);

      // The clipboard channel has no test handler; without this mock,
      // setData's Future hangs and the SnackBar never appears.
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.tap(find.text('คัดลอกโค้ด'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('คัดลอกโค้ดแล้ว'), findsOneWidget);

      // The copied code must decode fully; this is what the receiving device gets.
      final decoded = decodePlaylistShare(copied!);
      expect(decoded!.name, 'ชุดทดสอบ');
      expect(decoded.prayerIds, ['ratanattaya-vandana']);
      expect(find.text('บันทึก QR Code'), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets(
      'empty playlists cannot be shared and disable the share button',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'welcome_seen_version': 999,
          'playlists': ['{"id":"p1","name":"ชุดว่าง","prayerIds":[]}'],
        });
        await pumpApp(tester);

        appRouter.go('/playlists/p1');
        await pumpUntilFound(tester, find.text('แชร์ชุดสวด'));
        await tester.pump(const Duration(seconds: 1));

        final button = tester.widget<InkWell>(
          find.ancestor(
            of: find.text('แชร์ชุดสวด'),
            matching: find.byType(InkWell),
          ),
        );
        expect(button.onTap, isNull);
      },
    );

    testWidgets(
      'a pasted code opens the set preview, which saves known prayers only',
      (tester) async {
        SharedPreferences.setMockInitialValues({'welcome_seen_version': 999});
        final prefs = await pumpApp(tester);

        appRouter.go('/playlists');
        await openPastePage(tester);

        // Code from another device has one known prayer and one unknown prayer.
        final code = encodePlaylistShare(
          _playlist('จากเครื่องอื่น', [
            'ratanattaya-vandana',
            'prayer-from-the-future',
          ], description: 'คำอธิบายจากผู้แชร์'),
        );
        await tester.enterText(
          find.byKey(const ValueKey('paste_code_field')),
          code,
        );
        await tester.pump();
        // The paste page lists nothing itself; its button opens the preview.
        expect(find.text('จากเครื่องอื่น'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('paste_submit')));
        await pumpUntilFound(
          tester,
          find.byKey(const ValueKey('preview_confirm')),
        );
        await tester.pump(const Duration(seconds: 1));

        // The preview is the set page's layout: name, the known prayer only,
        // and the skipped-prayer notice at the foot. Nothing saved yet.
        expect(find.text('จากเครื่องอื่น'), findsOneWidget);
        expect(find.text('บทกราบพระรัตนตรัย'), findsOneWidget);
        expect(find.textContaining('ข้าม 1 บท'), findsOneWidget);
        expect(prefs.getPlaylistsRaw(), isEmpty);

        await tester.tap(find.byKey(const ValueKey('preview_confirm')));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Navigate to the newly added playlist and show its prayer.
        await pumpUntilFound(tester, find.text('บทกราบพระรัตนตรัย'));
        expect(find.text('จากเครื่องอื่น'), findsWidgets);

        // Persist only ids known on this device; unknown ids must not reach prefs.
        final raw = prefs.getPlaylistsRaw();
        expect(raw, hasLength(1));
        expect(raw.single, contains('ratanattaya-vandana'));
        expect(raw.single, isNot(contains('prayer-from-the-future')));
        // The sender's description arrives with the set.
        expect(
          (jsonDecode(raw.single) as Map)['description'],
          'คำอธิบายจากผู้แชร์',
        );
      },
    );

    testWidgets('invalid pasted code shows a warning and no add button', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'welcome_seen_version': 999});
      await pumpApp(tester);

      appRouter.go('/playlists');
      await openPastePage(tester);

      await tester.enterText(
        find.byKey(const ValueKey('paste_code_field')),
        'ไม่ใช่โค้ดอะไรเลย',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('โค้ดไม่ถูกต้อง'), findsOneWidget);
      // Nothing to preview, so "ดูชุดสวด" stays disabled.
      expect(submitButton(tester).onPressed, isNull);
    });

    testWidgets('a set with no prayer this device knows cannot be received', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'welcome_seen_version': 999});
      final prefs = await pumpApp(tester);

      appRouter.go(
        '/playlists/preview',
        extra: encodePlaylistShare(
          _playlist('จากอนาคต', ['prayer-from-the-future']),
        ),
      );
      await pumpUntilFound(
        tester,
        find.byKey(const ValueKey('preview_confirm')),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('จากอนาคต'), findsOneWidget);
      expect(find.textContaining('ไม่รู้จักบทในชุดนี้'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('preview_confirm')),
        warnIfMissed: false,
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(prefs.getPlaylistsRaw(), isEmpty);
    });

    testWidgets('paste from clipboard fills the field, or says it is empty', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'welcome_seen_version': 999});
      await pumpApp(tester);

      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => call.method == 'Clipboard.getData'
            ? (clipboard == null ? null : {'text': clipboard})
            : null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      appRouter.go('/playlists');
      await openPastePage(tester);
      expect(submitButton(tester).onPressed, isNull);

      await tester.tap(find.byKey(const ValueKey('paste_from_clipboard')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('คลิปบอร์ดไม่มีข้อความ'), findsOneWidget);

      clipboard =
          '  ${encodePlaylistShare(_playlist('จากคลิปบอร์ด', ['ratanattaya-vandana']))}\n';
      await tester.tap(find.byKey(const ValueKey('paste_from_clipboard')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // Filled, trimmed, and ready to preview; the page lists nothing itself.
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('paste_code_field')))
            .controller!
            .text,
        clipboard.trim(),
      );
      expect(submitButton(tester).onPressed, isNotNull);
    });

    testWidgets('receive page offers scan and paste on a phone', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'welcome_seen_version': 999});
      await pumpApp(tester);

      appRouter.go('/playlists/receive');
      await pumpUntilFound(tester, find.text('รับชุดสวดใหม่'));
      await tester.pump(const Duration(seconds: 1));

      // Widget tests run as Android, which has a camera: both ways in. The
      // scan card is not tapped; tests have no camera.
      expect(find.widgetWithText(AppBar, 'รับชุดสวด'), findsOneWidget);
      expect(find.byKey(const ValueKey('receive_scan')), findsOneWidget);
      expect(find.byKey(const ValueKey('receive_paste')), findsOneWidget);
    });

    testWidgets('receive page disables scan where there is no camera', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'welcome_seen_version': 999});
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      await pumpApp(tester);

      appRouter.go('/playlists/receive');
      await pumpUntilFound(tester, find.byKey(const ValueKey('receive_paste')));

      // Shown as drawn, but disabled and saying where it works.
      final scan = find.byKey(const ValueKey('receive_scan'));
      expect(scan, findsOneWidget);
      expect(
        find.descendant(
          of: scan,
          matching: find.text('ใช้ได้บนมือถือหรือเว็บ'),
        ),
        findsOneWidget,
      );
      final ink = tester.widget<InkWell>(
        find.descendant(of: scan, matching: find.byType(InkWell)),
      );
      expect(ink.onTap, isNull);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('a picked image with a set code opens its preview', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'welcome_seen_version': 999});
      final code = encodePlaylistShare(
        _playlist('จากรูป', ['ratanattaya-vandana']),
      );
      bool? askedForFiles;
      await openScanWithPicker(tester, ({required fromFiles}) async {
        askedForFiles = fromFiles;
        // A foreign QR in the same picture must not hide the set's code.
        return ['https://example.com', code];
      });
      await pumpApp(tester);

      // The real way in: receive page → scan card → scan page.
      appRouter.go('/playlists/receive');
      await pumpUntilFound(tester, find.byKey(const ValueKey('receive_scan')));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byKey(const ValueKey('receive_scan')));
      await pumpUntilFound(
        tester,
        find.byKey(const ValueKey('scan_pick_file')),
      );
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.byKey(const ValueKey('scan_pick_file')));
      await pumpUntilFound(tester, find.text('จากรูป'));
      await tester.pump(const Duration(seconds: 1));

      expect(askedForFiles, isTrue);
      // Straight to the set's preview — no stop on the paste page.
      expect(find.byKey(const ValueKey('preview_confirm')), findsOneWidget);
      expect(find.byKey(const ValueKey('paste_code_field')), findsNothing);
      expect(find.text('วิธีการสแกน'), findsNothing);
    });

    testWidgets('a picked image without a set code says so and stays', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'welcome_seen_version': 999});
      bool? askedForFiles;
      await openScanWithPicker(tester, ({required fromFiles}) async {
        askedForFiles = fromFiles;
        return ['https://example.com'];
      });
      await pumpApp(tester);

      appRouter.go('/playlists/scan');
      await pumpUntilFound(tester, find.byTooltip('เลือกรูปจากคลัง'));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byTooltip('เลือกรูปจากคลัง'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(askedForFiles, isFalse);
      expect(find.text('ไม่พบ QR Code ของชุดสวดในรูปนี้'), findsOneWidget);
      expect(find.text('วิธีการสแกน'), findsOneWidget);
    });

    testWidgets('cancelling the picker changes nothing', (tester) async {
      SharedPreferences.setMockInitialValues({'welcome_seen_version': 999});
      await openScanWithPicker(tester, ({required fromFiles}) async => null);
      await pumpApp(tester);

      appRouter.go('/playlists/scan');
      await pumpUntilFound(
        tester,
        find.byKey(const ValueKey('scan_pick_file')),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byKey(const ValueKey('scan_pick_file')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('วิธีการสแกน'), findsOneWidget);
      // The buttons are back for another try.
      final ink = tester.widget<InkWell>(
        find.byKey(const ValueKey('scan_pick_file')),
      );
      expect(ink.onTap, isNotNull);
    });

    testWidgets('an image that cannot be read says so', (tester) async {
      SharedPreferences.setMockInitialValues({'welcome_seen_version': 999});
      await openScanWithPicker(
        tester,
        ({required fromFiles}) async => throw Exception('corrupt image'),
      );
      await pumpApp(tester);

      appRouter.go('/playlists/scan');
      await pumpUntilFound(
        tester,
        find.byKey(const ValueKey('scan_pick_file')),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byKey(const ValueKey('scan_pick_file')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('อ่านรูปนี้ไม่ได้ ลองรูปอื่น'), findsOneWidget);
    });

    testWidgets('scan page shows the camera panel, steps and picking a file', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'welcome_seen_version': 999});
      mockScanner(tester);
      await pumpApp(tester);

      appRouter.go('/playlists/scan');
      await pumpUntilFound(tester, find.text('วิธีการสแกน'));
      await tester.pump(const Duration(seconds: 1));

      expect(find.widgetWithText(AppBar, 'สแกน QR Code'), findsOneWidget);
      // Android reads a picked image, so both ways to pick one are offered.
      expect(find.byTooltip('เลือกรูปจากคลัง'), findsOneWidget);
      expect(find.byKey(const ValueKey('scan_pick_file')), findsOneWidget);
      // The quoted button name in step 3 is the preview's real button.
      expect(find.textContaining('“ยืนยันรับชุดสวด”'), findsOneWidget);
    });

    test('playlist scan support is enabled on phones, not desktop apps', () {
      // The desktop apps have no camera path wired up; this guard keeps the
      // scan card from opening a broken screen there. The web build is
      // enabled through kIsWeb, which a test cannot switch on.
      for (final (platform, supported) in [
        (TargetPlatform.android, true),
        (TargetPlatform.iOS, true),
        (TargetPlatform.windows, false),
        (TargetPlatform.linux, false),
        (TargetPlatform.macOS, false),
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(playlistScanSupported, supported, reason: '$platform');
      }
      debugDefaultTargetPlatformOverride = null;
    });
  });
}
