import 'dart:convert';

import '../../data/models/playlist.dart';

/// Encodes and decodes offline playlist share codes.
///
/// One code supports two paths: show as QR for another device to scan, or copy
/// and send through chat. The payload contains the playlist name, its
/// description when it has one, and ordered `prayerIds` — not prayer text,
/// because every app has the same bundled content and ids are stable.
///
/// Format: `CHANTING1.` plus base64url JSON
/// `{"v":1,"name":...,"desc":...,"ids":[...]}`. `desc` was added later and is
/// optional; older apps ignore it, since the decoder skips unknown fields. The number in the prefix is the wire-format
/// version. If encoding changes, such as adding compression for long playlists,
/// emit `CHANTING2.` while old devices can still decode `CHANTING1.`.

/// Code type and version prefix; decoding uses it to reject unrelated text early.
const kShareCodePrefix = 'CHANTING1.';

/// Decode limits for untrusted external codes.
///
/// Overlong names are truncated. Too many ids or wrong id types reject the whole
/// code.
const kShareNameMaxLength = 60;

/// Kept short so a described set still fits a scannable QR.
const kShareDescriptionMaxLength = 120;
const kShareMaxPrayerIds = 200;
const _kShareIdMaxLength = 100;

/// Above this length, QR codes become too dense to scan reliably from a screen.
///
/// Sharing UI should hide QR and direct users to copy the code instead.
const kShareQrMaxChars = 1200;

/// Playlist decoded from a share code, not yet validated against this device.
///
/// Some ids may not exist locally and must be filtered before saving.
class SharedPlaylist {
  const SharedPlaylist({
    required this.name,
    required this.prayerIds,
    this.description,
  });

  final String name;
  final List<String> prayerIds;
  final String? description;
}

String encodePlaylistShare(Playlist playlist) {
  final description = _clip(playlist.description, kShareDescriptionMaxLength);
  final payload = jsonEncode({
    'v': 1,
    'name': playlist.name,
    'desc': ?description,
    'ids': playlist.prayerIds,
  });
  return '$kShareCodePrefix${base64UrlEncode(utf8.encode(payload))}';
}

/// Decodes a share code, returning null for any invalid shape.
///
/// The user only needs a single "invalid code" message, not the internal reason.
SharedPlaylist? decodePlaylistShare(String code) {
  final trimmed = code.trim();
  if (!trimmed.startsWith(kShareCodePrefix)) return null;
  try {
    final raw = utf8.decode(
      base64Url.decode(
        // Normalize in case padding was lost while copying through chat.
        base64Url.normalize(trimmed.substring(kShareCodePrefix.length)),
      ),
    );
    final json = jsonDecode(raw);
    if (json is! Map<String, dynamic>) return null;
    // Read only known fields. Unknown fields are ignored so codes from newer app
    // versions can still be imported here.
    final name = json['name'];
    final ids = json['ids'];
    if (name is! String || name.trim().isEmpty) return null;
    if (ids is! List || ids.length > kShareMaxPrayerIds) return null;

    final seen = <String>{};
    final prayerIds = <String>[];
    for (final id in ids) {
      if (id is! String || id.isEmpty || id.length > _kShareIdMaxLength) {
        return null;
      }
      if (seen.add(id)) prayerIds.add(id);
    }
    if (prayerIds.isEmpty) return null;

    final desc = json['desc'];
    return SharedPlaylist(
      name: _clip(name, kShareNameMaxLength)!,
      prayerIds: prayerIds,
      // A malformed description is dropped, not a reason to reject the set.
      description: desc is String
          ? _clip(desc, kShareDescriptionMaxLength)
          : null,
    );
  } on FormatException {
    return null;
  }
}

/// Trimmed and cut to [max] characters; null when nothing is left.
String? _clip(String? text, int max) {
  final t = text?.trim();
  if (t == null || t.isEmpty) return null;
  return t.length > max ? t.substring(0, max).trimRight() : t;
}
