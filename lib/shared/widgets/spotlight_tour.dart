import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;

import '../../l10n/app_localizations.dart';
import '../../theme/dashboard_tokens.dart';

/// One stop on a [showSpotlightTour]: the widget it points at and what it says.
class TourStep {
  const TourStep({
    required this.title,
    required this.body,
    this.target,
    this.circular = false,
    this.extra,
  });

  /// The widget to light up. Null centres the card with nothing lit, for an
  /// opening word. A target that is not on screen is skipped.
  final GlobalKey? target;

  final String title;
  final String body;

  /// Cut the light as a circle rather than a rounded box.
  final bool circular;

  /// Sits between the body and the buttons, e.g. a language picker.
  final Widget? extra;
}

/// Marks the bottom bar's start button for the home tour. The bar belongs to
/// the navigation shell, which the home screen cannot reach to hand a key to.
final tourStartButtonKey = GlobalKey(debugLabel: 'tour_start_button');

/// Set by "show the tour again" on the About screen; the home screen runs the
/// tour when it sees this and clears it. A plain notifier rather than a
/// provider because the asker and the home screen share no widget ancestry
/// worth threading one through.
final homeTourReplayRequest = ValueNotifier<bool>(false);

/// Walks the user through [steps], dimming the screen around one target at a
/// time. Completes when the tour is finished or skipped.
///
/// [steps] is called on every build rather than once, so the cards follow a
/// language changed from inside the tour.
Future<void> showSpotlightTour(
  BuildContext context, {
  required List<TourStep> Function(BuildContext context) steps,
}) {
  // Root navigator, so the scrim also covers the bottom bar.
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (context, _, _) => _SpotlightTour(steps: steps),
      transitionsBuilder: (context, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class _SpotlightTour extends StatefulWidget {
  const _SpotlightTour({required this.steps});

  final List<TourStep> Function(BuildContext context) steps;

  @override
  State<_SpotlightTour> createState() => _SpotlightTourState();
}

class _SpotlightTourState extends State<_SpotlightTour>
    with SingleTickerProviderStateMixin {
  int _index = 0;

  /// The lit target in screen coordinates; null while a step has none.
  Rect? _hole;

  /// The step's target, kept so the light can follow it.
  GlobalKey? _target;

  /// Re-measures the target every frame. Measuring once is not enough: a tour
  /// opened while the page under it is still sliding into place caught its
  /// target mid-slide and lit an empty patch beside it, and a resized window
  /// or a late layout moves the target just the same.
  late final Ticker _tracker;

  @override
  void initState() {
    super.initState();
    _tracker = createTicker((_) => _track())..start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _show(0));
  }

  @override
  void dispose() {
    _tracker.dispose();
    super.dispose();
  }

  Rect? _measure(GlobalKey? key) {
    final box = key?.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return (box.localToGlobal(Offset.zero) & box.size).inflate(6);
  }

  void _track() {
    if (_target == null) return;
    final rect = _measure(_target);
    if (rect == null || rect == _hole) return;
    setState(() => _hole = rect);
  }

  /// Moves to the first step at or after [index] that can be shown.
  Future<void> _show(int index) async {
    final steps = widget.steps(context);
    var next = index;
    while (next < steps.length) {
      final target = steps[next].target;
      if (target == null || target.currentContext != null) break;
      next++;
    }
    if (next >= steps.length) {
      Navigator.of(context).pop();
      return;
    }
    final targetContext = steps[next].target?.currentContext;
    if (targetContext == null) {
      setState(() {
        _index = next;
        _target = null;
        _hole = null;
      });
      return;
    }
    await Scrollable.ensureVisible(
      targetContext,
      alignment: 0.3,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
    if (!mounted || !targetContext.mounted) return;
    final key = steps[next].target;
    final rect = _measure(key);
    if (rect == null) return;
    setState(() {
      _index = next;
      _target = key;
      _hole = rect;
    });
  }

  void _next() => _show(_index + 1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final steps = widget.steps(context);
    final step = steps[_index.clamp(0, steps.length - 1)];
    final last = _index >= steps.length - 1;
    final hole = _hole;

    final card = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Material(
        key: const ValueKey('home_tour_card'),
        color: theme.colorScheme.surface,
        elevation: 6,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 14, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                step.body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              if (step.extra != null) ...[
                const SizedBox(height: 14),
                step.extra!,
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '${_index + 1}/${steps.length}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  if (!last)
                    TextButton(
                      key: const ValueKey('home_tour_skip'),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.tourSkip),
                    ),
                  const SizedBox(width: 4),
                  FilledButton(
                    key: const ValueKey('home_tour_next'),
                    onPressed: last ? () => Navigator.of(context).pop() : _next,
                    child: Text(last ? l10n.welcomeButton : l10n.tourNext),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Under the target when there is room for the card there, over it
        // otherwise; the bottom bar's button always takes the second branch.
        final below =
            hole != null && hole.bottom + 230 <= constraints.maxHeight;
        return Stack(
          key: const ValueKey('home_tour'),
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                // A tap on the dimmed screen moves on, but not from the
                // opening card: that one holds a control worth not skipping.
                onTap: hole == null ? null : _next,
                child: CustomPaint(
                  painter: _ScrimPainter(
                    hole: hole,
                    circular: step.circular,
                    edge: theme.brightness == Brightness.dark
                        ? theme.colorScheme.secondary
                        : DashboardTokens.goldEdge,
                  ),
                ),
              ),
            ),
            if (hole == null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: card,
                ),
              )
            else
              Positioned(
                left: 16,
                right: 16,
                top: below ? hole.bottom + 12 : null,
                bottom: below ? null : constraints.maxHeight - hole.top + 12,
                child: Center(child: card),
              ),
          ],
        );
      },
    );
  }
}

/// Dims everything but [hole], and rings the hole in gold.
class _ScrimPainter extends CustomPainter {
  const _ScrimPainter({
    required this.hole,
    required this.circular,
    required this.edge,
  });

  final Rect? hole;
  final bool circular;
  final Color edge;

  @override
  void paint(Canvas canvas, Size size) {
    final scrim = Paint()..color = Colors.black.withValues(alpha: 0.62);
    final hole = this.hole;
    if (hole == null) {
      canvas.drawRect(Offset.zero & size, scrim);
      return;
    }
    final radius = Radius.circular(circular ? hole.shortestSide / 2 : 20);
    final shape = RRect.fromRectAndRadius(hole, radius);
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addRRect(shape),
      scrim,
    );
    canvas.drawRRect(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = edge,
    );
  }

  @override
  bool shouldRepaint(_ScrimPainter old) =>
      old.hole != hole || old.circular != circular || old.edge != edge;
}
