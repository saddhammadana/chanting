import 'dart:convert';
import 'dart:io';

import 'package:chanting/app.dart';
import 'package:chanting/data/content_check.dart';
import 'package:chanting/data/local/content_store.dart';
import 'package:chanting/data/local/content_store_io.dart';
import 'package:chanting/data/local/prefs_service.dart';
import 'package:chanting/data/repositories/prayer_repository.dart';
import 'package:chanting/features/content_update/content_update_controller.dart';
import 'package:chanting/router/app_router.dart';
import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A prayer book fetched after install.
///
/// Nothing here touches the network: the server is a `MockClient` serving a
/// release built from the shipped files with one title changed, so a content
/// edit cannot break these and no prayer is pinned by name.
///
/// What is being protected is the reader's book. A release that does not
/// verify, does not decode, or is older than the bundle must leave the app
/// reading what it read before.
const _marker = ' (ฉบับแก้ไข)';

Map<String, String> _shippedFiles() => {
  for (final name in contentFileNames)
    name: File('assets/data/$name.json').readAsStringSync(),
};

/// The shipped book with the first Thai title marked, as a newer release.
Map<String, String> _editedFiles() {
  final files = _shippedFiles();
  final prayers = jsonDecode(files['prayers-th']!) as List<dynamic>;
  final first = prayers.first as Map<String, dynamic>;
  first['title'] = '${first['title']}$_marker';
  files['prayers-th'] = jsonEncode(prayers);
  return files;
}

String _firstPrayerId() =>
    ((jsonDecode(_shippedFiles()['prayers-th']!) as List).first as Map)['id']
        as String;

/// A server publishing [files] as release [version]. [calls] counts requests.
MockClient _server(
  Map<String, String> files, {
  int version = 5,
  int schema = kContentSchema,
  Map<String, String> hashes = const {},
  List<String>? calls,
}) => MockClient((request) async {
  calls?.add(request.url.path);
  if (request.url.path == kContentReleaseUrl.path) {
    return http.Response(
      jsonEncode({
        'version': version,
        'schema': schema,
        'publishedAt': '2026-10-10T01:00:00.000Z',
        'files': {
          for (final entry in files.entries)
            entry.key: {
              'sha256':
                  hashes[entry.key] ??
                  sha256.convert(utf8.encode(entry.value)).toString(),
              'bytes': utf8.encode(entry.value).length,
              'url': '${kContentReleaseUrl.path}/${entry.key}.json?v=$version',
            },
        },
      }),
      200,
    );
  }
  final name = request.url.pathSegments.last.replaceFirst('.json', '');
  return http.Response.bytes(utf8.encode(files[name]!), 200);
});

Future<ProviderContainer> _container(
  http.Client client, {
  ContentStore? store,
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues({...prefs});
  final container = ProviderContainer(
    overrides: [
      prefsServiceProvider.overrideWithValue(await PrefsService.init()),
      contentStoreProvider.overrideWithValue(store ?? ContentStore()),
      contentHttpClientProvider.overrideWithValue(client),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('a check the user asked for', () {
    test('stores a newer release and applies it at once', () async {
      final container = await _container(_server(_editedFiles()));
      final epoch = container.read(contentEpochProvider);

      await container.read(contentUpdateControllerProvider.notifier).checkNow();

      final state = container.read(contentUpdateControllerProvider);
      expect(state.status, ContentUpdateStatus.updated);
      expect(state.active?.version, 5);
      expect(state.pending, isNull);
      expect(container.read(contentEpochProvider), epoch + 1);

      final prayers = await PrayerRepository(
        store: container.read(contentStoreProvider),
      ).getAllPrayers();
      expect(
        prayers.firstWhere((p) => p.id == _firstPrayerId()).title,
        endsWith(_marker),
      );
    });

    test('says up to date when the server has nothing newer', () async {
      final container = await _container(
        _server(_editedFiles(), version: 3),
        store: ContentStore(bundledVersion: 3),
      );
      await container.read(contentUpdateControllerProvider.notifier).checkNow();

      final state = container.read(contentUpdateControllerProvider);
      expect(state.status, ContentUpdateStatus.upToDate);
      expect(state.active, isNull);
    });

    test('treats a server that has published nothing as up to date', () async {
      final container = await _container(
        MockClient((_) async => http.Response('{}', 404)),
      );
      await container.read(contentUpdateControllerProvider.notifier).checkNow();
      expect(
        container.read(contentUpdateControllerProvider).status,
        ContentUpdateStatus.upToDate,
      );
    });

    test('leaves a release with a newer schema alone', () async {
      final container = await _container(
        _server(_editedFiles(), schema: kContentSchema + 1),
      );
      await container.read(contentUpdateControllerProvider.notifier).checkNow();

      final state = container.read(contentUpdateControllerProvider);
      expect(state.status, ContentUpdateStatus.upToDate);
      expect(state.active, isNull);
    });
  });

  group('a release that must not be used', () {
    Future<ContentUpdateState> checked(http.Client client) async {
      final container = await _container(client);
      await container.read(contentUpdateControllerProvider.notifier).checkNow();
      expect(container.read(contentStoreProvider).saved, isNull);
      return container.read(contentUpdateControllerProvider);
    }

    test('a file that does not match its hash', () async {
      final state = await checked(
        _server(_editedFiles(), hashes: {'prayers-th': '0' * 64}),
      );
      expect(state.status, ContentUpdateStatus.failed);
      expect(state.active, isNull);
    });

    test('a file that is not a prayer book', () async {
      final files = _editedFiles()..['prayers-th'] = '{"oops": true}';
      final state = await checked(_server(files));
      expect(state.status, ContentUpdateStatus.failed);
    });

    test('an edition with no prayers', () async {
      final files = _editedFiles()..['prayers-en'] = '[]';
      final state = await checked(_server(files));
      expect(state.status, ContentUpdateStatus.failed);
    });

    test('no connection', () async {
      final state = await checked(
        MockClient((_) async => throw const SocketException('offline')),
      );
      expect(state.status, ContentUpdateStatus.failed);
    });

    test('a server error', () async {
      final state = await checked(
        MockClient((_) async => http.Response('', 503)),
      );
      expect(state.status, ContentUpdateStatus.failed);
    });
  });

  group('the check at startup', () {
    final noon = DateTime(2026, 10, 10, 12);

    test('stores a release for the next launch without applying it', () async {
      final container = await _container(_server(_editedFiles()));
      final epoch = container.read(contentEpochProvider);

      await container
          .read(contentUpdateControllerProvider.notifier)
          .checkOnStartup(now: () => noon);

      final state = container.read(contentUpdateControllerProvider);
      expect(
        state.active,
        isNull,
        reason: 'ข้อความต้องไม่เปลี่ยนกลางการใช้งาน',
      );
      expect(state.pending?.version, 5);
      expect(container.read(contentEpochProvider), epoch);

      // The button then applies what is already stored.
      await container.read(contentUpdateControllerProvider.notifier).checkNow();
      expect(
        container.read(contentUpdateControllerProvider).active?.version,
        5,
      );
    });

    test('asks at most once a day', () async {
      final calls = <String>[];
      final container = await _container(
        _server(_editedFiles(), version: 0, calls: calls),
      );
      final controller = container.read(
        contentUpdateControllerProvider.notifier,
      );

      await controller.checkOnStartup(now: () => noon);
      await controller.checkOnStartup(
        now: () => noon.add(const Duration(hours: 23)),
      );
      expect(calls, hasLength(1));

      await controller.checkOnStartup(
        now: () => noon.add(const Duration(hours: 25)),
      );
      expect(calls, hasLength(2));
    });

    test('asks nothing when the switch is off', () async {
      final calls = <String>[];
      final container = await _container(
        _server(_editedFiles(), calls: calls),
        prefs: {'content_auto_update': false},
      );
      await container
          .read(contentUpdateControllerProvider.notifier)
          .checkOnStartup(now: () => noon);
      expect(calls, isEmpty);
    });

    test('stays silent offline and asks again next time', () async {
      final container = await _container(
        MockClient((_) async => throw const SocketException('offline')),
      );
      await container
          .read(contentUpdateControllerProvider.notifier)
          .checkOnStartup(now: () => noon);

      expect(
        container.read(contentUpdateControllerProvider).status,
        ContentUpdateStatus.idle,
      );
      expect(container.read(prefsServiceProvider).getContentLastCheck(), 0);
    });
  });

  test(
    'going back to the bundled book drops the release and stops asking',
    () async {
      final container = await _container(_server(_editedFiles()));
      final controller = container.read(
        contentUpdateControllerProvider.notifier,
      );
      await controller.checkNow();
      await controller.useBundled();

      final state = container.read(contentUpdateControllerProvider);
      expect(state.active, isNull);
      expect(state.autoUpdate, isFalse);
      expect(
        await container.read(contentStoreProvider).read('prayers-th'),
        isNull,
      );
    },
  );

  group('the repository', () {
    setUp(() {
      for (final name in contentFileNames) {
        rootBundle.evict('assets/data/$name.json');
      }
    });

    test('falls back to the bundle when the fetched file is damaged', () async {
      final store = ContentStore();
      await store.save(
        (version: 2, publishedAt: ''),
        {'prayers-th': 'not json', 'sections-th': 'not json'},
      );
      store.apply();

      final prayers = await PrayerRepository(store: store).getAllPrayers();
      expect(prayers, isNotEmpty);
      expect(prayers.any((p) => p.title.endsWith(_marker)), isFalse);
    });
  });

  group('the shipped book', () {
    test('passes the check a fetched release has to pass', () {
      expect(contentProblems(_shippedFiles()), isEmpty);
    });

    test('is stamped with the release it was cut from', () {
      final stamp =
          jsonDecode(File('assets/data/release.json').readAsStringSync())
              as Map<String, dynamic>;
      expect(stamp['version'], isA<int>());
      expect(stamp['schema'], lessThanOrEqualTo(kContentSchema));
    });
  });

  group('the store on disk', () {
    late Directory root;

    setUp(() => root = Directory.systemTemp.createTempSync('content-store-'));
    tearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    test('reads back what it stored after a restart', () async {
      final first = await FileContentStore.open(root, bundledVersion: 1);
      expect(first.active, isNull);
      await first.save((version: 4, publishedAt: 'then'), {'prayers-th': 'a'});
      expect(first.active, isNull, reason: 'ยังไม่ apply');

      final second = await FileContentStore.open(root, bundledVersion: 1);
      expect(second.active, (version: 4, publishedAt: 'then'));
      expect(await second.read('prayers-th'), 'a');
      expect(await second.read('prayers-en'), isNull);
    });

    test('keeps only the release in use and the newest', () async {
      final store = await FileContentStore.open(root, bundledVersion: 0);
      await store.save((version: 1, publishedAt: ''), {'prayers-th': 'a'});
      store.apply();
      await store.save((version: 2, publishedAt: ''), {'prayers-th': 'b'});
      await store.save((version: 3, publishedAt: ''), {'prayers-th': 'c'});

      expect(await store.read('prayers-th'), 'a');
      expect(Directory('${root.path}/v2').existsSync(), isFalse);
      expect(Directory('${root.path}/v3').existsSync(), isTrue);
    });

    test('retires a release the bundle has caught up with', () async {
      final old = await FileContentStore.open(root, bundledVersion: 0);
      await old.save((version: 4, publishedAt: ''), {'prayers-th': 'a'});

      final updated = await FileContentStore.open(root, bundledVersion: 4);
      expect(updated.active, isNull);
      expect(root.existsSync(), isFalse);
    });

    test('goes back to the bundle on reset', () async {
      final store = await FileContentStore.open(root, bundledVersion: 0);
      await store.save((version: 2, publishedAt: ''), {'prayers-th': 'a'});
      store.apply();
      await store.reset();

      expect(store.active, isNull);
      expect(await store.read('prayers-th'), isNull);
      expect(
        (await FileContentStore.open(root, bundledVersion: 0)).active,
        isNull,
      );
    });
  });

  group('the settings page', () {
    setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

    setUp(() {
      for (final name in contentFileNames) {
        rootBundle.evict('assets/data/$name.json');
      }
      appRouter.go('/');
    });

    testWidgets('checking shows the release now being read', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({
        'welcome_seen_version': 999,
        'goal_prompt_seen': true,
      });
      final prefsService = await PrefsService.init();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            prefsServiceProvider.overrideWithValue(prefsService),
            contentHttpClientProvider.overrideWithValue(
              _server(_editedFiles()),
            ),
          ],
          child: const ChantingApp(),
        ),
      );
      appRouter.go('/settings/content');
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      final versionRow = find.byKey(const ValueKey('content_version'));
      expect(
        find.descendant(of: versionRow, matching: find.textContaining('5')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('content_use_bundled')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('content_check_now')));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(
        find.descendant(of: versionRow, matching: find.textContaining('5')),
        findsOneWidget,
      );
      expect(find.byType(SnackBar), findsOneWidget);

      // Back to the bundled book, which also turns the switch off.
      await tester.tap(find.byKey(const ValueKey('content_use_bundled')));
      await tester.pump();
      expect(find.byKey(const ValueKey('content_use_bundled')), findsNothing);
      expect(
        tester
            .widget<Switch>(find.byKey(const ValueKey('content_auto_update')))
            .value,
        isFalse,
      );

      // Let the toast leave before the test ends.
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 400));
      }
    });
  });
}
