import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter/foundation.dart' show immutable, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../data/content_check.dart';
import '../../data/local/content_store.dart';
import '../../data/local/prefs_service.dart';

/// Where the published prayer book is announced. The answer names a release
/// number, a schema and the hash of each file; see
/// docs/architecture/content-updates.md.
final kContentReleaseUrl = Uri.parse(
  'https://dhammapanya.org/api/v1/chant-release',
);

/// The newest file shape this build reads. A release with a higher schema is
/// left alone until the app itself is updated.
const kContentSchema = 1;

/// The web build has nowhere to keep a fetched book and is redeployed with
/// its bundle, so it neither asks nor shows the setting.
const contentUpdateSupported = !kIsWeb;

/// How often the app asks by itself.
const _autoCheckEvery = Duration(hours: 24);

/// Replaced in tests; the real client is closed with the container.
final contentHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

enum ContentUpdateStatus { idle, checking, upToDate, updated, failed }

@immutable
class ContentUpdateState {
  const ContentUpdateState({
    this.status = ContentUpdateStatus.idle,
    this.active,
    this.pending,
    this.autoUpdate = true,
  });

  final ContentUpdateStatus status;

  /// The fetched release being read, or null for the bundled book.
  final ContentRelease? active;

  /// A release already stored that the next launch will read.
  final ContentRelease? pending;
  final bool autoUpdate;
}

/// Fetches a newer prayer book and decides when readers see it.
///
/// A check made by the app itself only stores what it finds: the text a
/// person is chanting from must not change under them, so it is read from the
/// next launch. A check the user asked for is applied at once.
class ContentUpdateController extends Notifier<ContentUpdateState> {
  ContentStore get _store => ref.read(contentStoreProvider);
  PrefsService get _prefs => ref.read(prefsServiceProvider);

  @override
  ContentUpdateState build() => _snapshot(ContentUpdateStatus.idle);

  ContentUpdateState _snapshot(ContentUpdateStatus status) {
    final store = _store;
    return ContentUpdateState(
      status: status,
      active: store.active,
      pending: store.saved?.version == store.active?.version
          ? null
          : store.saved,
      autoUpdate: _prefs.getContentAutoUpdate(),
    );
  }

  Future<void> setAutoUpdate(bool value) async {
    await _prefs.setContentAutoUpdate(value);
    state = _snapshot(state.status);
  }

  /// The check `main` starts: silent, at most once a day, never applied.
  Future<void> checkOnStartup({DateTime Function() now = DateTime.now}) async {
    if (!contentUpdateSupported || !_prefs.getContentAutoUpdate()) return;
    final last = DateTime.fromMillisecondsSinceEpoch(
      _prefs.getContentLastCheck(),
    );
    if (now().difference(last) < _autoCheckEvery) return;
    try {
      await _fetch();
      await _prefs.setContentLastCheck(now().millisecondsSinceEpoch);
      state = _snapshot(ContentUpdateStatus.idle);
    } catch (_) {
      // Offline, or a release this build refuses. Ask again next launch.
    }
  }

  /// The check behind the settings button: applied as soon as it is stored.
  Future<void> checkNow() async {
    if (state.status == ContentUpdateStatus.checking) return;
    state = _snapshot(ContentUpdateStatus.checking);
    try {
      await _fetch();
      final store = _store;
      final changed = store.saved?.version != store.active?.version;
      if (changed) {
        store.apply();
        ref.read(contentEpochProvider.notifier).bump();
      }
      state = _snapshot(
        changed ? ContentUpdateStatus.updated : ContentUpdateStatus.upToDate,
      );
    } catch (_) {
      state = _snapshot(ContentUpdateStatus.failed);
    }
  }

  /// Back to the book the app was built with.
  Future<void> useBundled() async {
    await _store.reset();
    // Otherwise the next launch would fetch the same release straight back.
    await _prefs.setContentAutoUpdate(false);
    ref.read(contentEpochProvider.notifier).bump();
    state = _snapshot(ContentUpdateStatus.idle);
  }

  /// Stores the published release when it is newer than what is held.
  /// Throws on anything that should count as "could not check".
  Future<void> _fetch() async {
    final client = ref.read(contentHttpClientProvider);
    final answer = await client
        .get(kContentReleaseUrl)
        .timeout(const Duration(seconds: 10));
    // Nothing has been published yet.
    if (answer.statusCode == 404) return;
    if (answer.statusCode != 200) throw StateError('${answer.statusCode}');

    final manifest =
        jsonDecode(utf8.decode(answer.bodyBytes)) as Map<String, dynamic>;
    final version = manifest['version'] as int;
    if ((manifest['schema'] as int) > kContentSchema) return;
    if (version <= _store.newestVersion) return;

    final listed = manifest['files'] as Map<String, dynamic>;
    final files = <String, String>{};
    for (final name in contentFileNames) {
      final entry = listed[name] as Map<String, dynamic>;
      final file = await client
          .get(kContentReleaseUrl.resolve(entry['url'] as String))
          .timeout(const Duration(seconds: 30));
      if (file.statusCode != 200) throw StateError('$name ${file.statusCode}');
      if (sha256.convert(file.bodyBytes).toString() != entry['sha256']) {
        throw StateError('$name does not match its hash');
      }
      files[name] = utf8.decode(file.bodyBytes);
    }

    final problems = contentProblems(files);
    if (problems.isNotEmpty) throw StateError(problems.join('; '));

    await _store.save((
      version: version,
      publishedAt: manifest['publishedAt'] as String,
    ), files);
  }
}

final contentUpdateControllerProvider =
    NotifierProvider<ContentUpdateController, ContentUpdateState>(
      ContentUpdateController.new,
    );
