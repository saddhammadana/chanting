import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/prayer.dart';
import '../../data/models/prayer_section.dart';
import '../../data/repositories/prayer_repository.dart';
import '../prayer_list/prayer_list_controller.dart';
import '../prayer_list/section_extras_controller.dart';

// Content providers are autoDispose; see prayerRepositoryProvider for why this
// avoids "setState during build" crashes after locale changes.

/// One prayer by id, or null when not found.
final prayerDetailProvider = FutureProvider.autoDispose.family<Prayer?, String>(
  (ref, id) {
    return ref.watch(prayerRepositoryProvider).getPrayerById(id);
  },
);

/// Reference point for continuous reading: current prayer plus source category.
///
/// [sectionId] is needed because one prayer can appear in multiple categories.
/// Knowing only `prayerId` cannot tell which category order to follow. Null means
/// no source category was supplied, such as deep links, resume cards, or
/// playlists; fall back to the first containing category.
typedef ReadingContext = ({String prayerId, String? sectionId});

/// Category whose order should be used for [ctx].
Future<PrayerSection?> resolveSection(
  PrayerRepository repo,
  ReadingContext ctx,
) async {
  final id = ctx.sectionId;
  if (id != null) {
    final section = await repo.getSectionById(id);
    // Missing category from an old link falls back like an unspecified category.
    if (section != null && section.prayerIds.contains(ctx.prayerId)) {
      return section;
    }
  }
  final containing = await repo.sectionsContaining(ctx.prayerId);
  return containing.isEmpty ? null : containing.first;
}

/// Next or previous category in category order.
///
/// Used by cards and cross-category gestures in continuous mode. [id] is carried
/// so opening the new category can pass `?section=`; otherwise a first prayer that
/// belongs to multiple categories could resolve to the wrong category order.
typedef AdjacentSection = ({String id, String name, String firstPrayerId});

Future<AdjacentSection?> _adjacent(
  PrayerRepository repo,
  ReadingContext ctx,
  int step,
) async {
  final current = await resolveSection(repo, ctx);
  if (current == null) return null;
  final sections = await repo.getSections();
  final i = sections.indexWhere((s) => s.id == current.id);
  final j = i + step;
  if (i == -1 || j < 0 || j >= sections.length) return null;
  final target = sections[j];
  if (target.prayerIds.isEmpty) return null;
  return (
    id: target.id,
    name: target.title,
    firstPrayerId: target.prayerIds.first,
  );
}

final nextCategoryProvider = FutureProvider.autoDispose
    .family<AdjacentSection?, ReadingContext>(
      (ref, ctx) => _adjacent(ref.watch(prayerRepositoryProvider), ctx, 1),
    );

/// Opens at the first prayer of the previous category, matching next-category flow.
final prevCategoryProvider = FutureProvider.autoDispose
    .family<AdjacentSection?, ReadingContext>(
      (ref, ctx) => _adjacent(ref.watch(prayerRepositoryProvider), ctx, -1),
    );

/// Cross-page flag for auto-scroll handoff.
///
/// When auto-scroll reaches the end and opens the next prayer, the new prayer
/// starts scrolling immediately even if auto-start is disabled.
class AutoScrollResume extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final autoScrollResumeProvider = NotifierProvider<AutoScrollResume, bool>(
  AutoScrollResume.new,
);

/// All prayers in the active category order, used by continuous reading.
final categoryPrayersProvider = FutureProvider.autoDispose
    .family<List<Prayer>, ReadingContext>((ref, ctx) async {
      final repo = ref.watch(prayerRepositoryProvider);
      final section = await resolveSection(repo, ctx);
      if (section == null) return const [];
      // Include user-added category extras so continuous reading matches the
      // category list the user sees.
      final byId = {for (final p in await repo.getAllPrayers()) p.id: p};
      return withExtras(
        await repo.prayersOfSection(section.id),
        ref.watch(sectionExtrasProvider)[section.id],
        byId,
      );
    });

/// Prayer position in continuous reading order.
///
/// Prev/next feed buttons and swipe navigation. Position is one-based for display;
/// 0 means not found.
typedef PrayerNeighbors = ({
  Prayer? prev,
  Prayer? next,
  int position,
  int total,
});

/// Previous and next prayers plus same-category position.
final prayerNeighborsProvider = FutureProvider.autoDispose
    .family<PrayerNeighbors, ReadingContext>((ref, ctx) async {
      final list = await ref.watch(categoryPrayersProvider(ctx).future);
      final i = list.indexWhere((p) => p.id == ctx.prayerId);
      if (i == -1) return (prev: null, next: null, position: 0, total: 0);
      return (
        prev: i > 0 ? list[i - 1] : null,
        next: i < list.length - 1 ? list[i + 1] : null,
        position: i + 1,
        total: list.length,
      );
    });

/// Currently read category, used for top-bar title and end-of-category messaging.
///
/// The old direct `prayer.category` approach no longer works once a prayer can be
/// in multiple categories. The visible title should be the category the user came
/// from, not an arbitrary category of the prayer.
final currentSectionProvider = FutureProvider.autoDispose
    .family<PrayerSection?, ReadingContext>(
      (ref, ctx) => resolveSection(ref.watch(prayerRepositoryProvider), ctx),
    );
