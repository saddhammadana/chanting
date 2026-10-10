import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'content_store.dart';

/// Opens the on-disk store, falling back to an empty in-memory one when the
/// platform has no application-support directory. Never throws: a prayer book
/// that cannot be fetched is not a reason for the app not to start.
Future<ContentStore> openContentStore({required int bundledVersion}) async {
  try {
    final support = await getApplicationSupportDirectory();
    return FileContentStore.open(
      Directory('${support.path}/content'),
      bundledVersion: bundledVersion,
    );
  } catch (_) {
    return ContentStore(bundledVersion: bundledVersion);
  }
}

/// `content/v<version>/<name>.json`, with `current.json` naming the release
/// in use. The pointer is written last and by rename, so a fetch interrupted
/// half way leaves the previous release in place.
class FileContentStore extends ContentStore {
  FileContentStore(this._root, {required super.bundledVersion, super.active});

  final Directory _root;

  File get _pointer => File('${_root.path}/current.json');
  Directory _folder(int version) => Directory('${_root.path}/v$version');

  static Future<ContentStore> open(
    Directory root, {
    required int bundledVersion,
  }) async {
    ContentRelease? stored;
    try {
      final json =
          jsonDecode(await File('${root.path}/current.json').readAsString())
              as Map<String, dynamic>;
      stored = (
        version: json['version'] as int,
        publishedAt: json['publishedAt'] as String,
      );
    } catch (_) {
      // No pointer, or one that cannot be read: the bundle.
    }
    final store = FileContentStore(
      root,
      bundledVersion: bundledVersion,
      active: stored != null && stored.version > bundledVersion ? stored : null,
    );
    // An app update that bundles the same or newer text retires the files.
    if (stored != null && store.active == null) await store.erase();
    return store;
  }

  @override
  Future<String?> load(int version, String name) async {
    try {
      return await File('${_folder(version).path}/$name.json').readAsString();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(ContentRelease release, Map<String, String> files) async {
    final folder = _folder(release.version);
    await folder.create(recursive: true);
    for (final entry in files.entries) {
      await File(
        '${folder.path}/${entry.key}.json',
      ).writeAsString(entry.value, flush: true);
    }
    final draft = File('${_pointer.path}.tmp');
    await draft.writeAsString(
      jsonEncode({
        'version': release.version,
        'publishedAt': release.publishedAt,
      }),
      flush: true,
    );
    await draft.rename(_pointer.path);

    // Keep the release still being read this session and the new one.
    final keep = {
      folder.path,
      if (active != null) _folder(active!.version).path,
    };
    await for (final entry in _root.list()) {
      if (entry is Directory && !keep.contains(entry.path)) {
        await entry.delete(recursive: true);
      }
    }
  }

  @override
  Future<void> erase() async {
    if (await _root.exists()) await _root.delete(recursive: true);
  }
}
