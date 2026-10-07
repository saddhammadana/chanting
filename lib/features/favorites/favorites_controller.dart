import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/prefs_service.dart';
import '../../data/models/prayer.dart';
import '../../features/prayer_list/prayer_list_controller.dart';

/// Favorite prayer ids, persisted to SharedPreferences on every change.
class FavoritesController extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    return ref.read(prefsServiceProvider).getFavoriteIds().toSet();
  }

  void toggle(String prayerId) {
    final next = {...state};
    if (!next.remove(prayerId)) {
      next.add(prayerId);
    }
    state = next;
    ref.read(prefsServiceProvider).setFavoriteIds(next.toList());
  }

  bool isFavorite(String prayerId) => state.contains(prayerId);
}

final favoritesControllerProvider =
    NotifierProvider<FavoritesController, Set<String>>(FavoritesController.new);

/// Favorite prayers in original content order.
///
/// autoDispose because this watches content providers; see prayerRepositoryProvider.
final favoritePrayersProvider = FutureProvider.autoDispose<List<Prayer>>((
  ref,
) async {
  final ids = ref.watch(favoritesControllerProvider);
  final all = await ref.watch(prayerRepositoryProvider).getAllPrayers();
  return all.where((p) => ids.contains(p.id)).toList();
});
