import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// Pull-past-edge gesture for advancing, webtoon-style.
///
/// Wraps the actual scrollable and handles the gesture itself. This used to live
/// only inside `_ContinuousContentState`, but one-prayer swipe mode needs the same
/// gesture with a different destination type. Extracting it keeps both modes on
/// the same behavior instead of parallel implementations drifting apart.
///
/// Labels are functions rather than l10n keys so callers choose whether wording
/// says category or prayer.
class PullToAdvance extends StatefulWidget {
  const PullToAdvance({
    super.key,
    required this.child,
    required this.nextLabel,
    required this.onNext,
    required this.prevLabel,
    required this.onPrev,
    required this.moreNext,
    required this.releaseNext,
    required this.morePrev,
    required this.releasePrev,
  });

  /// Scrollable whose edge gesture should be observed.
  final Widget child;

  /// Destination name; null disables that direction.
  final String? nextLabel;
  final VoidCallback? onNext;
  final String? prevLabel;
  final VoidCallback? onPrev;

  final String Function(String name) moreNext;
  final String Function(String name) releaseNext;
  final String Function(String name) morePrev;
  final String Function(String name) releasePrev;

  @override
  State<PullToAdvance> createState() => _PullToAdvanceState();
}

class _PullToAdvanceState extends State<PullToAdvance> {
  /// Pull distance in px considered intentional advance.
  static const _pullThreshold = 96.0;

  /// Accumulated edge pull; positive means pulling up at end, negative at start.
  double _pull = 0;

  /// Last pull direction, kept after release so the indicator fades at that edge.
  bool _pullingUp = true;

  /// Destination for the active pull direction.
  String? get _pullTargetName =>
      _pullingUp ? widget.nextLabel : widget.prevLabel;

  /// Stores new pull distance, discarding directions with no destination.
  void _setPull(double value) {
    if (value > 0 && widget.onNext == null) value = 0;
    if (value < 0 && widget.onPrev == null) value = 0;
    if (value == _pull) return;
    setState(() {
      _pull = value;
      if (value != 0) _pullingUp = value > 0;
    });
  }

  /// Accumulates pull delta without crossing zero in one gesture.
  ///
  /// Direction is chosen at gesture start; dragging back can only reduce to zero.
  double _accumulate(double delta) {
    final value = _pull + delta;
    if (_pull > 0) return value.clamp(0.0, double.infinity);
    if (_pull < 0) return value.clamp(double.negativeInfinity, 0.0);
    return value;
  }

  /// Handles drag beyond scroll edges.
  ///
  /// Supports clamping physics through OverscrollNotification and bouncing physics
  /// through pixels beyond bounds. Dragging back before release reduces distance;
  /// releasing below threshold cancels.
  bool _handle(ScrollNotification notification) {
    if (widget.onNext == null && widget.onPrev == null) return false;
    final metrics = notification.metrics;
    if (notification is OverscrollNotification &&
        notification.dragDetails != null) {
      // Overscroll sign identifies edge: positive at the end, negative at start.
      _setPull(_accumulate(notification.overscroll));
    } else if (notification is ScrollUpdateNotification &&
        notification.dragDetails != null) {
      // Bouncing physics expose real pixels beyond the edge, so use them directly.
      if (metrics.pixels > metrics.maxScrollExtent) {
        _setPull(metrics.pixels - metrics.maxScrollExtent);
      } else if (metrics.pixels < metrics.minScrollExtent) {
        _setPull(metrics.pixels - metrics.minScrollExtent);
      } else if (_pull != 0) {
        // Clamping physics are back in range; reverse drag subtracts distance.
        _setPull(_accumulate(notification.scrollDelta ?? 0));
      }
    } else if (notification is ScrollEndNotification) {
      if (_pull.abs() >= _pullThreshold) {
        (_pullingUp ? widget.onNext : widget.onPrev)?.call();
      }
      _setPull(0);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final target = _pullTargetName;
    final reached = _pull.abs() >= _pullThreshold;
    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _handle,
          child: widget.child,
        ),
        // Pull-distance indicator at the active edge, fading in with distance.
        if (target != null)
          Positioned(
            left: 0,
            right: 0,
            top: _pullingUp ? null : 12,
            bottom: _pullingUp ? 12 : null,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: (_pull.abs() / _pullThreshold).clamp(0.0, 1.0),
                duration: const Duration(milliseconds: 80),
                child: _PullProgressIndicator(
                  progress: _pull.abs() / _pullThreshold,
                  pullingUp: _pullingUp,
                  message: switch ((reached, _pullingUp)) {
                    (true, true) => widget.releaseNext(target),
                    (true, false) => widget.releasePrev(target),
                    (false, true) => widget.moreNext(target),
                    (false, false) => widget.morePrev(target),
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Circular progress indicator for the webtoon-style pull gesture.
///
/// The circle fills with pull distance. A full circle means the threshold is
/// reached, switching to a solid circle with a check mark; releasing then goes to
/// the destination.
///
/// [message] is passed in already composed. The destination can be a category in
/// continuous mode or a prayer in one-prayer mode, so callers choose wording.
class _PullProgressIndicator extends StatelessWidget {
  const _PullProgressIndicator({
    required this.progress,
    required this.message,
    required this.pullingUp,
  });

  /// 0..1 before threshold, >= 1 once threshold is reached.
  final double progress;

  /// Pre-composed message from the caller.
  final String message;

  /// True when pulling upward at page end; false when pulling downward at start.
  final bool pullingUp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final reached = progress >= 1;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Circle background darkens at threshold so readiness is obvious.
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                decoration: BoxDecoration(
                  color: reached
                      ? theme.colorScheme.secondary
                      : theme.colorScheme.secondaryContainer,
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: CircularProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    strokeWidth: 3,
                    strokeCap: StrokeCap.round,
                    backgroundColor: Colors.transparent,
                    color: reached
                        ? theme.colorScheme.onSecondary
                        : theme.colorScheme.secondary,
                  ),
                ),
              ),
              Icon(
                reached
                    ? Icons.check_rounded
                    : pullingUp
                    ? Icons.keyboard_double_arrow_up
                    : Icons.keyboard_double_arrow_down,
                size: 22,
                color: reached
                    ? theme.colorScheme.onSecondary
                    : theme.colorScheme.onSecondaryContainer,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Caption under the circle, on a subtle surface so it stays readable.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
              if (reached)
                Text(
                  pullingUp ? l10n.pullCancelDown : l10n.pullCancelUp,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer.withValues(
                      alpha: 0.7,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
