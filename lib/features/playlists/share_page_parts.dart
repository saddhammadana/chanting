import 'package:flutter/material.dart';

import '../../shared/widgets/app_asset_image.dart';
import '../../shared/widgets/content_width.dart';
import '../../theme/dashboard_tokens.dart';
import 'widgets/edit_decorations.dart' show editGround;
import 'widgets/edit_header_app_bar.dart';

/// Frame shared by the sharing pages (share, receive, scan, paste): the set
/// pages' flat ground and sticky cloud-and-temple header
/// ([EditHeaderAppBar]), over a phone-width column that scrolls under it.
class SharePageScaffold extends StatelessWidget {
  const SharePageScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    this.children = const [],
    this.slivers,
    this.backdrop = const [],
    this.actions = const [],
    this.bottomBar,
    this.controller,
    this.showBack = true,
  });

  final String title;

  /// The header's line under the title.
  final String subtitle;

  final List<Widget> children;

  /// Replaces [children] for a page whose column holds a sliver of its own;
  /// padded like [children].
  final List<Widget>? slivers;

  /// AppBar actions, after the title.
  final List<Widget> actions;

  /// Pinned under the scrolling column, in the Scaffold's bottom slot.
  final Widget? bottomBar;

  /// Scroll controller for the [slivers] column.
  final ScrollController? controller;

  /// False on a bottom-nav destination, which has nothing to go back to.
  final bool showBack;

  /// Ornament painted on the ground behind the list (e.g. corner artwork);
  /// each entry is a child of a [Stack] the size of the body, so position it.
  final List<Widget> backdrop;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: editGround(Theme.of(context)),
      body: Stack(
        children: [
          ...backdrop,
          LayoutBuilder(
            builder: (context, box) {
              final gutter = ((box.maxWidth - ContentWidth.composedWidth) / 2)
                  .clamp(0.0, double.infinity);
              return CustomScrollView(
                controller: controller,
                slivers: [
                  EditHeaderAppBar(
                    title: title,
                    subtitle: subtitle,
                    actions: actions,
                    showBack: showBack,
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      20 + gutter,
                      12,
                      20 + gutter,
                      28,
                    ),
                    sliver: slivers == null
                        ? SliverList.list(children: children)
                        : SliverMainAxisGroup(slivers: slivers!),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: bottomBar,
    );
  }
}

/// Card face shared with the rest of the app: the theme's card colour and
/// hairline, raised by the same warm shadow as the settings cards.
BoxDecoration shareCardDecoration(ThemeData theme) {
  final shape = theme.cardTheme.shape;
  return BoxDecoration(
    color: theme.cardTheme.color ?? theme.colorScheme.surface,
    borderRadius: shape is RoundedRectangleBorder
        ? shape.borderRadius
        : BorderRadius.circular(18),
    border: Border.all(color: theme.colorScheme.outlineVariant),
    boxShadow: DashboardTokens.cardShadows(theme, glow: 0.2),
  );
}

Color shareGold(ThemeData theme) => theme.colorScheme.secondary;

/// A thin gold rule broken by a small outline lotus.
class LotusRule extends StatelessWidget {
  const LotusRule({super.key, required this.width, required this.lotus});

  final double width;
  final double lotus;

  @override
  Widget build(BuildContext context) {
    final gold = shareGold(Theme.of(context));
    final line = Expanded(
      child: Container(height: 1, color: gold.withValues(alpha: 0.55)),
    );
    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        child: Row(
          children: [
            line,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: OutlineLotus(size: lotus, color: gold),
            ),
            line,
          ],
        ),
      ),
    );
  }
}

/// The outline lotus mark, tinted to [color].
class OutlineLotus extends StatelessWidget {
  const OutlineLotus({super.key, required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => AppAssetImage(
    'assets/images/shared/lotus_white_outline.png',
    width: size,
    height: size * 155 / 256,
    fit: BoxFit.contain,
    // The asset is a white outline; tint it rather than ship a gold copy.
    color: color,
    colorBlendMode: BlendMode.srcIn,
  );
}
