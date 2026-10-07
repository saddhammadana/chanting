import 'dart:async' show Timer;

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:flutter/scheduler.dart' show Ticker, TickerProvider;
import 'package:flutter/widgets.dart' show ScrollController, VoidCallback;

/// Slow auto-scroll while chanting.
///
/// Drives [controller] one frame at a time and notifies listeners whenever
/// [running] changes. Speed and delay are callbacks so the reader's settings
/// are read live rather than copied at construction.
class AutoScroller extends ChangeNotifier {
  AutoScroller({
    required TickerProvider vsync,
    required this.controller,
    required this.pxPerSecond,
    required this.delaySeconds,
    required this.onReachedEnd,
  }) {
    _ticker = vsync.createTicker(_onTick);
  }

  final ScrollController controller;
  final double Function() pxPerSecond;

  /// Seconds of "หน่วงก่อนเริ่ม" to wait before the first frame; see [start].
  final int Function() delaySeconds;

  /// Called after scrolling stops at the end of the content.
  final VoidCallback onReachedEnd;

  late final Ticker _ticker;
  bool _running = false;
  Duration _lastTick = Duration.zero;

  /// Pending "หน่วงก่อนเริ่ม" wait; see [start].
  Timer? _delayTimer;

  bool get running => _running;

  void start() {
    // The pause is part of "scrolling": the button reads as stop from the
    // moment it is pressed, so pressing it again during the wait cancels.
    _running = true;
    notifyListeners();
    _lastTick = Duration.zero;
    final delay = delaySeconds();
    if (delay <= 0) {
      _ticker.start();
      return;
    }
    _delayTimer?.cancel();
    _delayTimer = Timer(Duration(seconds: delay), () {
      // Still wanted? The reader may have stopped during the wait; leaving
      // the screen cancels the timer in [dispose].
      if (_running) {
        _lastTick = Duration.zero;
        _ticker.start();
      }
    });
  }

  void stop() {
    _delayTimer?.cancel();
    _ticker.stop();
    _lastTick = Duration.zero;
    _running = false;
    notifyListeners();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (!controller.hasClients) return;
    final position = controller.position;
    // Read speed live every frame so settings changes take effect immediately.
    final target = position.pixels + pxPerSecond() * dt;
    if (target >= position.maxScrollExtent) {
      controller.jumpTo(position.maxScrollExtent);
      stop(); // Reached the end of the prayer.
      onReachedEnd();
    } else {
      controller.jumpTo(target);
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _ticker.dispose();
    super.dispose();
  }
}
