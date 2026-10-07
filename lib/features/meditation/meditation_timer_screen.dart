import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../data/local/ambient_sound.dart';
import '../../data/local/completion_signal.dart';
import '../../data/local/prefs_service.dart';
import '../../data/local/system_bars.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_asset_image.dart';
import '../../shared/widgets/app_back_button.dart';
import '../../shared/widgets/content_width.dart';
import '../../shared/widgets/floral_corners.dart';
import '../../shared/widgets/golden_pill_button.dart';
import '../../theme/app_theme.dart';
import '../settings/settings_controller.dart';
import '../stats/practice_log_controller.dart';
import 'widgets/meditation_session_view.dart';
import 'widgets/meditation_setup.dart';

// Four presets plus the custom control fill one quiet row like the reference.
// Any previously saved duration (including 20 minutes) remains available and
// is represented by the custom control.
const _kMeditationPresetMinutes = [5, 10, 15, 30];

/// How long the session controls stay up before the screen settles into the
/// ring alone. Long enough to reach pause without chasing it, short enough
/// that a sitting is not spent looking at buttons.
const _kSessionControlsDelay = Duration(seconds: 6);

/// How long a nature sound plays when it is picked on the setup screen.
const _kAmbientPreview = Duration(seconds: 6);

enum _TimerStatus { idle, running, paused, done }

/// Meditation timer with wakelock during sessions and haptic completion.
///
/// Uses the same wakelock_plus approach as the reader. How completion is
/// announced follows the user's setting; see [CompletionSignal].
class MeditationTimerScreen extends ConsumerStatefulWidget {
  const MeditationTimerScreen({super.key});

  @override
  ConsumerState<MeditationTimerScreen> createState() =>
      _MeditationTimerScreenState();
}

class _MeditationTimerScreenState extends ConsumerState<MeditationTimerScreen> {
  late int _totalMinutes;
  late int _remainingSeconds;
  _TimerStatus _status = _TimerStatus.idle;
  Timer? _ticker;

  /// How the sitting is announced when it begins. Silent by default so the
  /// timer does not gain a sound for anyone already using it.
  late CompletionSignal _startSignal;

  /// Nature sound looped under the sitting, and how loud, 0-1.
  late AmbientSound _ambient;
  late double _ambientVolume;

  /// Held from `initState`: `dispose` must silence the loop and cannot use
  /// `ref` to find it.
  late final AmbientSoundPlayer _ambientPlayer;

  /// Ends the short preview a sound gets when it is picked on setup.
  Timer? _previewTimer;

  /// Held from `initState` for the same reason: a sitting abandoned by
  /// leaving the screen is logged from `dispose`.
  late final PracticeLogController _practiceLog;

  /// Controls and ornament recede while sitting and a tap brings them back;
  /// the ring is what stays. Same gesture as the reading screen's immersive
  /// mode, so there is one thing to learn rather than two.
  bool _controlsVisible = true;
  Timer? _controlsTimer;

  /// Shown once each time the controls leave, so the tap is discoverable.
  bool _tapHintVisible = false;

  /// A sitting renders on the app's own dark ground whatever the device theme
  /// is; built once because this screen rebuilds every second.
  late final ThemeData _dimTheme = AppTheme.dark();

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(prefsServiceProvider);
    _totalMinutes = prefs.getMeditationMinutes();
    _remainingSeconds = _totalMinutes * 60;
    _startSignal = CompletionSignal.fromName(
      prefs.getMeditationStartSignal() ?? CompletionSignal.silent.name,
    );
    _ambient = ambientSoundSupported
        ? AmbientSound.fromName(prefs.getMeditationAmbient())
        : AmbientSound.none;
    _ambientVolume =
        prefs.getMeditationAmbientVolume() ?? kAmbientDefaultVolume;
    _ambientPlayer = ref.read(ambientSoundPlayerProvider);
    _practiceLog = ref.read(practiceLogControllerProvider.notifier);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _controlsTimer?.cancel();
    if (_previewTimer?.isActive ?? false) {
      _previewTimer!.cancel();
      unawaited(_ambientPlayer.stop());
    }
    if (_status == _TimerStatus.running) {
      WakelockPlus.disable().catchError((_) {});
    }
    if (_status == _TimerStatus.running || _status == _TimerStatus.paused) {
      unawaited(_ambientPlayer.stop());
      _logSitting(deferred: true);
    }
    // Unconditional: leaving with the bars hidden hides them on every screen
    // after this one.
    unawaited(setSystemBarsHidden(false));
    super.dispose();
  }

  void _selectMinutes(int minutes) {
    setState(() {
      _totalMinutes = minutes;
      _remainingSeconds = minutes * 60;
      _status = _TimerStatus.idle;
    });
    ref.read(prefsServiceProvider).setMeditationMinutes(minutes);
  }

  /// Opens the custom-minute dialog.
  Future<void> _promptCustomMinutes() async {
    final minutes = await showDialog<int>(
      context: context,
      builder: (context) => CustomMinutesDialog(
        initialMinutes: _totalMinutes,
        maxMinutes: kMeditationMaxMinutes,
        withHours: true,
      ),
    );
    if (minutes != null) _selectMinutes(minutes);
  }

  Future<void> _promptStartSignal() async {
    final l10n = AppLocalizations.of(context);
    final chosen = await _pickOption<CompletionSignal>(
      title: l10n.meditationStartSignal,
      options: CompletionSignal.values,
      current: _startSignal,
      labelOf: (s) => s.label(l10n),
    );
    if (chosen == null) return;
    setState(() => _startSignal = chosen);
    unawaited(
      ref.read(prefsServiceProvider).setMeditationStartSignal(chosen.name),
    );
    _previewBell(chosen);
  }

  /// Rings the bell when it is the signal just chosen, the way picking a
  /// nature sound plays it.
  void _previewBell(CompletionSignal chosen) {
    if (chosen != CompletionSignal.sound) return;
    unawaited(
      ref
          .read(completionSignalPlayerProvider)
          .preview(
            volume: ref.read(settingsControllerProvider).completionVolume,
          ),
    );
  }

  Future<void> _promptEndSignal() async {
    final l10n = AppLocalizations.of(context);
    final settings = ref.read(settingsControllerProvider);
    final chosen = await _pickOption<CompletionSignal>(
      title: l10n.meditationEndSignal,
      options: CompletionSignal.values,
      current: settings.completionSignal,
      labelOf: (s) => s.label(l10n),
    );
    if (chosen == null) return;
    // The same setting Settings edits, so the choice follows the user there.
    ref.read(settingsControllerProvider.notifier).setCompletionSignal(chosen);
    _previewBell(chosen);
  }

  Future<void> _promptAmbient() async {
    final l10n = AppLocalizations.of(context);
    final chosen = await _pickOption<AmbientSound>(
      title: l10n.meditationAmbient,
      options: AmbientSound.values,
      current: _ambient,
      labelOf: (s) => s.label(l10n),
    );
    if (chosen == null || !mounted) return;
    setState(() => _ambient = chosen);
    unawaited(ref.read(prefsServiceProvider).setMeditationAmbient(chosen.name));
    _previewTimer?.cancel();
    if (_status == _TimerStatus.running) {
      // Changed mid-sitting, the new sound takes over at once.
      unawaited(_ambientPlayer.start(chosen, _ambientVolume));
    } else if (_status == _TimerStatus.idle && chosen != AmbientSound.none) {
      // On setup the choice is heard for a moment, so it is not picked blind;
      // then it waits for the clock.
      unawaited(_ambientPlayer.start(chosen, _ambientVolume));
      _previewTimer = Timer(_kAmbientPreview, () {
        if (mounted && _status == _TimerStatus.idle) {
          unawaited(_ambientPlayer.stop(fade: true));
        }
      });
    } else {
      unawaited(_ambientPlayer.stop());
    }
  }

  void _setAmbientVolume(double volume) {
    setState(() => _ambientVolume = volume);
    unawaited(_ambientPlayer.setVolume(volume));
    // A drag is the user still using the controls; do not fade them away
    // from under the thumb.
    if (_status == _TimerStatus.running) _scheduleControlsHide();
  }

  /// One picker for every option row; returns null on cancel.
  ///
  /// `RadioListTile`'s group API is deprecated in favour of a `RadioGroup`
  /// ancestor, which buys nothing for a list that closes on the first tap.
  Future<T?> _pickOption<T>({
    required String title,
    required List<T> options,
    required T current,
    required String Function(T) labelOf,
  }) {
    final dialogTheme = _screenTheme(context);
    final scheme = dialogTheme.colorScheme;
    return showDialog<T>(
      context: context,
      builder: (ctx) => Theme(
        data: dialogTheme,
        child: SimpleDialog(
          title: Text(title),
          children: [
            for (final option in options)
              SimpleDialogOption(
                key: ValueKey('meditation_option_$option'),
                onPressed: () => Navigator.pop(ctx, option),
                child: Row(
                  children: [
                    Icon(
                      option == current
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: option == current
                          ? scheme.secondary
                          : scheme.onSurfaceVariant,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(labelOf(option))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _start() {
    WakelockPlus.enable().catchError((_) {});
    // Starting from a finished sitting is a new sitting of the same length.
    // The clock was left at zero, and counting on from there ended it again
    // on the first tick.
    if (_status == _TimerStatus.done) {
      _status = _TimerStatus.idle;
      _remainingSeconds = _totalMinutes * 60;
    }
    if (_status == _TimerStatus.idle) {
      unawaited(
        ref
            .read(completionSignalPlayerProvider)
            .playOnce(
              _startSignal,
              volume: ref.read(settingsControllerProvider).completionVolume,
            ),
      );
    }
    _previewTimer?.cancel();
    unawaited(_ambientPlayer.start(_ambient, _ambientVolume));
    setState(() => _status = _TimerStatus.running);
    _scheduleControlsHide();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingSeconds <= 1) {
        _finish();
        return;
      }
      setState(() => _remainingSeconds--);
    });
  }

  /// Counts the time sat so far toward the daily goal, the same log the
  /// reading screen writes to. Only the clock's own seconds count, so time
  /// spent paused does not.
  ///
  /// [deferred] is for `dispose`: the widget tree is locked then and Riverpod
  /// forbids notifying the home ring, so the write waits a microtask.
  void _logSitting({bool deferred = false}) {
    final seconds = _totalMinutes * 60 - _remainingSeconds;
    if (seconds <= 0) return;
    final log = _practiceLog;
    final now = DateTime.now();
    if (deferred) {
      Future.microtask(() => log.addSeconds(seconds, now: now));
    } else {
      log.addSeconds(seconds, now: now);
    }
  }

  void _pause() {
    _ticker?.cancel();
    WakelockPlus.disable().catchError((_) {});
    unawaited(_ambientPlayer.pause());
    setState(() => _status = _TimerStatus.paused);
    _revealControls();
  }

  void _reset() {
    _ticker?.cancel();
    WakelockPlus.disable().catchError((_) {});
    unawaited(_ambientPlayer.stop());
    // Ended early: what was sat still counts. A finished sitting was logged
    // by `_finish` and is `done` by now.
    if (_status == _TimerStatus.running || _status == _TimerStatus.paused) {
      _logSitting();
    }
    setState(() {
      _status = _TimerStatus.idle;
      _remainingSeconds = _totalMinutes * 60;
    });
    _revealControls();
  }

  /// The theme this screen is drawn in right now.
  ///
  /// A sitting installs its own dark ground inside `build`, but `showDialog`
  /// builds from the navigator — above that `Theme` — so an option picker
  /// opened mid-sitting comes up cream on a dark screen unless it is handed
  /// the same data.
  ThemeData _screenTheme(BuildContext context) {
    final ambient = Theme.of(context);
    final sitting =
        _status == _TimerStatus.running || _status == _TimerStatus.paused;
    return sitting && ambient.brightness == Brightness.light
        ? _dimTheme
        : ambient;
  }

  /// Let the controls go after a moment so a running sitting settles into the
  /// ring. Only while running — pausing means the user wants the buttons.
  void _scheduleControlsHide() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(_kSessionControlsDelay, () {
      if (!mounted || _status != _TimerStatus.running) return;
      _hideControls(hint: true);
    });
  }

  void _hideControls({required bool hint}) {
    _controlsTimer?.cancel();
    setState(() {
      _controlsVisible = false;
      _tapHintVisible = hint;
    });
    // Hides the status/navigation bars on mobile; a no-op on web and desktop.
    unawaited(setSystemBarsHidden(true));
    if (!hint) return;
    Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _tapHintVisible = false);
    });
  }

  /// Bring the controls back, and the system bars with them.
  void _revealControls({bool thenHide = false}) {
    _controlsTimer?.cancel();
    if (!_controlsVisible || _tapHintVisible) {
      setState(() {
        _controlsVisible = true;
        _tapHintVisible = false;
      });
      unawaited(setSystemBarsHidden(false));
    }
    if (thenHide) _scheduleControlsHide();
  }

  void _toggleControls() {
    if (_controlsVisible) {
      _hideControls(hint: false);
    } else {
      _revealControls(thenHide: _status == _TimerStatus.running);
    }
  }

  Future<void> _finish() async {
    _ticker?.cancel();
    unawaited(WakelockPlus.disable().catchError((_) {}));
    // Eased out rather than cut, so the end is the bell arriving.
    unawaited(_ambientPlayer.stop(fade: true));
    setState(() {
      _status = _TimerStatus.done;
      _remainingSeconds = 0;
    });
    _logSitting();
    _revealControls();
    // How the end is announced is the user's choice (sound / vibrate / silent);
    // the player owns that, so this screen does not branch on it.
    final settings = ref.read(settingsControllerProvider);
    await ref
        .read(completionSignalPlayerProvider)
        .play(settings.completionSignal, volume: settings.completionVolume);
  }

  static String _format(int seconds) {
    String pad(int n) => n.toString().padLeft(2, '0');
    final h = seconds ~/ 3600;
    final m = seconds % 3600 ~/ 60;
    final s = seconds % 60;
    // Hours only once there are some: a sitting can now run most of a day,
    // and "1380:00" is not a time anyone reads.
    return h > 0 ? '$h:${pad(m)}:${pad(s)}' : '${pad(m)}:${pad(s)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final totalSeconds = _totalMinutes * 60;
    final progress = totalSeconds == 0
        ? 0.0
        : (totalSeconds - _remainingSeconds) / totalSeconds;
    final running = _status == _TimerStatus.running;
    final paused = _status == _TimerStatus.paused;
    final sessionActive = running || paused;
    final done = _status == _TimerStatus.done;
    final endSignal = ref.watch(settingsControllerProvider).completionSignal;
    // Custom value not represented by presets; the custom chip displays it.
    final isCustom = !_kMeditationPresetMinutes.contains(_totalMinutes);

    // Leaving mid-sitting used to pop the route, which cancelled the ticker
    // in `dispose` with nothing said — and now that a sitting has no bar, the
    // system gesture would be the only way out. Both land on setup instead.
    return PopScope(
      canPop: !sessionActive,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && sessionActive) _reset();
      },
      // The ground dims for the sitting whatever the device theme is: the
      // screen is held awake for half an hour, often in a dark room, and the
      // cream the artwork was drawn for is the wrong thing to stare into.
      //
      // Switched rather than cross-faded. `AnimatedTheme` asserts on this pair
      // — `GoogleFonts` text styles carry `inherit: false` and cannot be lerped
      // against a plain `ThemeData`'s — and there is nothing to smooth over
      // anyway: the body is replaced wholesale on the same frame.
      child: Theme(
        data: _screenTheme(context),
        child: Builder(
          builder: (context) {
            final theme = Theme.of(context);
            final scheme = theme.colorScheme;
            return Scaffold(
              // Setting a duration is a form, so it keeps the bar and the corner
              // ornament. A sitting is the opposite of a form: it sheds the bar
              // entirely, which is also why nothing there needs a turned chevron.
              appBar: sessionActive
                  ? null
                  : AppBar(
                      centerTitle: true,
                      toolbarHeight: 88,
                      backgroundColor: Colors.transparent,
                      surfaceTintColor: Colors.transparent,
                      titleTextStyle: theme.textTheme.headlineSmall?.copyWith(
                        fontFamily: theme.textTheme.bodyLarge?.fontFamily,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                      leading: const AppBackButton(),
                      leadingWidth: 64,
                      // Same head piece as the home screen's header.
                      flexibleSpace: const FloralCorners.head(
                        top: -13,
                        horizontal: -8,
                      ),
                      title: Text(l10n.meditationTitle),
                    ),
              body: SafeArea(
                child: ContentWidth(
                  maxWidth: ContentWidth.composedWidth,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      if (sessionActive) {
                        final totalSeconds = _totalMinutes * 60;
                        final remainingProgress = totalSeconds == 0
                            ? 0.0
                            : _remainingSeconds / totalSeconds;
                        return MeditationSessionView(
                          time: _format(_remainingSeconds),
                          totalMinutes: _totalMinutes,
                          progress: remainingProgress.clamp(0.0, 1.0),
                          running: running,
                          endSignal: endSignal.label(l10n),
                          onPrimary: running ? _pause : _start,
                          onReset: _reset,
                          onEnd: _reset,
                          onSignal: _promptEndSignal,
                          ambient: _ambient,
                          ambientVolume: _ambientVolume,
                          onAmbient: _promptAmbient,
                          onAmbientVolume: _setAmbientVolume,
                          onAmbientVolumeEnd: (volume) => ref
                              .read(prefsServiceProvider)
                              .setMeditationAmbientVolume(volume),
                          controls: _controlsVisible,
                          tapHint: _tapHintVisible,
                          onTapBackground: _toggleControls,
                        );
                      }
                      // The artwork gives the ring just over half the screen width;
                      // cap it so it does not swallow a tablet column.
                      final ring = math.min(constraints.maxWidth * 0.56, 300.0);
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                        children: [
                          MeditationTimerHero(
                            size: ring,
                            progress: progress.clamp(0.0, 1.0),
                            time: _format(_remainingSeconds),
                            unit: done
                                ? l10n.meditationDone
                                : l10n.homeGoalUnit,
                            done: done,
                          ),
                          const SizedBox(height: 22),
                          Row(
                            spacing: 7,
                            children: [
                              for (final minutes in _kMeditationPresetMinutes)
                                Expanded(
                                  child: DurationChip(
                                    key: ValueKey('meditation_preset_$minutes'),
                                    label: l10n.meditationMinutes(minutes),
                                    selected: _totalMinutes == minutes,
                                    onTap: running
                                        ? null
                                        : () => _selectMinutes(minutes),
                                  ),
                                ),
                              Expanded(
                                child: DurationChip(
                                  key: const ValueKey('meditation_custom'),
                                  label: isCustom
                                      ? meditationDurationLabel(
                                          l10n,
                                          _totalMinutes,
                                        )
                                      : l10n.meditationCustom,
                                  selected: isCustom,
                                  onTap: running ? null : _promptCustomMinutes,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          OptionsCard(
                            rows: [
                              OptionRow(
                                key: const ValueKey('meditation_start_signal'),
                                icon: Icons.notifications_none_rounded,
                                label: l10n.meditationStartSignal,
                                value: _startSignal.label(l10n),
                                onTap: running ? null : _promptStartSignal,
                              ),
                              if (ambientSoundSupported)
                                OptionRow(
                                  key: const ValueKey('meditation_ambient'),
                                  icon: Icons.music_note_outlined,
                                  label: l10n.meditationBackground,
                                  value: _ambient.label(l10n),
                                  onTap: running ? null : _promptAmbient,
                                ),
                              OptionRow(
                                key: const ValueKey('meditation_end_signal'),
                                icon: Icons.alarm,
                                label: l10n.meditationEndSignal,
                                value: endSignal.label(l10n),
                                onTap: running ? null : _promptEndSignal,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          if (running)
                            GoldenPillButton(
                              key: const ValueKey('meditation_pause'),
                              label: l10n.meditationPause,
                              icon: const Icon(Icons.pause_rounded),
                              height: 58,
                              expand: true,
                              onPressed: _pause,
                            )
                          else
                            GoldenPillButton(
                              key: const ValueKey('meditation_start'),
                              label: _status == _TimerStatus.paused
                                  ? l10n.meditationResume
                                  : l10n.meditationStartLong,
                              icon: const AppAssetImage(
                                'assets/images/meditation/meditation_lotus_play.png',
                                width: 52,
                                height: 34,
                                fit: BoxFit.contain,
                              ),
                              height: 58,
                              expand: true,
                              onPressed: _start,
                            ),
                          if (_status != _TimerStatus.idle) ...[
                            const SizedBox(height: 10),
                            Center(
                              child: TextButton.icon(
                                key: const ValueKey('meditation_reset'),
                                onPressed: _reset,
                                icon: const Icon(Icons.replay, size: 18),
                                label: Text(l10n.meditationReset),
                                style: TextButton.styleFrom(
                                  foregroundColor: scheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Text(
                            l10n.meditationScreenOnNote,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
