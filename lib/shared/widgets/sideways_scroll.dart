import 'package:flutter/gestures.dart'
    show PointerDeviceKind, PointerScrollEvent, PointerSignalEvent;
import 'package:flutter/material.dart';

/// Horizontal scroll helper that works on desktop and web.
///
/// Flutter's defaults make horizontal strips hard to use with a mouse:
/// desktop `ScrollBehavior` does not drag with the mouse because mouse drag often
/// means text selection, and most mouse wheels only send vertical deltas. The
/// result is a partially visible strip with no obvious way to reach the rest.
///
/// This combines three fixes because no one input path covers every device:
/// 1. mouse drag via `dragDevices`;
/// 2. vertical wheel delta mapped to horizontal scrolling by [_wheel];
/// 3. a visible [Scrollbar] that signals more content exists to the right.
///
/// [builder] receives the [ScrollController] and must attach it to exactly one
/// scrollable, otherwise [Scrollbar] asserts.
class SidewaysScroll extends StatefulWidget {
  const SidewaysScroll({super.key, required this.builder});

  final Widget Function(BuildContext context, ScrollController controller)
  builder;

  @override
  State<SidewaysScroll> createState() => _SidewaysScrollState();
}

class _SidewaysScrollState extends State<SidewaysScroll> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Mouse-wheel handler. Use whichever axis moved more, so both ordinary vertical
  /// wheels and horizontal trackpad gestures work.
  void _wheel(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_controller.hasClients) return;
    final d = event.scrollDelta;
    final delta = d.dx.abs() > d.dy.abs() ? d.dx : d.dy;
    if (delta == 0) return;
    final target = (_controller.offset + delta).clamp(
      0.0,
      _controller.position.maxScrollExtent,
    );
    if (target != _controller.offset) _controller.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _wheel,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: const {
            PointerDeviceKind.mouse,
            PointerDeviceKind.touch,
            PointerDeviceKind.stylus,
            PointerDeviceKind.trackpad,
          },
          // Use the explicit [Scrollbar] below. Letting ScrollBehavior add another
          // one creates stacked scrollbars on desktop.
          scrollbars: false,
        ),
        child: Scrollbar(
          controller: _controller,
          thickness: 4,
          child: widget.builder(context, _controller),
        ),
      ),
    );
  }
}
