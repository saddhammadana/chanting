import 'package:flutter/material.dart';

import '../../../data/local/ambient_sound.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/sound_volume_card.dart';

/// The glyph each nature sound is shown with, here and in the setup row.
IconData ambientSoundIcon(AmbientSound sound) => switch (sound) {
  AmbientSound.none => Icons.music_off_outlined,
  AmbientSound.forestStream => Icons.water,
  AmbientSound.rain => Icons.water_drop_outlined,
  AmbientSound.forestBirds => Icons.forest_outlined,
  AmbientSound.seaWaves => Icons.tsunami,
};

/// Session card for the nature sound: the head opens the picker, the slider
/// underneath sets how loud it is.
///
/// Two separate targets rather than one tappable card, so dragging the slider
/// can never open the picker.
class SessionAmbientCard extends StatelessWidget {
  const SessionAmbientCard({
    super.key,
    required this.sound,
    required this.volume,
    required this.onPick,
    required this.onVolume,
    required this.onVolumeEnd,
  });

  final AmbientSound sound;

  /// 0-1.
  final double volume;
  final VoidCallback onPick;
  final ValueChanged<double> onVolume;
  final ValueChanged<double> onVolumeEnd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SoundVolumeCard(
      icon: ambientSoundIcon(sound),
      title: l10n.meditationAmbient,
      subtitle: sound.label(l10n),
      volume: volume,
      sliderLabel: l10n.meditationAmbientVolume,
      // No sound chosen means nothing to turn up.
      enabled: sound != AmbientSound.none,
      onPick: onPick,
      onVolume: onVolume,
      onVolumeEnd: onVolumeEnd,
      pickKey: const ValueKey('meditation_ambient_pick'),
      sliderKey: const ValueKey('meditation_ambient_volume'),
    );
  }
}
