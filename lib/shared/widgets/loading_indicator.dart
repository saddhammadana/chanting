import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'app_asset_image.dart';

/// The app's loader: the golden lotus of the launch screen, a line of text and
/// three gold dots. Android and iOS open on this lotus, still, at this size and
/// at the centre, and the web splash in `web/index.html` draws the same file,
/// so the picture does not change when Flutter takes over.
///
/// This used to accept a `message` parameter with a Thai default and `null` to
/// hide it. No call site used that flexibility, and a const constructor cannot
/// receive l10n, so the parameter was removed instead of making this widget more
/// complex for unused behavior.
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key, this.appName = false});

  /// Draws the app's name under the lotus and keeps the lotus itself at the
  /// centre of the space, with the text hanging below it. For the start-up
  /// splash, which has no page title above it to say whose loader this is and
  /// has to line up with the platform launch screen's centred lotus.
  final bool appName;

  /// The launch screen's lotus, a still PNG with real alpha, so one file
  /// sits on the light and the dark ground alike. It is a copy of Android's
  /// `drawable-xxhdpi/splash_lotus.png` and iOS's `LaunchImage`, and is also
  /// named in `web/index.html`: change all of them together.
  static const asset = 'assets/images/shared/splash_lotus.png';

  /// The launch screens draw the image 288 wide, with the flower inside the
  /// middle two thirds.
  static const _splashSize = 288.0;
  static const _inlineSize = 180.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final size = appName ? _splashSize : _inlineSize;
    final lotus = ExcludeSemantics(
      child: AppAssetImage(asset, width: size, height: size),
    );
    final caption = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (appName) ...[
          Text(
            l10n.appName,
            style: theme.textTheme.headlineLarge?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w400,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Text(
          l10n.loading,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 16),
        _Dots(color: scheme.secondary),
      ],
    );
    if (!appName) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          // The image's own transparent margin is more than the space wanted,
          // so the caption is drawn a little way up into it.
          children: [
            lotus,
            Transform.translate(
              offset: const Offset(0, -_inlineSize / 9),
              child: caption,
            ),
          ],
        ),
      );
    }
    // Centred by its own Center: under loose constraints a bare Stack sits at
    // the top-left corner.
    return Center(
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          lotus,
          // Below the lotus without moving it off centre: the flower's own
          // half-height (a third of the image), a gap, then the caption's own
          // height, which FractionalTranslation supplies.
          Transform.translate(
            offset: const Offset(0, _splashSize / 3 + 12),
            child: FractionalTranslation(
              translation: const Offset(0, 0.5),
              child: caption,
            ),
          ),
        ],
      ),
    );
  }
}

/// Three dots brightening in turn.
class _Dots extends StatefulWidget {
  const _Dots({required this.color});

  final Color color;

  @override
  State<_Dots> createState() => _DotsState();
}

class _DotsState extends State<_Dots> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Opacity(
                // Each dot peaks a fifth of a cycle after the one before it.
                opacity:
                    0.35 +
                    0.65 *
                        (0.5 +
                            0.5 *
                                math.cos(
                                  2 * math.pi * (_controller.value - i * 0.2),
                                )),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
