/// User-pinned home-screen reference. Can point to a category, playlist, or prayer.
///
/// Pins are typed references in one ordered list rather than three separate lists.
/// The home row is a single user-controlled order, and users must be able to mix
/// categories, playlists, and individual prayers freely.
///
/// Stored in prefs as `"<type>:<id>"` under the `pinned` `List<String>` key. JSON
/// encoding is unnecessary for this small shape.
///
/// Missing targets must be tolerated: a playlist may be deleted, a category may be
/// removed, or an edition may not contain a prayer. UI callers should skip invalid
/// refs silently rather than crashing or showing empty tiles.
class PinnedRef {
  const PinnedRef(this.type, this.id);

  final PinnedType type;
  final String id;

  /// Returns `null` for malformed strings or unknown future types.
  ///
  /// Callers should drop invalid refs silently rather than breaking the whole home
  /// screen.
  static PinnedRef? tryParse(String raw) {
    final i = raw.indexOf(':');
    if (i <= 0 || i == raw.length - 1) return null;
    final type = PinnedType.values
        .where((t) => t.name == raw.substring(0, i))
        .firstOrNull;
    return type == null ? null : PinnedRef(type, raw.substring(i + 1));
  }

  String encode() => '${type.name}:$id';

  @override
  bool operator ==(Object other) =>
      other is PinnedRef && other.type == type && other.id == id;

  @override
  int get hashCode => Object.hash(type, id);

  @override
  String toString() => encode();
}

/// What a home-screen pin points at. The name is the prefix stored in prefs.
enum PinnedType { section, playlist, prayer }
