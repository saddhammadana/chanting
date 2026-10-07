import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/prefs_service.dart';

/// Preset round targets: 9 for short chants, 27, and 108 for one mala round.
const kMalaPresetTargets = [9, 27, 108];

/// Maximum custom target to guard against obvious input mistakes.
const kMalaMaxTarget = 1080;

/// Mala counter state, persisted so counting can resume after closing the app.
class MalaState {
  final int count;
  final int target;

  const MalaState({required this.count, required this.target});

  /// Whether count reached or exceeded target; used for completion haptics.
  bool get isComplete => count >= target && target > 0;

  MalaState copyWith({int? count, int? target}) =>
      MalaState(count: count ?? this.count, target: target ?? this.target);
}

/// Chant round counter: increment, target, reset, and persist every change.
class MalaController extends Notifier<MalaState> {
  @override
  MalaState build() {
    final prefs = ref.read(prefsServiceProvider);
    return MalaState(
      count: prefs.getMalaCount(),
      target: prefs.getMalaTarget(),
    );
  }

  /// Increments once and returns true only when the target is reached exactly.
  ///
  /// Counting can continue beyond the target for multiple rounds, but strong
  /// haptics should fire only on the exact crossing.
  bool increment() {
    final next = state.count + 1;
    state = state.copyWith(count: next);
    ref.read(prefsServiceProvider).setMalaCount(next);
    return next == state.target;
  }

  void reset() {
    state = state.copyWith(count: 0);
    ref.read(prefsServiceProvider).setMalaCount(0);
  }

  /// Sets a new target clamped to 1..max.
  ///
  /// If the current count already exceeds the new target, reset count to avoid an
  /// immediate, confusing completed state.
  void setTarget(int target) {
    final clamped = target.clamp(1, kMalaMaxTarget);
    final resetCount = state.count > clamped;
    state = MalaState(count: resetCount ? 0 : state.count, target: clamped);
    final prefs = ref.read(prefsServiceProvider);
    prefs.setMalaTarget(clamped);
    if (resetCount) prefs.setMalaCount(0);
  }
}

final malaControllerProvider = NotifierProvider<MalaController, MalaState>(
  MalaController.new,
);
