import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/prefs_service.dart';
import '../../data/models/prayer.dart';
import '../../data/models/prayer_section.dart';
import '../../data/repositories/prayer_repository.dart';
import '../settings/settings_controller.dart';
import 'section_extras_controller.dart';

/// Shared repository for app features, bound to the selected prayer **edition**.
///
/// Content providers stay `autoDispose` so locale changes rebuild cleanly.
final prayerRepositoryProvider = Provider.autoDispose<PrayerRepository>((ref) {
  final uiLocale = ref.watch(
    settingsControllerProvider.select((s) => s.locale),
  );
  return PrayerRepository(
    languageCode: contentLanguageFor(uiLocale.resolve().languageCode),
  );
});

/// One section with its prayers; these values always travel together.
typedef SectionPrayers = ({PrayerSection section, List<Prayer> prayers});

/// All prayers grouped by section **in sections-file order**, loaded from assets
/// and reloaded when the edition changes.
class PrayerListController extends AsyncNotifier<List<SectionPrayers>> {
  @override
  Future<List<SectionPrayers>> build() async {
    // Watch so language changes create a new repository.
    final repo = ref.watch(prayerRepositoryProvider);
    final grouped = await repo.getPrayersByCategory();
    // Append user data here; the repository stays shipped content only.
    final extras = ref.watch(sectionExtrasProvider);
    final byId = {for (final p in await repo.getAllPrayers()) p.id: p};
    return [
      for (final s in await repo.getSections())
        (
          section: s,
          prayers: withExtras(grouped[s.id] ?? const [], extras[s.id], byId),
        ),
    ];
  }
}

final prayerListControllerProvider =
    AsyncNotifierProvider.autoDispose<
      PrayerListController,
      List<SectionPrayers>
    >(PrayerListController.new);

/// All unique prayers in section-defined order.
final allPrayersProvider = FutureProvider.autoDispose<List<Prayer>>(
  (ref) => ref.watch(prayerRepositoryProvider).getAllPrayers(),
);

/// Last-read prayer id. Detail saves it; list uses it for the continue card.
class LastReadController extends Notifier<String?> {
  @override
  String? build() => ref.read(prefsServiceProvider).getLastReadId();

  void set(String prayerId) {
    state = prayerId;
    ref.read(prefsServiceProvider).setLastReadId(prayerId);
  }
}

final lastReadControllerProvider =
    NotifierProvider<LastReadController, String?>(LastReadController.new);

/// Last-read full Prayer for the continue card.
final lastReadPrayerProvider = FutureProvider.autoDispose<Prayer?>((ref) async {
  final id = ref.watch(lastReadControllerProvider);
  if (id == null) return null;
  return ref.watch(prayerRepositoryProvider).getPrayerById(id);
});

/// Current prayer-list search query.
class SearchQueryController extends Notifier<String> {
  @override
  String build() => '';

  void set(String query) => state = query;
}

final searchQueryProvider = NotifierProvider<SearchQueryController, String>(
  SearchQueryController.new,
);

/// Up to four recent search terms, newest first.
class SearchHistoryController extends Notifier<List<String>> {
  static const _max = 4;

  @override
  List<String> build() => ref.read(prefsServiceProvider).getSearchHistory();

  void add(String query) {
    final q = query.trim();
    if (q.isEmpty) return;
    // Promote repeated terms instead of storing duplicates.
    final next = [q, ...state.where((e) => e != q)];
    state = next.length > _max ? next.sublist(0, _max) : next;
    ref.read(prefsServiceProvider).setSearchHistory(state);
  }

  void remove(String query) {
    state = state.where((e) => e != query).toList();
    ref.read(prefsServiceProvider).setSearchHistory(state);
  }
}

final searchHistoryProvider =
    NotifierProvider<SearchHistoryController, List<String>>(
      SearchHistoryController.new,
    );

/// Romanized Pali diacritics to base letters for search.
const _diacriticFolding = {
  'ā': 'a',
  'ī': 'i',
  'ū': 'u',
  'ñ': 'n',
  'ṃ': 'm',
  'ṅ': 'n',
  'ṇ': 'n',
  'ṭ': 't',
  'ḍ': 'd',
  'ḷ': 'l',
};

/// Normalize text for search by lowercasing and folding diacritics.
String foldForSearch(String s) {
  var out = s.toLowerCase();
  for (final entry in _diacriticFolding.entries) {
    out = out.replaceAll(entry.key, entry.value);
  }
  return out;
}

/// Prayer list filtered by query, searching title and content.
final filteredPrayersProvider =
    Provider.autoDispose<AsyncValue<List<SectionPrayers>>>((ref) {
      final query = foldForSearch(ref.watch(searchQueryProvider).trim());
      final sections = ref.watch(prayerListControllerProvider);
      if (query.isEmpty) return sections;
      return sections.whenData((list) {
        final filtered = <SectionPrayers>[];
        for (final entry in list) {
          final matches = entry.prayers
              .where(
                (p) =>
                    foldForSearch(p.title).contains(query) ||
                    foldForSearch(p.text).contains(query),
              )
              .toList();
          if (matches.isNotEmpty) {
            filtered.add((section: entry.section, prayers: matches));
          }
        }
        return filtered;
      });
    });
