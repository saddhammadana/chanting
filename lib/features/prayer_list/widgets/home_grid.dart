import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/pinned_ref.dart';
import '../../../data/models/prayer.dart';
import '../../../l10n/app_localizations.dart';
import '../../playlists/playlists_controller.dart';
import '../../settings/settings_controller.dart';
import '../../stats/practice_log_controller.dart';
import '../daily_recommendation.dart';
import '../day_part.dart';
import '../pinned_controller.dart';
import '../prayer_list_controller.dart' show SectionPrayers;
import '../section_icon_overrides.dart';
import 'dashboard_parts.dart';
import 'home_cards.dart';
import 'practice_hero.dart';

/// The home widgets the first-launch tour stops at. Owned by the screen that
/// runs the tour and handed down, so the keys live exactly as long as it does.
class HomeTourKeys {
  final goal = GlobalKey(debugLabel: 'tour_goal');
  final shortcuts = GlobalKey(debugLabel: 'tour_shortcuts');
  final recommended = GlobalKey(debugLabel: 'tour_recommended');
}

/// The home dashboard keeps every established entry point while giving daily
/// practice, continuity, and user pins a clearer hierarchy.
class HomeGrid extends ConsumerWidget {
  const HomeGrid({
    super.key,
    required this.sections,
    required this.onStart,
    required this.onGoal,
    this.lastReadTitle,
    this.onResume,
    this.tourKeys,
  });

  final List<SectionPrayers> sections;
  final VoidCallback onStart;
  final VoidCallback onGoal;
  final String? lastReadTitle;
  final VoidCallback? onResume;

  /// Marks the stops of the first-launch tour; see `showWelcomeIfNeeded`.
  final HomeTourKeys? tourKeys;

  static const _morningId = 'tham-wat-chao';
  static const _eveningId = 'tham-wat-yen';
  static const _mettaPrayerId = 'mettapharana';

  /// Ids the grid always draws in their own place, so a pin on one of them
  /// must not add a second tile.
  static const _fixedDestinations = {_morningId, _eveningId, _mettaPrayerId};

  SectionPrayers? _section(String id) =>
      sections.where((e) => e.section.id == id).firstOrNull;

  Prayer? _prayer(String id) =>
      sections.expand((e) => e.prayers).where((p) => p.id == id).firstOrNull;

  Widget? _pinBox(BuildContext context, WidgetRef ref, PinnedRef pin) {
    final l10n = AppLocalizations.of(context);
    switch (pin.type) {
      case PinnedType.section:
        final entry = _section(pin.id);
        if (entry == null) return null;
        return DashboardTile(
          icon: resolvedSectionIcon(
            entry.section,
            ref.watch(sectionIconOverridesProvider),
          ),
          label: entry.section.title,
          subtitle: l10n.playlistPrayerCount(entry.prayers.length),
          compact: true,
          onTap: () => context.push('/category/${entry.section.id}'),
        );
      case PinnedType.playlist:
        final playlist = ref
            .watch(playlistsControllerProvider)
            .where((e) => e.id == pin.id)
            .firstOrNull;
        if (playlist == null) return null;
        return DashboardTile(
          icon: Icons.playlist_play_outlined,
          label: playlist.name,
          subtitle: l10n.playlistPrayerCount(playlist.prayerIds.length),
          compact: true,
          onTap: () => context.push('/playlists/${playlist.id}'),
        );
      case PinnedType.prayer:
        final prayer = _prayer(pin.id);
        if (prayer == null) return null;
        return DashboardTile(
          icon: Icons.bookmark_outline,
          label: prayer.title,
          compact: true,
          onTap: () => context.push('/prayer/${prayer.id}'),
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final pins = ref.watch(pinnedControllerProvider);
    final iconOverrides = ref.watch(sectionIconOverridesProvider);
    bool isPinned(PinnedType type, String id) =>
        pins.any((pin) => pin.type == type && pin.id == id);
    // Read when the page builds, like the greeting: a new day brings the next
    // prayer in the rotation.
    final recommendedPrayer = recommendedPrayerOn(DateTime.now(), [
      for (final id in kRecommendationSectionIds) ...?_section(id)?.prayers,
    ]);

    return ListView(
      key: const ValueKey('home_scroll'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        KeyedSubtree(
          key: tourKeys?.goal,
          child: PracticeHero(
            key: const ValueKey('home_practice_hero'),
            // Read when the page builds, like the header's greeting.
            title:
                _section(
                  DayPart.of(DateTime.now()).serviceSectionId,
                )?.section.title ??
                l10n.homePracticeTitle,
            minutesToday: ref.watch(practiceMinutesTodayProvider),
            goalMinutes: ref.watch(
              settingsControllerProvider.select((s) => s.practiceGoalMinutes),
            ),
            onStart: onStart,
            onGoal: onGoal,
          ),
        ),
        const SizedBox(height: 24),
        DashboardSectionTitle(
          l10n.homeQuickAccess,
          actionLabel: l10n.homeViewAll,
          actionKey: const ValueKey('home_all_categories'),
          onAction: () => context.push('/categories'),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          key: tourKeys?.shortcuts,
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 720
                ? 6
                : constraints.maxWidth >= 340
                ? 4
                : 2;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: columns,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: columns >= 4 ? 0.94 : 1.35,
              children: [
                for (final (id, key) in const [
                  (_morningId, 'home_morning'),
                  (_eveningId, 'home_evening'),
                ])
                  if (_section(id) case final entry?
                      when isPinned(PinnedType.section, id))
                    DashboardTile(
                      key: ValueKey(key),
                      icon: resolvedSectionIcon(entry.section, iconOverrides),
                      label: entry.section.title,
                      compact: true,
                      onTap: () => context.push('/category/$id'),
                    ),
                DashboardTile(
                  // This tile is the app's only way into the meditation timer,
                  // so it is labelled and drawn as that screen. It used to say
                  // "before bed", which named no content the app has.
                  key: const ValueKey('home_meditation'),
                  icon: Icons.self_improvement,
                  label: l10n.meditationTitle,
                  compact: true,
                  onTap: () => context.push('/meditation'),
                ),
                DashboardTile(
                  key: const ValueKey('home_metta'),
                  icon: Icons.volunteer_activism_outlined,
                  label: l10n.homeMetta,
                  compact: true,
                  onTap: () => context.push('/prayer/$_mettaPrayerId'),
                ),
                for (final pin in pins)
                  if (!_fixedDestinations.contains(pin.id))
                    ?_pinBox(context, ref, pin),
              ],
            );
          },
        ),
        if (lastReadTitle != null && onResume != null) ...[
          const SizedBox(height: 24),
          DashboardSectionTitle(l10n.homeContinueTitle),
          const SizedBox(height: 10),
          ContinueCard(title: lastReadTitle!, onTap: onResume!),
        ],
        if (recommendedPrayer != null) ...[
          const SizedBox(height: 24),
          DashboardSectionTitle(l10n.homeRecommendedTitle),
          const SizedBox(height: 10),
          RecommendedPrayerCard(
            key: tourKeys?.recommended,
            title: recommendedPrayer.title,
            description: recommendedPrayer.description,
            durationMinutes: recommendedPrayer.durationMinutes,
            onTap: () => context.push('/prayer/${recommendedPrayer.id}'),
          ),
        ],
      ],
    );
  }
}
