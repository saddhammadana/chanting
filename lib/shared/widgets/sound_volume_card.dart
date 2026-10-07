import 'package:flutter/material.dart';

import '../../theme/dashboard_tokens.dart';

/// A sound and how loud it is: an icon well, a title over the sound's name,
/// and a volume slider underneath.
///
/// One card for every sound the app plays — the nature sound under a sitting
/// and the completion bell — so both are set the same way. The head and the
/// slider are separate targets, so dragging the slider can never open a
/// picker.
class SoundVolumeCard extends StatelessWidget {
  const SoundVolumeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.volume,
    required this.sliderLabel,
    required this.onVolume,
    required this.onVolumeEnd,
    this.onPick,
    this.enabled = true,
    this.pickKey,
    this.sliderKey,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  /// 0-1.
  final double volume;

  /// What the slider is called to a screen reader.
  final String sliderLabel;
  final ValueChanged<double> onVolume;
  final ValueChanged<double> onVolumeEnd;

  /// Opens a picker from the head; null draws a head that is not a button.
  final VoidCallback? onPick;

  /// False when there is nothing to turn up: the slider is drawn disabled.
  final bool enabled;
  final Key? pickKey;
  final Key? sliderKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final gold = dark ? scheme.secondary : DashboardTokens.goldGlyph;

    final head = Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 6),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.secondaryContainer.withValues(
                alpha: dark ? 0.34 : 0.42,
              ),
              border: Border.all(
                color: scheme.secondary.withValues(alpha: 0.52),
              ),
            ),
            child: Icon(icon, color: gold, size: 27),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (onPick != null)
            Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: dark ? scheme.surface : DashboardTokens.tileFaceTop,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: dark
              ? scheme.secondary.withValues(alpha: 0.34)
              : DashboardTokens.cardEdge,
        ),
        boxShadow: dark
            ? null
            : [DashboardTokens.warmShadow(0.08, blur: 5, dy: 2)],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            if (onPick == null)
              head
            else
              Semantics(
                button: true,
                label: '$title, $subtitle',
                child: InkWell(
                  key: pickKey,
                  onTap: onPick,
                  child: ExcludeSemantics(child: head),
                ),
              ),
            Padding(
              // Lines the track up under the text column, as the artwork does.
              padding: const EdgeInsets.fromLTRB(74, 0, 18, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Slider(
                      key: sliderKey,
                      value: volume.clamp(0.0, 1.0),
                      semanticFormatterCallback: (value) =>
                          '${(value * 100).round()}%',
                      label: sliderLabel,
                      onChanged: enabled ? onVolume : null,
                      onChangeEnd: enabled ? onVolumeEnd : null,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    !enabled || volume == 0
                        ? Icons.volume_off_outlined
                        : Icons.volume_up_outlined,
                    color: enabled ? gold : scheme.onSurfaceVariant,
                    size: 26,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
