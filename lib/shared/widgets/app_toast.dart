import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/dashboard_tokens.dart';
import 'app_asset_image.dart';

/// What a toast is reporting; picks its colour and its glyph.
enum ToastKind {
  /// Something the user asked for was done.
  success(AppColors.toastSuccess, Icons.check_rounded),

  /// Something happened that is neither good nor bad news.
  info(AppColors.toastInfo, Icons.info_outline_rounded),

  /// The user has to do something first.
  warning(AppColors.gold, Icons.priority_high_rounded),

  /// It did not work.
  error(AppColors.toastError, Icons.close_rounded);

  const ToastKind(this.accent, this.icon);

  final Color accent;
  final IconData icon;
}

/// Every short message in the app, from `Thai Mobile Toast Notifications
/// Mockup.png`: a pill tinted by [kind], a round glyph, the text, a faint
/// lotus and a close button.
///
/// Returns a [SnackBar] so the messenger still owns queueing, timing and the
/// swipe to dismiss; only the paint is ours. Always floating — the shell
/// relies on that to keep the start button on the bar.
SnackBar appToast(
  String message, {
  ToastKind kind = ToastKind.success,
  Duration duration = const Duration(seconds: 3),
  String? actionLabel,
  VoidCallback? onAction,
}) => SnackBar(
  behavior: SnackBarBehavior.floating,
  backgroundColor: Colors.transparent,
  elevation: 0,
  // Room for the pill's shadow: a SnackBar clips its content to its own box,
  // and with none the shadow was cut off square at the pill's edge.
  padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
  duration: duration,
  content: _ToastPill(
    message: message,
    kind: kind,
    actionLabel: actionLabel,
    onAction: onAction,
  ),
);

const _lotus = 'assets/images/shared/toast_lotus.png';

class _ToastPill extends StatelessWidget {
  const _ToastPill({
    required this.message,
    required this.kind,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final ToastKind kind;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // The surface with a wash of the kind's colour, so it reads as a tint in
    // both themes rather than as a second palette.
    final fill = Color.alphaBlend(
      kind.accent.withValues(
        alpha: theme.brightness == Brightness.light ? 0.08 : 0.20,
      ),
      scheme.surface,
    );
    void close() => ScaffoldMessenger.of(context).hideCurrentSnackBar();

    return Center(
      child: ConstrainedBox(
        // A message, not a banner: held near phone width on a wide window.
        constraints: const BoxConstraints(maxWidth: 520, minHeight: 52),
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: fill,
            // A hairline in the kind's colour, so the pill keeps its edge
            // on a page whose ground is as pale as its fill.
            shape: StadiumBorder(
              side: BorderSide(color: kind.accent.withValues(alpha: 0.28)),
            ),
            shadows: DashboardTokens.softShadows(theme),
          ),
          child: ClipPath(
            clipper: const ShapeBorderClipper(shape: StadiumBorder()),
            child: Stack(
              children: [
                Positioned(
                  right: 30,
                  bottom: -4,
                  // Two passes over the same white lotus. Tinted alone it is a
                  // flat silhouette: the artwork is white throughout and its
                  // petals differ only by a few points of alpha. Laying the
                  // white original over the tint leaves the colour showing at
                  // the petal edges, which is how the mockup draws it.
                  child: ExcludeSemantics(
                    child: Stack(
                      children: [
                        AppAssetImage(
                          _lotus,
                          width: 96,
                          color: kind.accent.withValues(alpha: 0.3),
                          colorBlendMode: BlendMode.srcIn,
                        ),
                        const Opacity(
                          opacity: 0.85,
                          child: AppAssetImage(_lotus, width: 96),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: kind.accent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(kind.icon, size: 20, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          message,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (actionLabel != null)
                        TextButton(
                          onPressed: () {
                            close();
                            onAction?.call();
                          },
                          child: Text(actionLabel!),
                        ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        color: scheme.onSurface,
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).closeButtonTooltip,
                        visualDensity: VisualDensity.compact,
                        onPressed: close,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
