import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/golden_pill_button.dart';
import 'edit_decorations.dart';

/// "เริ่มสวดทั้งชุด": the gold play button that chants the set in order.
class PlaylistDetailPlayAllCard extends StatelessWidget {
  const PlaylistDetailPlayAllCard({
    super.key,
    required this.count,
    required this.onPlay,
  });

  final int count;

  /// Null for an empty set, which has nothing to chant.
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    // The edit page's card face — soft edge and soft shadow — so the set's
    // two pages frame their main card alike.
    final decoration = editPanelDecoration(theme);
    final radius = decoration.borderRadius! as BorderRadius;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.playlistPlayAll,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (count > 0) ...[
          const SizedBox(height: 2),
          Text(
            l10n.playlistPlayAllDetail(count),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
    return DecoratedBox(
      decoration: decoration,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: onPlay,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Row(
              children: [
                if (onPlay != null) ...[
                  ExcludeSemantics(
                    // The card is the button; this circle only marks it.
                    child: GoldenIconButton(
                      icon: const Icon(Icons.play_arrow_rounded, size: 32),
                      tooltip: l10n.playlistPlayAll,
                      size: 54,
                      onPressed: onPlay!,
                    ),
                  ),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: onPlay == null
                      ? text
                      : Semantics(button: true, child: text),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
