import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/local/prefs_service.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_asset_image.dart';
import '../../shared/widgets/content_width.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/floral_corners.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../../shared/widgets/spotlight_tour.dart';
import '../../theme/app_colors.dart';
import 'day_part.dart';
import 'prayer_list_controller.dart';
import 'widgets/home_grid.dart';
import 'widgets/welcome_sheet.dart';

/// The home screen: the practice hero and the user's pinned tiles.
class PrayerListScreen extends ConsumerStatefulWidget {
  const PrayerListScreen({super.key});

  @override
  ConsumerState<PrayerListScreen> createState() => _PrayerListScreenState();
}

class _PrayerListScreenState extends ConsumerState<PrayerListScreen> {
  final _tourKeys = HomeTourKeys();

  /// The first-launch tour: a welcome, then the home screen top to bottom.
  /// Titles reuse the labels already on screen, so a card names what it lights.
  List<TourStep> _tourSteps(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return [
      TourStep(
        title: l10n.welcomeTitle,
        body: l10n.tourWelcomeBody,
        extra: const TourLanguagePicker(),
      ),
      TourStep(
        target: _tourKeys.goal,
        title: l10n.homeTodayGoal,
        body: l10n.tourGoalBody,
      ),
      TourStep(
        target: _tourKeys.shortcuts,
        title: l10n.homeQuickAccess,
        body: l10n.tourShortcutsBody,
      ),
      TourStep(
        target: _tourKeys.recommended,
        title: l10n.homeRecommendedTitle,
        body: l10n.tourRecommendedBody,
      ),
      TourStep(
        target: tourStartButtonKey,
        circular: true,
        title: l10n.navStart,
        body: l10n.tourStartBody,
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    homeTourReplayRequest.addListener(_replayTourIfAsked);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // Asked for from About while this screen was not in the tree.
      _replayTourIfAsked();
      final freshInstall = await showWelcomeIfNeeded(
        context,
        ref,
        tourSteps: _tourSteps,
      );
      if (!mounted) return;
      // A goal is the one setting worth asking for up front: the home ring and
      // the reminders both hang off it, and nothing else on the page means
      // anything until it exists. Offered once, after the welcome sheet, and
      // only to someone who just installed — an updating user already has
      // their own habit. The page itself can be skipped.
      final prefs = ref.read(prefsServiceProvider);
      if (!freshInstall || prefs.getGoalPromptSeen()) return;
      unawaited(prefs.setGoalPromptSeen(true));
      if (context.mounted) unawaited(context.push('/settings/goal?first=1'));
    });
  }

  @override
  void dispose() {
    homeTourReplayRequest.removeListener(_replayTourIfAsked);
    super.dispose();
  }

  /// Runs the tour again without its welcome card, which is for a first
  /// launch: the language was chosen long ago.
  void _replayTourIfAsked() {
    if (!homeTourReplayRequest.value || !mounted) return;
    homeTourReplayRequest.value = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showSpotlightTour(
        context,
        steps: (context) => _tourSteps(context).skip(1).toList(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Home always uses the complete collection. Search state belongs to the
    // Prayers destination and must not silently filter this dashboard.
    final prayersAsync = ref.watch(prayerListControllerProvider);
    final lastRead = ref.watch(lastReadPrayerProvider).value;

    // The artwork leaves the header room to breathe above the emblem, which on
    // a phone is exactly what the status bar supplies. Desktop and web have no
    // inset, so the emblem ended up against the window edge and under the
    // corner ornament; make up whatever the platform does not give.
    const headerTopRoom = 24.0;
    final extraTop = (headerTopRoom - MediaQuery.paddingOf(context).top).clamp(
      0.0,
      headerTopRoom,
    );

    // Read when the page builds: coming back to home picks up a new part of
    // the day, and nobody watches the header across a boundary.
    final dayPart = DayPart.of(DateTime.now());
    final greeting = dayPart.greeting(l10n);
    final theme = Theme.of(context);
    final greetingStyle = theme.textTheme.titleMedium?.copyWith(
      fontSize: 20,
      fontWeight: FontWeight.w600,
    );
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    // The two lines' combined height, at the user's text scale.
    double lineHeight(TextStyle? style) {
      final painter = TextPainter(
        text: TextSpan(text: greeting, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      final height = painter.height;
      painter.dispose();
      return height;
    }

    final textHeight = lineHeight(greetingStyle) + lineHeight(subtitleStyle);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 90 + extraTop,
        centerTitle: false,
        // The header lives entirely in `title` so it can sit inside the same
        // width cap as the body. Split across `title` and `actions` it stretched
        // to the window edges on a wide screen, leaving the greeting and the
        // bell floating far from the content column and under the corner
        // ornament.
        titleSpacing: 0,
        automaticallyImplyLeading: false,
        // The same head piece the settings pages are framed with. Its default
        // size already fits this bar (90 plus the status bar, or plus
        // `headerTopRoom` where there is none), so nothing is passed.
        flexibleSpace: const FloralCorners.head(top: -13, horizontal: -8),
        title: ContentWidth(
          maxWidth: ContentWidth.gridWidth,
          fillHeight: false,
          child: Padding(
            // Matches HomeGrid's own horizontal padding so the emblem and the
            // bell line up with the cards below them.
            padding: EdgeInsets.only(left: 20, right: 20, top: extraTop),
            child: Row(
              key: const ValueKey('home_header'),
              children: [
                // Exactly as tall as the two lines beside it, so the
                // lotus's top meets the greeting's and its foot the
                // subtitle's. Measured rather than fitted with
                // IntrinsicHeight, which would ask the image for its
                // natural height and grow the row to it.
                SizedBox(
                  height: textHeight,
                  width: textHeight * 352 / 227,
                  child: const AppAssetImage(
                    'assets/images/home/golden_watercolor_lotus.png',
                    fit: BoxFit.contain,
                    cacheWidth: 260,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        greeting,
                        key: const ValueKey('home_greeting'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: greetingStyle,
                      ),
                      Text(
                        dayPart.subtitle(l10n),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: subtitleStyle,
                      ),
                    ],
                  ),
                ),
                // IconButton(
                //   key: const ValueKey('home_notifications'),
                //   icon: Stack(
                //     clipBehavior: Clip.none,
                //     children: [
                //       const Icon(Icons.notifications_none_rounded, size: 32),
                //       Positioned(
                //         right: 0,
                //         top: 0,
                //         child: Container(
                //           width: 8,
                //           height: 8,
                //           decoration: BoxDecoration(
                //             color: Theme.of(context).colorScheme.secondary,
                //             shape: BoxShape.circle,
                //             boxShadow: [
                //               BoxShadow(
                //                 color: Theme.of(
                //                   context,
                //                 ).colorScheme.secondary.withValues(alpha: 0.36),
                //                 blurRadius: 6,
                //               ),
                //             ],
                //           ),
                //         ),
                //       ),
                //     ],
                //   ),
                //   tooltip: l10n.homeNotifications,
                //   onPressed: () => context.go('/settings'),
                // ),
              ],
            ),
          ),
        ),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: Theme.of(context).brightness == Brightness.dark
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(context).colorScheme.surface,
                    Theme.of(context).scaffoldBackgroundColor,
                  ],
                )
              : const RadialGradient(
                  center: Alignment(0, -0.78),
                  radius: 1.15,
                  colors: [AppColors.creamLight, AppColors.cream],
                ),
        ),
        child: ContentWidth(
          maxWidth: ContentWidth.gridWidth,
          child: prayersAsync.when(
            skipLoadingOnReload: true,
            loading: () => const LoadingIndicator(),
            error: (e, _) => EmptyState(
              icon: Icons.error_outline,
              message: l10n.prayerLoadError,
              detail: '$e',
            ),
            data: (sections) {
              if (sections.isEmpty) {
                return EmptyState(
                  icon: Icons.menu_book_outlined,
                  message: l10n.prayerListEmpty,
                );
              }
              return HomeGrid(
                sections: sections,
                tourKeys: _tourKeys,
                onStart: () => context.push('/start'),
                onGoal: () => context.push('/settings/goal'),
                lastReadTitle: lastRead?.title,
                onResume: lastRead == null
                    ? null
                    : () => context.push('/prayer/${lastRead.id}?resume=1'),
              );
            },
          ),
        ),
      ),
    );
  }
}
