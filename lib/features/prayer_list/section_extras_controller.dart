import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/prefs_service.dart';
import '../../data/models/prayer.dart';

/// Prayers **added by the user to shipped sections**: `{sectionId: [prayerId, ...]}`.
///
/// This supports "I chant one more prayer after morning chanting every day"
/// without forking the entire shipped section.
///
/// The alternative is creating a playlist from the section and editing that, but
/// it becomes a fork. Future shipped fixes would not reach the user's copy. This
/// keeps the section fully shipped and appends user additions only at display time.
///
/// Stored in prefs key `section_extras` as `List<String>` values shaped like
/// `"<sectionId>:<prayerId>"`, mirroring `pinned`. Both ids are Latin slugs and
/// cannot contain `:`. List order is append order.
class SectionExtrasController extends Notifier<Map<String, List<String>>> {
  @override
  Map<String, List<String>> build() {
    final out = <String, List<String>>{};
    for (final raw in ref.read(prefsServiceProvider).getSectionExtrasRaw()) {
      final i = raw.indexOf(':');
      // Drop malformed future values silently; prefs must not break section pages.
      if (i <= 0 || i == raw.length - 1) continue;
      out.putIfAbsent(raw.substring(0, i), () => []).add(raw.substring(i + 1));
    }
    return out;
  }

  bool contains(String sectionId, String prayerId) =>
      state[sectionId]?.contains(prayerId) ?? false;

  void add(String sectionId, String prayerId) {
    if (contains(sectionId, prayerId)) return;
    state = {
      ...state,
      sectionId: [...?state[sectionId], prayerId],
    };
    _persist();
  }

  void remove(String sectionId, String prayerId) {
    final list = state[sectionId];
    if (list == null || !list.contains(prayerId)) return;
    final next = [...list.where((e) => e != prayerId)];
    final map = {...state};
    // Remove sections with no extras instead of persisting empty lists.
    if (next.isEmpty) {
      map.remove(sectionId);
    } else {
      map[sectionId] = next;
    }
    state = map;
    _persist();
  }

  void _persist() => ref.read(prefsServiceProvider).setSectionExtrasRaw([
    for (final entry in state.entries)
      for (final id in entry.value) '${entry.key}:$id',
  ]);
}

final sectionExtrasProvider =
    NotifierProvider<SectionExtrasController, Map<String, List<String>>>(
      SectionExtrasController.new,
    );

/// Append user-added prayers to a section list. Pure and directly testable.
///
/// Two rules must hold:
/// - **Skip ids that cannot be found.** The prayer may have been removed from an
///   edition or may be absent in the current language. Like pins, skip silently
///   but keep the user's saved value because another language may have it.
/// - **Skip ids already present in the section.** If a future shipped edition
///   adds the same prayer to the section, it must not appear twice.
List<Prayer> withExtras(
  List<Prayer> sectionPrayers,
  List<String>? extraIds,
  Map<String, Prayer> byId,
) {
  if (extraIds == null || extraIds.isEmpty) return sectionPrayers;
  final present = {for (final p in sectionPrayers) p.id};
  return [
    ...sectionPrayers,
    for (final id in extraIds)
      if (!present.contains(id) && byId[id] != null) byId[id]!,
  ];
}
