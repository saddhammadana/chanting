import 'dart:async' show Future;

import '../stats/practice_log_controller.dart';

/// Chanting time spent on the reading screen, banked into the practice log.
///
/// The home card's goal ring counts wall time with the reader in front, so the
/// clock stops whenever the app leaves the foreground; time spent in another
/// app is not chanting.
class ReadingSession {
  /// [_log] is captured up front because `ref` resolves through `BuildContext`,
  /// which is already unsafe by the time `dispose` needs to bank the last
  /// session.
  ReadingSession(this._log);

  final PracticeLogController _log;

  /// When the open chanting session started, or null while it is paused.
  DateTime? _start;

  void resume() => _start ??= DateTime.now();

  /// Folds the open session into today's total and stops the clock.
  ///
  /// [deferred] is for `dispose`: it runs while the tree is being finalized,
  /// and Riverpod forbids notifying listeners (the home card's ring) then.
  /// The duration is measured now so the delay never counts.
  void pause({bool deferred = false}) {
    final start = _start;
    if (start == null) return;
    _start = null;
    final now = DateTime.now();
    final seconds = now.difference(start).inSeconds;
    if (seconds <= 0) return;
    final log = _log;
    if (deferred) {
      Future.microtask(() => log.addSeconds(seconds, now: now));
    } else {
      log.addSeconds(seconds, now: now);
    }
  }
}
