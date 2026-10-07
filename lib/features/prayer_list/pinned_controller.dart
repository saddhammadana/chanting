import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/prefs_service.dart';
import '../../data/models/pinned_ref.dart';

/// Default pins for existing users seeing this feature for the first time.
///
/// Before pins, the home screen showed every section card. After the update,
/// sections move behind "all sections"; without defaults, existing users would
/// feel daily content disappeared. These common daily sections are pinned but
/// can be removed by the user.
const kDefaultPins = [
  PinnedRef(PinnedType.section, 'tham-wat-chao'),
  PinnedRef(PinnedType.section, 'tham-wat-yen'),
];

/// User-pinned home items, in pinning order.
///
/// **New pins are always appended.** The order is therefore user-created and good
/// enough without adding home-screen drag sorting yet.
class PinnedController extends Notifier<List<PinnedRef>> {
  @override
  List<PinnedRef> build() {
    final raw = ref.read(prefsServiceProvider).getPinnedRaw();
    // Missing key means an existing user just updated, so add default pins.
    // `[]` is different: the user had pins and removed them all.
    if (raw == null) return kDefaultPins;
    // Drop malformed or unknown future values silently; prefs from a newer
    // version must not break the whole home screen.
    return [for (final s in raw) ?PinnedRef.tryParse(s)];
  }

  bool isPinned(PinnedRef pin) => state.contains(pin);

  /// Toggle pin state and return whether the item is pinned after the action, so
  /// UI can choose snackbar text without reading state again.
  bool toggle(PinnedRef pin) {
    final pinned = state.contains(pin);
    state = pinned ? [...state.where((e) => e != pin)] : [...state, pin];
    _persist();
    return !pinned;
  }

  void remove(PinnedRef pin) {
    if (!state.contains(pin)) return;
    state = [...state.where((e) => e != pin)];
    _persist();
  }

  void _persist() => ref.read(prefsServiceProvider).setPinnedRaw([
    for (final p in state) p.encode(),
  ]);
}

final pinnedControllerProvider =
    NotifierProvider<PinnedController, List<PinnedRef>>(PinnedController.new);
