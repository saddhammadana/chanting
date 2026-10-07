import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_asset_image.dart';
import '../../../shared/widgets/gold_play_button.dart';
import '../../../shared/widgets/golden_pill_button.dart';
import '../../../theme/dashboard_tokens.dart';
import '../prayer_list_controller.dart' show SectionPrayers;
import 'dashboard_parts.dart';

/// "Continue reading" card: the last prayer opened, with a gold play button.
class ContinueCard extends StatelessWidget {
  const ContinueCard({super.key, required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    return DashboardInkCard(
      decoration: illuminatedCardDecoration(theme),
      radius: 18,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: Colors.white.withValues(alpha: 0.56)),
        ),
        child: Row(
          children: [
            const _AssetIconWell(
              asset: 'assets/images/home/golden_open_book.png',
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.resumeReading,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.secondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const GoldPlayButton(),
          ],
        ),
      ),
    );
  }
}

/// Today's recommended prayer, over a faded illustration.
class RecommendedPrayerCard extends StatelessWidget {
  const RecommendedPrayerCard({
    super.key,
    required this.title,
    required this.onTap,
    this.description,
    this.durationMinutes,
  });

  final String title;

  /// The prayer's own summary from the data, shown under the title. Without
  /// one the card falls back to a line that fits any prayer.
  final String? description;
  final int? durationMinutes;
  final VoidCallback onTap;

  // The illustration is kept small and faded so it stays behind the text.
  static const _artShare = 0.40;
  static const _artMaxWidth = 200.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final dark = theme.brightness == Brightness.dark;
    // Duration is shown only when the record has one; it is never guessed.
    final summary = (description?.trim().isNotEmpty ?? false)
        ? description!.trim()
        : l10n.homeRecommendedDescription;
    final subtitle = durationMinutes == null
        ? summary
        : '$summary • ${l10n.meditationMinutes(durationMinutes!)}';

    return DashboardInkCard(
      decoration: illuminatedCardDecoration(theme, glow: 0.2),
      radius: 18,
      inkKey: const ValueKey('home_recommended_prayer'),
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final artWidth = (constraints.maxWidth * _artShare).clamp(
            0.0,
            _artMaxWidth,
          );
          return Container(
            constraints: const BoxConstraints(minHeight: 150),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              border: Border.all(
                color: Colors.white.withValues(alpha: dark ? 0.04 : 0.56),
              ),
            ),
            child: Stack(
              alignment: AlignmentDirectional.centerStart,
              children: [
                Positioned(
                  right: 8,
                  top: -4,
                  bottom: -4,
                  width: artWidth,
                  child: Opacity(
                    opacity: dark ? 0.65 : 0.75,
                    child: const AppAssetImage(
                      'assets/images/home/golden_lotus_book_with_ethereal_clouds.png',
                      fit: BoxFit.contain,
                      alignment: Alignment.centerRight,
                    ),
                  ),
                ),
                Padding(
                  // Clear of the illustration: a prayer's description is a
                  // full sentence, and run under the book it was unreadable.
                  padding: EdgeInsets.fromLTRB(20, 16, artWidth + 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 13,
                          color: scheme.onSurface,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      LayoutBuilder(
                        builder: (context, c) =>
                            LotusDivider(width: c.maxWidth.clamp(0.0, 168.0)),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: onTap,
                        style: goldOutlinedButtonStyle(theme),
                        child: Text(l10n.homeOpenPrayer),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// One category as a row card: icon, title, chevron. Used by the
/// all-categories list.
class CategoryCard extends StatelessWidget {
  const CategoryCard({
    super.key,
    required this.entry,
    required this.icon,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });

  final SectionPrayers entry;
  final IconData icon;
  final VoidCallback onTap;

  /// Second line under the title, the prayer count.
  final String? subtitle;

  /// Sits after the chevron, for the all-categories list's row menu.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => GoldenRowCard(
    title: entry.section.title,
    icon: icon,
    onTap: onTap,
    subtitle: subtitle,
    trailing: trailing,
  );
}

/// The row [CategoryCard] is drawn as: a gold icon, a title over an optional
/// second line, a chevron. Its own widget so a list of something other than
/// categories (saved prayers) is the same row rather than a lookalike.
class GoldenRowCard extends StatelessWidget {
  const GoldenRowCard({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final String? subtitle;

  /// Sits after the chevron.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      // A row with a subtitle may need to grow for a long title.
      height: subtitle == null ? 70 : null,
      constraints: const BoxConstraints(minHeight: 70),
      child: DashboardInkCard(
        decoration: illuminatedCardDecoration(theme, radius: 16, glow: 0.11),
        radius: 16,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 10, trailing == null ? 12 : 0, 10),
          child: Row(
            children: [
              GoldenIcon(icon: icon, size: 28),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurface,
                size: 22,
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// Round cream well holding a small piece of artwork.
class _AssetIconWell extends StatelessWidget {
  const _AssetIconWell({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 68,
      height: 68,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [
            scheme.surface,
            scheme.secondaryContainer.withValues(alpha: 0.48),
          ],
        ),
        shape: BoxShape.circle,
        border: Border.all(color: scheme.secondary.withValues(alpha: 0.44)),
        boxShadow: [DashboardTokens.warmShadow(0.07, blur: 3, dy: 2)],
      ),
      child: AppAssetImage(asset, fit: BoxFit.contain),
    );
  }
}
