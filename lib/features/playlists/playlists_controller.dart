import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/prefs_service.dart';
import '../../data/models/playlist.dart';

/// All user playlists, persisted to SharedPreferences on every change.
class PlaylistsController extends Notifier<List<Playlist>> {
  @override
  List<Playlist> build() {
    return ref
        .read(prefsServiceProvider)
        .getPlaylistsRaw()
        .map(Playlist.fromJsonString)
        .toList();
  }

  void _persist() {
    ref
        .read(prefsServiceProvider)
        .setPlaylistsRaw(state.map((p) => p.toJsonString()).toList());
  }

  /// Creates a new playlist with prayer ids already present.
  ///
  /// Used by both imported shared playlists and "create playlist from category".
  /// Both need exactly the same behavior: create with `prayerIds` and make the
  /// name unique, so one method handles both flows.
  ///
  /// [prayerIds] must already be filtered against this device's prayer library.
  /// Unknown ids must not enter prefs because they would create broken rendered
  /// playlists. Duplicate names receive (2), (3), ... without another prompt.
  Playlist import(String name, List<String> prayerIds, {String? description}) {
    final names = state.map((p) => p.name).toSet();
    var unique = name;
    for (var n = 2; names.contains(unique); n++) {
      unique = '$name ($n)';
    }
    final playlist = Playlist(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: unique,
      prayerIds: prayerIds,
      description: description,
    );
    state = [...state, playlist];
    _persist();
    return playlist;
  }

  /// Writes the edit page's draft: a new set when [id] is null, otherwise
  /// the set with that id. A blank [description] is stored as none.
  Playlist save({
    String? id,
    required String name,
    required String? description,
    required List<String> prayerIds,
  }) {
    final text = description?.trim();
    final playlist = Playlist(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      prayerIds: prayerIds,
      description: text == null || text.isEmpty ? null : text,
    );
    state = id == null
        ? [...state, playlist]
        : [for (final p in state) p.id == id ? playlist : p];
    _persist();
    return playlist;
  }

  /// Removes a set and returns where it stood, for [restore]; -1 when no
  /// set has that id.
  int remove(String id) {
    final index = state.indexWhere((p) => p.id == id);
    if (index < 0) return -1;
    state = [...state]..removeAt(index);
    _persist();
    return index;
  }

  /// Puts a just-deleted set back where it was ("เลิกทำ"). Its pin was never
  /// pruned from prefs, so it returns pinned too.
  void restore(Playlist playlist, int index) {
    if (state.any((p) => p.id == playlist.id)) return;
    final at = index.clamp(0, state.length);
    state = [...state]..insert(at, playlist);
    _persist();
  }
}

final playlistsControllerProvider =
    NotifierProvider<PlaylistsController, List<Playlist>>(
      PlaylistsController.new,
    );

/// Playlist by id, or null after deletion.
final playlistProvider = Provider.family<Playlist?, String>((ref, id) {
  final playlists = ref.watch(playlistsControllerProvider);
  for (final p in playlists) {
    if (p.id == id) return p;
  }
  return null;
});
