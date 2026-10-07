import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/pinned_ref.dart';
import '../../../data/models/playlist.dart';
import '../../../l10n/app_localizations.dart';
import '../../prayer_list/categories_screen.dart' show togglePin;
import '../../prayer_list/pinned_controller.dart';
import '../share_page_parts.dart';
import 'edit_decorations.dart';

/// The artwork's three-way bar under the list: pin to home, edit, share.
class PlaylistDetailActionBar extends ConsumerWidget {
  const PlaylistDetailActionBar({
    super.key,
    required this.playlist,
    required this.onEdit,
  });

  final Playlist playlist;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final pin = PinnedRef(PinnedType.playlist, playlist.id);
    final pinned = ref.watch(pinnedControllerProvider).contains(pin);
    final divider = SizedBox(
      height: 40,
      child: VerticalDivider(width: 1, color: theme.colorScheme.outlineVariant),
    );
    // The foot frame supplies the ground, corners, inset and width.
    return DecoratedBox(
      decoration: editPanelDecoration(theme),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            _BarAction(
              icon: pinned ? Icons.push_pin : Icons.push_pin_outlined,
              label: pinned ? l10n.playlistUnpin : l10n.playlistPin,
              onTap: () => togglePin(context, ref, pin),
            ),
            divider,
            _BarAction(
              icon: Icons.edit_outlined,
              label: l10n.playlistEditShort,
              onTap: onEdit,
            ),
            divider,
            _BarAction(
              icon: Icons.share_outlined,
              label: l10n.playlistShareTitle,
              // An empty set has nothing to share; disable it instead
              // of opening an empty QR.
              onTap: playlist.prayerIds.isEmpty
                  ? null
                  : () => context.push('/playlists/${playlist.id}/share'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarAction extends StatelessWidget {
  const _BarAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onTap != null;
    final color = enabled ? theme.colorScheme.onSurface : theme.disabledColor;
    return Expanded(
      child: Semantics(
        button: true,
        enabled: enabled,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 26, color: enabled ? shareGold(theme) : color),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
