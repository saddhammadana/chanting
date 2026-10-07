import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../l10n/app_localizations.dart';
import 'completion_signal.dart';

/// The nature sound that plays under a meditation sitting.
///
/// See docs/architecture/audio.md and assets/sound/README.md for provenance.
enum AmbientSound {
  /// Nothing. The default, so the timer gains no sound for existing users.
  none(null),
  forestStream('assets/sound/ambient/forest_stream.mp3'),
  rain('assets/sound/ambient/rain.mp3'),
  forestBirds('assets/sound/ambient/forest_birds.mp3'),
  seaWaves('assets/sound/ambient/sea_waves.mp3');

  const AmbientSound(this.asset);

  /// Bundled loop, or null for [none].
  final String? asset;

  static AmbientSound fromName(String? name) => AmbientSound.values.firstWhere(
    (e) => e.name == name,
    orElse: () => AmbientSound.none,
  );
}

/// The user-visible name of an ambient sound.
extension AmbientSoundLabel on AmbientSound {
  String label(AppLocalizations l10n) => switch (this) {
    AmbientSound.none => l10n.ambientNone,
    AmbientSound.forestStream => l10n.ambientForestStream,
    AmbientSound.rain => l10n.ambientRain,
    AmbientSound.forestBirds => l10n.ambientForestBirds,
    AmbientSound.seaWaves => l10n.ambientSeaWaves,
  };
}

/// Volume a first-time listener gets; a background, not a foreground.
const kAmbientDefaultVolume = 0.5;

/// Loops one [AmbientSound] for as long as a sitting runs.
///
/// A plain class so tests can substitute a recording fake. Every audio failure
/// is swallowed: a sitting must run to its end with or without sound.
class AmbientSoundPlayer {
  AmbientSoundPlayer();

  AudioPlayer? _player;
  AmbientSound _loaded = AmbientSound.none;
  double _volume = kAmbientDefaultVolume;

  /// Bumped by every command so a fade still in flight knows it was overtaken.
  int _generation = 0;

  /// Plays [sound] on a loop, resuming where it was if it is already loaded.
  Future<void> start(AmbientSound sound, double volume) async {
    final asset = sound.asset;
    if (asset == null) return stop();
    final generation = ++_generation;
    _volume = volume;
    try {
      await configureMixingAudioSession();
      final player = _player ??= await _create();
      if (_loaded != sound) {
        // Swapping the source under a playing player leaves the old loop
        // running on some backends, and `play` is a no-op while `playing` is
        // already true; stopping first makes the change audible everywhere.
        if (player.playing) await player.stop();
        await player.setAsset(asset);
        await player.setLoopMode(LoopMode.one);
        _loaded = sound;
      }
      if (generation != _generation) return;
      await player.setVolume(volume);
      // `play` completes only when playback stops, which a loop never does.
      unawaited(
        player.play().catchError((Object e) {
          debugPrint('ambient sound failed: $e');
        }),
      );
    } catch (e) {
      debugPrint('ambient sound failed: $e');
    }
  }

  /// The shared session describes the bell as a notification; this player
  /// opts out of that so the loop follows the media volume on Android.
  Future<AudioPlayer> _create() async {
    final player = AudioPlayer(androidApplyAudioAttributes: false);
    await player.setAndroidAudioAttributes(
      const AndroidAudioAttributes(
        contentType: AndroidAudioContentType.music,
        usage: AndroidAudioUsage.media,
      ),
    );
    return player;
  }

  /// Holds the loop where it is; [start] with the same sound picks it up.
  Future<void> pause() async {
    ++_generation;
    try {
      await _player?.pause();
    } catch (e) {
      debugPrint('ambient sound failed: $e');
    }
  }

  Future<void> setVolume(double volume) async {
    _volume = volume;
    try {
      await _player?.setVolume(volume);
    } catch (e) {
      debugPrint('ambient sound failed: $e');
    }
  }

  /// Ends the loop. With [fade] it eases out first, so the end of a sitting
  /// is the bell arriving rather than the forest being cut off.
  Future<void> stop({bool fade = false}) async {
    final generation = ++_generation;
    final player = _player;
    _loaded = AmbientSound.none;
    if (player == null) return;
    try {
      if (fade && player.playing) {
        for (var step = 5; step >= 0; step--) {
          await player.setVolume(_volume * step / 6);
          await Future<void>.delayed(const Duration(milliseconds: 200));
          if (generation != _generation) return;
        }
      }
      await player.stop();
    } catch (e) {
      debugPrint('ambient sound failed: $e');
    }
  }

  Future<void> dispose() async {
    ++_generation;
    try {
      await _player?.dispose();
    } catch (_) {
      // Non-fatal cleanup failure.
    }
    _player = null;
  }
}

/// True where a nature sound can actually be produced.
///
/// Unlike the bell, the web is included: the loop starts from the tap that
/// starts the sitting, which is the user gesture browsers ask for.
bool get ambientSoundSupported => true;

final ambientSoundPlayerProvider = Provider<AmbientSoundPlayer>((ref) {
  final player = AmbientSoundPlayer();
  ref.onDispose(player.dispose);
  return player;
});
