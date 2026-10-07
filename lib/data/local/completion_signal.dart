import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, debugPrint, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart' show HapticFeedback, MethodChannel;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../l10n/app_localizations.dart';

/// How the app announces that a timed session has finished.
///
/// See docs/architecture/audio.md for the audio-session policy.
enum CompletionSignal {
  /// Singing bowl plus haptic pulses.
  sound,

  /// Three heavy pulses. The original behaviour and still the default.
  haptic,

  /// Nothing.
  silent;

  static CompletionSignal fromName(String name) => CompletionSignal.values
      .firstWhere((e) => e.name == name, orElse: () => CompletionSignal.haptic);
}

/// The user-visible name of a completion signal.
extension CompletionSignalLabel on CompletionSignal {
  String label(AppLocalizations l10n) => switch (this) {
    CompletionSignal.sound => l10n.completionSignalSound,
    CompletionSignal.haptic => l10n.completionSignalHaptic,
    CompletionSignal.silent => l10n.completionSignalSilent,
  };
}

bool _sessionConfigured = false;

/// Claims the audio session as a short notification, not as a music player.
///
/// The session is app-wide, so the bell and the meditation nature sound share
/// this one configuration: both mix with other apps rather than stopping them.
Future<void> configureMixingAudioSession() async {
  if (_sessionConfigured) return;
  _sessionConfigured = true;
  final session = await AudioSession.instance;
  await session.configure(
    const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.ambient,
      avAudioSessionCategoryOptions:
          AVAudioSessionCategoryOptions.mixWithOthers,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.sonification,
        usage: AndroidAudioUsage.notification,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
      androidWillPauseWhenDucked: false,
    ),
  );
}

/// Plays the end-of-session signal.
///
/// Owns the reusable audio player and gives tests a replaceable dependency.
class CompletionSignalPlayer {
  CompletionSignalPlayer();

  static const asset = 'assets/sound/singing_bowl.mp3';

  AudioPlayer? _player;

  /// Signals completion in the way [signal] asks for.
  ///
  /// Returns once the *haptics* are done, not once the bowl has finished
  /// ringing: the tail is nine seconds long and nothing should wait on it.
  ///
  /// [volume] is the bell's own, 0-1, on top of the device's media volume.
  Future<void> play(CompletionSignal signal, {double volume = 1}) async {
    if (signal == CompletionSignal.silent) return;
    // Sound and haptics together; silent phones still get haptics.
    if (signal == CompletionSignal.sound) {
      unawaited(_playBowl(volume));
    }
    await _pulse();
  }

  /// The bell alone, so a choice or a volume can be heard as it is made.
  /// No vibration: nothing has finished.
  Future<void> preview({double volume = 1}) => _playBowl(volume);

  /// A single, lighter announcement — the start of a sitting, or the warning
  /// before its end. [play]'s three heavy pulses read as "finished".
  Future<void> playOnce(CompletionSignal signal, {double volume = 1}) async {
    if (signal == CompletionSignal.silent) return;
    if (signal == CompletionSignal.sound) unawaited(_playBowl(volume));
    await _buzz(120, HapticFeedback.mediumImpact);
  }

  Future<void> _pulse() async {
    for (var i = 0; i < 3; i++) {
      await _buzz(250, HapticFeedback.heavyImpact);
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
  }

  static const _vibrateChannel = MethodChannel('th.chanting.app/vibrate');

  /// One pulse. Android drives the vibrator directly (see `MainActivity`):
  /// [HapticFeedback] there is touch feedback, which the system drops when
  /// "touch vibration" is off — most phones, so the signal never arrived.
  Future<void> _buzz(int ms, Future<void> Function() fallback) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _vibrateChannel.invokeMethod<void>('vibrate', {'ms': ms});
        return;
      } catch (_) {
        // No handler (tests, an embedder without MainActivity): fall through.
      }
    }
    await fallback();
  }

  /// On Android the bell follows the media volume, not the ringer.
  ///
  /// The shared session calls it a notification, and Android mutes that
  /// stream whenever the phone is on silent or vibrate — which is how a phone
  /// is usually left during a sitting, so the bell someone chose never rang.
  /// The nature sound already opts out the same way.
  Future<AudioPlayer> _createPlayer() async {
    final player = AudioPlayer(androidApplyAudioAttributes: false);
    await player.setAndroidAudioAttributes(
      const AndroidAudioAttributes(
        contentType: AndroidAudioContentType.sonification,
        usage: AndroidAudioUsage.media,
      ),
    );
    return player;
  }

  /// Starts the bowl from the beginning. Audio failures are non-fatal.
  Future<void> _playBowl(double volume) async {
    if (!completionSoundSupported) return;
    try {
      await configureMixingAudioSession();
      final player = _player ??= await _createPlayer();
      await player.setVolume(volume.clamp(0.0, 1.0));
      await player.setAsset(asset);
      await player.play();
    } catch (e) {
      debugPrint('completion sound failed: $e');
    }
  }

  Future<void> dispose() async {
    try {
      await _player?.dispose();
    } catch (_) {
      // Non-fatal cleanup failure.
    }
    _player = null;
  }
}

/// True where a completion sound can actually be produced.
bool get completionSoundSupported => !kIsWeb;

final completionSignalPlayerProvider = Provider<CompletionSignalPlayer>((ref) {
  final player = CompletionSignalPlayer();
  ref.onDispose(player.dispose);
  return player;
});
