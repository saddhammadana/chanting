import 'package:flutter/widgets.dart';

/// Saves the reader's scroll offset and restores it for "continue reading".
class ReadPositionKeeper {
  ReadPositionKeeper({required this.controller, required this.persist});

  final ScrollController controller;

  /// Writes an offset to storage along with the reader context it belongs to.
  final void Function(double offset) persist;

  int _restoreTries = 0;
  DateTime _lastSave = DateTime.fromMillisecondsSinceEpoch(0);

  /// Persist the scroll offset, throttled during auto-scroll.
  void save({bool force = false}) {
    if (!controller.hasClients) return;
    final now = DateTime.now();
    if (!force && now.difference(_lastSave) < const Duration(seconds: 2)) {
      return;
    }
    _lastSave = now;
    persist(controller.offset);
  }

  /// Restore a saved scroll offset, retrying until layout is tall enough.
  ///
  /// [isMounted] stops the retries once the reader has been left.
  void restore(double target, {required bool Function() isMounted}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isMounted()) return;
      if (controller.hasClients) {
        final max = controller.position.maxScrollExtent;
        if (max >= target || _restoreTries >= 20) {
          controller.jumpTo(target.clamp(0.0, max));
          return;
        }
      }
      _restoreTries++;
      if (_restoreTries <= 20) restore(target, isMounted: isMounted);
    });
    WidgetsBinding.instance.scheduleFrame();
  }
}
