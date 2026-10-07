import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/prefs_service.dart';

/// Keep at most about two years of days, so prefs do not grow without bound.
const _kMaxPracticeDays = 730;

/// Longest single session that can count toward a day, guarding against a
/// reading screen left open overnight.
const kMaxSessionSeconds = 2 * 60 * 60;

/// Formats a date the way the log keys its entries.
String isoDate(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

/// Seconds chanted per day, keyed `yyyy-MM-dd`. Pure for easy testing.
class PracticeLog {
  final Map<String, int> secondsByDate;

  const PracticeLog(this.secondsByDate);

  static const empty = PracticeLog({});

  /// Parses `yyyy-MM-dd:seconds` entries, skipping anything malformed so a
  /// hand-edited or truncated value cannot leave the home card unreadable.
  factory PracticeLog.fromEntries(List<String> raw) {
    final out = <String, int>{};
    for (final entry in raw) {
      final at = entry.lastIndexOf(':');
      if (at <= 0) continue;
      final seconds = int.tryParse(entry.substring(at + 1));
      if (seconds == null || seconds < 0) continue;
      out[entry.substring(0, at)] = seconds;
    }
    return PracticeLog(out);
  }

  /// Serializes back, oldest first and capped to the retention window.
  List<String> toEntries() {
    final dates = secondsByDate.keys.toList()..sort();
    final kept = dates.length > _kMaxPracticeDays
        ? dates.sublist(dates.length - _kMaxPracticeDays)
        : dates;
    return [for (final d in kept) '$d:${secondsByDate[d]}'];
  }

  int secondsOn(String date) => secondsByDate[date] ?? 0;

  /// Whole minutes chanted on [date]; a part-minute does not count yet.
  int minutesOn(String date) => secondsOn(date) ~/ 60;

  /// One session folded into [date], clamped by [kMaxSessionSeconds].
  PracticeLog adding(String date, int seconds) {
    if (seconds <= 0) return this;
    final capped = seconds > kMaxSessionSeconds ? kMaxSessionSeconds : seconds;
    return PracticeLog({...secondsByDate, date: secondsOn(date) + capped});
  }
}

/// Practice time per day: the reading screen and the meditation timer each
/// add a session on the way out.
class PracticeLogController extends Notifier<PracticeLog> {
  @override
  PracticeLog build() => PracticeLog.fromEntries(
    ref.read(prefsServiceProvider).getPracticeSeconds(),
  );

  /// Adds one session. [now] is injectable so tests need not wait a day.
  ///
  /// The reading screen calls this a microtask after its `dispose`, by which
  /// time the whole `ProviderScope` may already be gone (app or test teardown).
  void addSeconds(int seconds, {DateTime? now}) {
    if (seconds <= 0 || !ref.mounted) return;
    final next = state.adding(isoDate(now ?? DateTime.now()), seconds);
    state = next;
    ref.read(prefsServiceProvider).setPracticeSeconds(next.toEntries());
  }
}

final practiceLogControllerProvider =
    NotifierProvider<PracticeLogController, PracticeLog>(
      PracticeLogController.new,
    );

/// Whole minutes practised today, watched by the home card's progress ring.
final practiceMinutesTodayProvider = Provider<int>(
  (ref) => ref
      .watch(practiceLogControllerProvider)
      .minutesOn(isoDate(DateTime.now())),
);
