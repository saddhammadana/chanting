import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../share_page_parts.dart';

/// A prayer's chanting length beside a small clock.
class PrayerMinutes extends StatelessWidget {
  const PrayerMinutes({super.key, required this.minutes});

  final int minutes;

  @override
  Widget build(BuildContext context) => PlaylistDetailStat(
    icon: Icons.schedule,
    label: AppLocalizations.of(context).playlistPrayerMinutes(minutes),
    size: 16,
  );
}

/// A gold icon beside a dimmed label: one small fact about a set or prayer.
class PlaylistDetailStat extends StatelessWidget {
  const PlaylistDetailStat({
    super.key,
    required this.icon,
    required this.label,
    this.size = 20,
  });

  final IconData icon;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: size, color: shareGold(theme)),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
