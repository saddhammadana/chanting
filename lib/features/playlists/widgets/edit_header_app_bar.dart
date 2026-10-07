import 'package:flutter/material.dart';

import '../../../shared/widgets/app_back_button.dart';
import '../share_page_parts.dart';
import 'edit_corner_art.dart';
import 'edit_decorations.dart';

/// Header: clouds and lotus at the left, the temple at the right, the lotus
/// rule, title and subtitle between. It stays whole while the page scrolls
/// under it, so going back — and what this page is — never scrolls away.
class EditHeaderAppBar extends StatelessWidget {
  const EditHeaderAppBar({
    super.key,
    required this.title,
    required this.subtitle,
    this.actions = const [],
    this.showBack = true,
  });

  final String title;
  final String subtitle;

  /// False on a bottom-nav destination, which has nothing to go back to.
  final bool showBack;

  /// Toolbar actions at the right, level with the back button.
  final List<Widget> actions;

  /// The toolbar row holding the title, then the lotus rule and a
  /// two-line subtitle under it (less [_ruleLift]).
  static const expandedHeight = 106.0;

  static const _ruleLift = 8.0;

  /// Same as [EditSaveBar]'s corners, so head and foot frame the page alike.
  static const _cornerWidth = 190.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final top = MediaQuery.paddingOf(context).top;
    return SliverAppBar(
      pinned: true,
      // Equal heights: the header never collapses.
      collapsedHeight: expandedHeight,
      expandedHeight: expandedHeight,
      backgroundColor: editGround(theme),
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      leading: showBack ? const AppBackButton() : null,
      leadingWidth: showBack ? 64 : null,
      actions: actions,
      flexibleSpace: Stack(
        clipBehavior: Clip.hardEdge,
        fit: StackFit.expand,
        children: [
          // Mirrors EditSaveBar: one fixed-size piece in each top corner,
          // flush with the screen edge. Both files draw their flowers into
          // their own bottom edge, so the pair fades out towards the
          // bottom of the header instead of being cut off by it.
          Positioned.fill(
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (rect) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Colors.white, Colors.transparent],
                stops: [0, 0.55, 1],
              ).createShader(rect),
              child: Stack(
                children: [
                  for (final right in [false, true])
                    Positioned(
                      top: 0,
                      left: right ? null : 0,
                      right: right ? 0 : null,
                      child: EditCornerArt(
                        right
                            ? 'assets/images/playlists/temple_lotus_corner_top_right.png'
                            : 'assets/images/playlists/cloud_lotus_corner_top_left.png',
                        width: _cornerWidth,
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Title first, centred in the toolbar row beside the back button;
          // the lotus rule and the subtitle follow below the button, where
          // they may use the full width.
          Positioned(
            left: 20,
            right: 20,
            top: top,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: kToolbarHeight,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 44),
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                // Lifted into the toolbar row's slack under the title, so the
                // rule sits midway between title and subtitle instead of
                // hard on the subtitle.
                Transform.translate(
                  offset: const Offset(0, -_ruleLift),
                  child: Column(
                    children: [
                      const LotusRule(width: 150, lotus: 26),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
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
