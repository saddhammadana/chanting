import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/content_width.dart';
import '../../../shared/widgets/golden_pill_button.dart';
import 'edit_corner_art.dart';
import 'edit_decorations.dart';

/// The foot of the set pages: the page's flat ground with the artwork's two
/// lotus corners, holding [child] at the composed width above the system
/// inset. The edit page puts its save button here, the set page its bar.
class EditFootFrame extends StatelessWidget {
  const EditFootFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: editGround(Theme.of(context)),
      child: Stack(
        children: [
          const Positioned(
            left: 0,
            bottom: 0,
            child: EditCornerArt(
              'assets/images/playlists/lotus_cloud_corner_bottom_left.png',
              width: 190,
            ),
          ),
          const Positioned(
            right: 0,
            bottom: 0,
            child: EditCornerArt(
              'assets/images/playlists/lotus_cloud_corner_bottom_right.png',
              width: 190,
            ),
          ),
          SafeArea(
            top: false,
            // Narrower than the form above it: one button across an 800px
            // column reads as a banner, not a button.
            child: ContentWidth(
              maxWidth: ContentWidth.composedWidth,
              fillHeight: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The gold "บันทึกชุดสวด" over the artwork's two lotus corners, pinned
/// under the scrolling form.
class EditSaveBar extends StatelessWidget {
  const EditSaveBar({super.key, required this.onSave});

  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return EditFootFrame(
      child: GoldenPillButton(
        key: const ValueKey('playlist_save_button'),
        label: l10n.playlistSave,
        icon: const Icon(Icons.save_outlined),
        height: 56,
        expand: true,
        onPressed: onSave,
      ),
    );
  }
}
