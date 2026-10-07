import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_asset_image.dart';
import '../../../shared/widgets/gold_ring.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/dashboard_tokens.dart';
import 'meditation_ornaments.dart';

// Both were written for this screen and then wanted by the goal page too, so
// they live in shared/ now. Re-exported to keep this screen's single import.
export '../../../shared/widgets/custom_minutes_dialog.dart';
export '../../../shared/widgets/duration_chip.dart';

/// A sitting's length in words: minutes under an hour, hours and minutes from
/// there, because nobody reads "330 minutes".
String meditationDurationLabel(AppLocalizations l10n, int minutes) {
  if (minutes < 60) return l10n.meditationMinutes(minutes);
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? l10n.durationHours(h) : l10n.durationHoursMinutes(h, m);
}

/// Maximum custom duration: the last value an hours wheel of 0–23 beside a
/// minutes wheel can spell. Not a judgement about how long to sit.
const kMeditationMaxMinutes = 23 * 60 + 59;

/// The timer's devotional focal point: the progress ring stays fully legible
/// while the supplied lotus-and-cloud artwork rests behind its lower edge.
class MeditationTimerHero extends StatelessWidget {
  const MeditationTimerHero({
    super.key,
    required this.size,
    required this.progress,
    required this.time,
    required this.unit,
    required this.done,
  });

  final double size;
  final double progress;
  final String time;
  final String unit;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final ornamentWidth = size * 0.70;

    return Center(
      child: SizedBox(
        width: size * 1.72,
        height: size * 1.23,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 0,
              bottom: 0,
              child: LotusTonalFade(
                child: AppAssetImage(
                  'assets/images/meditation/meditation_lotus_cloud.png',
                  width: ornamentWidth,
                  height: size * 0.46,
                  fit: BoxFit.contain,
                  alignment: Alignment.bottomLeft,
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Transform.flip(
                flipX: true,
                child: LotusTonalFade(
                  child: AppAssetImage(
                    'assets/images/meditation/meditation_lotus_cloud.png',
                    width: ornamentWidth,
                    height: size * 0.46,
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomLeft,
                  ),
                ),
              ),
            ),
            TimerSparkles(size: size),
            Positioned(
              top: size * 0.10,
              child: GoldRing(
                size: size,
                progress: progress,
                child: ExcludeSemantics(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        time,
                        style: theme.textTheme.displayLarge?.copyWith(
                          fontFamily: theme.textTheme.bodyLarge?.fontFamily,
                          fontSize: size * 0.25,
                          height: 1,
                          letterSpacing: 0,
                          fontWeight: FontWeight.w400,
                          color: dark ? scheme.secondary : AppColors.goldDark,
                        ),
                      ),
                      SizedBox(height: size * 0.02),
                      Text(
                        unit,
                        maxLines: 1,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          // Same fraction of the diameter as the home ring's unit.
                          fontSize: size * 0.103,
                          height: 1.1,
                          fontWeight: done ? FontWeight.w700 : FontWeight.w400,
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
          ],
        ),
      ),
    );
  }
}

/// The artwork's "sitting options" card: a heading over hairline-separated
/// rows.
class OptionsCard extends StatelessWidget {
  const OptionsCard({super.key, required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: dark ? scheme.surface : DashboardTokens.tileFaceTop,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: dark
              ? scheme.secondary.withValues(alpha: 0.34)
              : DashboardTokens.cardEdge,
        ),
        boxShadow: dark
            ? null
            : [DashboardTokens.warmShadow(0.08, blur: 3, dy: 2)],
      ),
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              AppLocalizations.of(context).meditationOptions,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: dark
                    ? scheme.secondary.withValues(alpha: 0.22)
                    : DashboardTokens.cardEdge.withValues(alpha: 0.82),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      indent: 8,
                      endIndent: 8,
                      color: scheme.outlineVariant,
                    ),
                  rows[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One row of [OptionsCard]: a gold glyph, a label, the current value, and a
/// chevron.
class OptionRow extends StatelessWidget {
  const OptionRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    return Semantics(
      button: true,
      label: '$label, $value',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.secondaryContainer.withValues(
                      alpha: dark ? 0.36 : 0.52,
                    ),
                    border: Border.all(
                      color: scheme.secondary.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: dark ? scheme.secondary : DashboardTokens.goldGlyph,
                  ),
                ),
                const SizedBox(width: 12),
                // Only the label may flex. A `Flexible` value takes a flex
                // share the way `Expanded` does, so it was handed half the free
                // space, underflowed it, and RenderFlex pushed the leftover
                // past the chevron — value and chevron floated mid-row instead
                // of sitting against the card edge as the artwork has them.
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  value,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
