import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_asset_image.dart';
import '../../../shared/widgets/gold_ring.dart';
import '../../../shared/widgets/gold_sparkle.dart';
import '../../../shared/widgets/golden_pill_button.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/dashboard_tokens.dart';
import 'dashboard_parts.dart';

/// Top card of the home dashboard: today's goal, the start button
/// and the daily-goal ring.
class PracticeHero extends StatelessWidget {
  const PracticeHero({
    super.key,
    required this.title,
    required this.minutesToday,
    required this.goalMinutes,
    required this.onStart,
    required this.onGoal,
  });

  /// What today's goal is right now: the service for this part of the day.
  final String title;
  final int minutesToday;
  final int goalMinutes;
  final VoidCallback onStart;

  /// Tapping the ring opens the page its goal is set on.
  final VoidCallback onGoal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final dark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? [scheme.surface, scheme.secondaryContainer]
              : [AppColors.creamLight, AppColors.creamField],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: dark
              ? scheme.secondary.withValues(alpha: 0.48)
              : DashboardTokens.cardEdge,
        ),
        // The artwork shades this card with warmth only; a grey layer read
        // as a ledge under it in light. Dark keeps one, under the gold glow.
        boxShadow: dark
            ? [
                BoxShadow(
                  color: scheme.secondary.withValues(alpha: 0.10),
                  blurRadius: 32,
                  spreadRadius: 1,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: scheme.onSurface.withValues(alpha: 0.22),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : [DashboardTokens.warmShadow(0.11)],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -14,
            bottom: -25,
            child: Opacity(
              opacity: dark ? 0.12 : 0.18,
              child: const AppAssetImage(
                'assets/images/home/elegant_cream_gold_lotus_emblem.png',
                width: 126,
                height: 112,
                fit: BoxFit.contain,
              ),
            ),
          ),
          // `Positioned.fill`, not a bare `Align`: this card is a `ListView`
          // child, so the Stack's height is unbounded and an `Align` with no
          // height factor shrink-wraps its star rather than filling. The y in
          // these alignments was ignored for that reason and all of them sat
          // in a row along the top edge whatever they said. Filling hands them
          // the Stack's real size — the one the text and the ring settle on.
          //
          // The ring is nearly as tall as the card at every width, so the room
          // around it is the strips above and below rather than the sides.
          // Each of these clears the ring and its glow by 20px or more, and
          // stays off the lotus watermark in the bottom-right corner, at both
          // a wide window and a 360pt phone — the two shapes move differently,
          // since the ring is capped at 138px while the card keeps growing.
          //
          // Scattered, not mirrored: the card is not symmetric to begin with
          // (text left, ring right). Both weights appear — traced stars belong
          // to the card's ornament, solid ones read as light caught nearby.
          ...const [
            (
              align: Alignment(0.16, -0.66),
              size: 9.0,
              style: SparkleStyle.filled,
            ),
            (
              align: Alignment(0.32, -0.92),
              size: 6.0,
              style: SparkleStyle.filled,
            ),
            (
              align: Alignment(0.78, -0.80),
              size: 12.0,
              style: SparkleStyle.outlined,
            ),
            (
              align: Alignment(0.22, 0.77),
              size: 7.0,
              style: SparkleStyle.outlined,
            ),
          ].map(
            (s) => Positioned.fill(
              child: Align(
                alignment: s.align,
                child: GoldSparkle(size: s.size, style: s.style),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.homeTodayGoal,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const LotusDivider(),
                      const SizedBox(height: 16),
                      GoldenPillButton(
                        key: const ValueKey('home_start_chanting'),
                        label: l10n.homeStartChanting,
                        onPressed: onStart,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 4,
                  child: _PracticeProgressRing(
                    minutes: minutesToday,
                    goalMinutes: goalMinutes,
                    onTap: onGoal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Daily-goal ring from the home dashboard artwork: a pale band with a gold
/// arc for the minutes chanted today, a lotus straddling its top edge, and the
/// count inside.
class _PracticeProgressRing extends StatelessWidget {
  const _PracticeProgressRing({
    required this.minutes,
    required this.goalMinutes,
    required this.onTap,
  });

  final int minutes;
  final int goalMinutes;
  final VoidCallback onTap;

  static const _maxDiameter = 138.0;
  // Type sizes as fractions of the diameter, measured off the artwork.
  static const _doneSize = 0.327;
  static const _goalSize = 0.21;
  static const _unitSize = 0.103;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final dark = theme.brightness == Brightness.dark;
    final progress = goalMinutes <= 0
        ? 0.0
        : (minutes / goalMinutes).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final size = width.isFinite && width < _maxDiameter
            ? width
            : _maxDiameter;

        return Semantics(
          button: true,
          label: l10n.homeGoalRing(minutes, goalMinutes),
          child: GoldRing(
            size: size,
            progress: progress,
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: SizedBox.square(
                  dimension: size,
                  child: ExcludeSemantics(
                    // The artwork sits the count a little below the middle,
                    // balancing the lotus that crowns the ring.
                    child: Padding(
                      padding: EdgeInsets.only(top: size * 0.09),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '$minutes',
                                  style: TextStyle(
                                    fontSize: size * _doneSize,
                                    fontWeight: FontWeight.w400,
                                    color: dark
                                        ? scheme.secondary
                                        : AppColors.goldDark,
                                  ),
                                ),
                                TextSpan(
                                  text: ' / $goalMinutes',
                                  style: TextStyle(
                                    fontSize: size * _goalSize,
                                    fontWeight: FontWeight.w400,
                                    color: dark
                                        ? scheme.onSurfaceVariant
                                        : AppColors.goalInk,
                                  ),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            style: theme.textTheme.displaySmall?.copyWith(
                              height: 1,
                              letterSpacing: 0,
                            ),
                          ),
                          SizedBox(height: size * 0.012),
                          Text(
                            l10n.homeGoalUnit,
                            maxLines: 1,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: size * _unitSize,
                              height: 1.1,
                              color: dark
                                  ? scheme.onSurfaceVariant
                                  : AppColors.brownDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
