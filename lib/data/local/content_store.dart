import 'package:flutter/foundation.dart' show protected;
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'content_store_stub.dart'
    if (dart.library.io) 'content_store_io.dart'
    show openContentStore;

/// Which fetched prayer book this is: the release number the server gave it
/// and when that release was published (ISO 8601).
typedef ContentRelease = ({int version, String publishedAt});

/// The prayer book fetched after install, kept beside the one in the bundle.
///
/// The bundle is always there and always readable, so everything here is an
/// override that may be absent: [read] answers null and the repository falls
/// back to the asset. See docs/architecture/content-updates.md.
///
/// This class keeps the files in memory, which is all the web build and the
/// tests need. `content_store_io.dart` keeps them on disk.
class ContentStore {
  ContentStore({this.bundledVersion = 0, this.active}) : saved = active;

  /// Release the bundled files were cut from (`assets/data/release.json`).
  /// A fetched release is used only when its number is higher, so an app
  /// update carrying newer text is not overridden by an older file.
  final int bundledVersion;

  /// What readers see this session, or null for the bundle.
  ContentRelease? active;

  /// The newest release stored. Ahead of [active] after a background fetch,
  /// which waits for the next launch so text never changes under a reader.
  ContentRelease? saved;

  final _memory = <int, Map<String, String>>{};

  /// The newest release this install already has, bundled or fetched.
  int get newestVersion => saved?.version ?? bundledVersion;

  /// One file of the active release by name (`prayers-th`), or null.
  Future<String?> read(String name) async {
    final release = active;
    return release == null ? null : load(release.version, name);
  }

  Future<void> save(ContentRelease release, Map<String, String> files) async {
    await write(release, files);
    saved = release;
  }

  /// Makes the stored release the one readers see.
  void apply() => active = saved;

  /// Back to the bundle, dropping whatever was fetched.
  Future<void> reset() async {
    await erase();
    active = saved = null;
  }

  @protected
  Future<String?> load(int version, String name) async =>
      _memory[version]?[name];

  @protected
  Future<void> write(ContentRelease release, Map<String, String> files) async {
    _memory[release.version] = files;
  }

  @protected
  Future<void> erase() async => _memory.clear();
}

/// Overridden with the on-disk store in `main()`. The default holds nothing,
/// so a widget test reads the bundle.
final contentStoreProvider = Provider<ContentStore>((ref) => ContentStore());

/// Bumped when the active release changes, so content providers reload.
class ContentEpoch extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final contentEpochProvider = NotifierProvider<ContentEpoch, int>(
  ContentEpoch.new,
);
