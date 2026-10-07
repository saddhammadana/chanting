import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_asset_image.dart';
import 'playlist_detail_stat.dart';

/// The lotus-book cover beside the set's name, its description and its
/// length when known.
class PlaylistDetailHeader extends StatelessWidget {
  const PlaylistDetailHeader({
    super.key,
    required this.name,
    required this.description,
    required this.minutes,
  });

  final String name;
  final String? description;
  final int? minutes;

  static const _coverWidth = 86.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const ExcludeSemantics(
          child: AppAssetImage(
            'assets/images/playlists/pale_amber_lotus_book.png',
            width: _coverWidth,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (description != null) ...[
                const SizedBox(height: 4),
                Text(
                  description!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              // The count is in the list's own heading below.
              if (minutes != null) ...[
                const SizedBox(height: 8),
                PlaylistDetailStat(
                  icon: Icons.schedule,
                  label: l10n.playlistPrayerMinutes(minutes!),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
