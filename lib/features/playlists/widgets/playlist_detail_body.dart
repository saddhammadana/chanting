import 'package:flutter/material.dart';

import '../../../data/models/prayer.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/golden_pill_button.dart';
import '../share_page_parts.dart';
import 'playlist_detail_header.dart';
import 'playlist_detail_play_all_card.dart';
import 'playlist_detail_prayer_row.dart';

/// The set page's body: cover and name, the play-all card, the list heading
/// with "จัดลำดับ", and the rows. [onPlayAll] and [onReorder] are null where
/// the page has nothing to offer for them (an empty or unsaved set).
List<Widget> playlistDetailBody(
  BuildContext context, {
  required String name,
  required String? description,
  required List<String> ids,
  required Map<String, Prayer> byId,
  required void Function(String id) onOpen,
  required Widget empty,
  VoidCallback? onPlayAll,
  VoidCallback? onReorder,
}) {
  final l10n = AppLocalizations.of(context);
  final theme = Theme.of(context);
  // A total only when every prayer has a length; a partial sum would be a
  // guess passed off as a figure.
  final minutes =
      ids.isNotEmpty && ids.every((id) => byId[id]?.durationMinutes != null)
      ? ids.fold<int>(0, (sum, id) => sum + byId[id]!.durationMinutes!)
      : null;

  return [
    SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PlaylistDetailHeader(
            name: name,
            description: description,
            minutes: minutes,
          ),
          const SizedBox(height: 22),
          if (onPlayAll != null) ...[
            PlaylistDetailPlayAllCard(count: ids.length, onPlay: onPlayAll),
            const SizedBox(height: 26),
          ],
          if (ids.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.playlistPrayersHeading(ids.length),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // Only worth offering once there is an order to change.
                if (onReorder != null && ids.length > 1)
                  OutlinedButton.icon(
                    key: const ValueKey('playlist_reorder_button'),
                    style: goldOutlinedButtonStyle(theme).copyWith(
                      shape: const WidgetStatePropertyAll(StadiumBorder()),
                      side: WidgetStatePropertyAll(
                        BorderSide(color: theme.colorScheme.outlineVariant),
                      ),
                    ),
                    onPressed: onReorder,
                    icon: Icon(Icons.tune, size: 20, color: shareGold(theme)),
                    label: Text(l10n.playlistReorder),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    ),
    if (ids.isEmpty)
      SliverToBoxAdapter(child: empty)
    else
      SliverList.builder(
        itemCount: ids.length,
        itemBuilder: (context, index) {
          final prayerId = ids[index];
          return Padding(
            key: ValueKey(prayerId),
            padding: const EdgeInsets.only(bottom: 10),
            child: PlaylistDetailPrayerRow(
              index: index,
              prayer: byId[prayerId],
              fallbackTitle: prayerId,
              onOpen: () => onOpen(prayerId),
            ),
          );
        },
      ),
  ];
}
