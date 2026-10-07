import 'package:flutter/material.dart';

import '../../../data/models/prayer.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/gold_play_button.dart';
import '../../../theme/app_colors.dart';
import '../share_page_parts.dart';
import 'playlist_detail_stat.dart';

/// Soft gold fill behind small numerals and icons, per brightness.
Color _softGold(ThemeData theme) => theme.brightness == Brightness.dark
    ? AppColors.darkGoldSoft
    : AppColors.goldSoft;

/// One prayer: its place in the set, title, length when known and a line of
/// description, with play. Removing and reordering live on the edit page.
class PlaylistDetailPrayerRow extends StatelessWidget {
  const PlaylistDetailPrayerRow({
    super.key,
    required this.index,
    required this.prayer,
    required this.fallbackTitle,
    required this.onOpen,
  });

  final int index;
  final Prayer? prayer;
  final String fallbackTitle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    // Flat: a column of eight raised cards read as a stack of shadows.
    final decoration = shareCardDecoration(theme).copyWith(boxShadow: const []);
    final radius = decoration.borderRadius! as BorderRadius;
    final minutes = prayer?.durationMinutes;
    final description = prayer?.description;

    return DecoratedBox(
      decoration: decoration,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _softGold(theme),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${index + 1}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: shareGold(theme),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              prayer?.title ?? fallbackTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (minutes != null) ...[
                            const SizedBox(width: 10),
                            PrayerMinutes(minutes: minutes),
                          ],
                        ],
                      ),
                      if (description != null && description.isNotEmpty)
                        Text(
                          description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GoldPlayButton(
                  tooltip: l10n.playlistStartChanting,
                  size: 38,
                  onPressed: onOpen,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
