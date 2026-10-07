import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/prayer.dart';
import '../../../shared/widgets/content_width.dart';

/// Bottom bar: **"where to go next"** — previous/next prayer buttons only.
///
/// Progress and the "prayer n/m" label moved to the top [ReadingTopBar] so
/// both reading modes keep that information in the same place. Continuous mode
/// has no bottom bar to host it.
class NeighborBar extends StatelessWidget {
  const NeighborBar({
    super.key,
    required this.prev,
    required this.next,
    this.playlistId,
    this.sectionId,
  });

  final Prayer? prev;
  final Prayer? next;
  final String? playlistId;
  final String? sectionId;

  /// Path to another prayer while preserving playlist/section context and page-turn direction.
  String _pathTo(String id, String dir) =>
      '/prayer/$id?dir=$dir'
      '${playlistId == null ? '' : '&pl=$playlistId'}'
      '${sectionId == null ? '' : '&section=$sectionId'}';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      // The background and top border span the screen, but the contents must
      // stay in the same column as the prayer text. Otherwise desktop layouts
      // stretch the progress bar across the window while the text stays around
      // 700px wide, and the "prayer 1/8" label drifts far from the content.
      child: SafeArea(
        child: ContentWidth(
          // bottomNavigationBar passes the screen height as maxHeight, not
          // infinity. Do not fill it, or the bar expands over the whole screen.
          fillHeight: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Progress and the "prayer n/m" label live in [ReadingTopBar].
                // This row only answers "where to go next".
                // If only one button remains, it should take the full row.
                // A previous Spacer reserved half the row on first/last prayers,
                // making the single button look accidentally offset.
                Row(
                  children: [
                    if (prev != null)
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () => context.pushReplacement(
                            _pathTo(prev!.id, 'prev'),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: scheme.onSurface.withValues(
                              alpha: 0.75,
                            ),
                            shape: const StadiumBorder(),
                          ),
                          icon: const Icon(Icons.chevron_left),
                          label: Text(
                            prev!.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    if (prev != null && next != null) const SizedBox(width: 8),
                    if (next != null)
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () => context.pushReplacement(
                            _pathTo(next!.id, 'next'),
                          ),
                          style: TextButton.styleFrom(
                            backgroundColor: scheme.secondaryContainer,
                            foregroundColor: scheme.onSecondaryContainer,
                            shape: const StadiumBorder(),
                          ),
                          iconAlignment: IconAlignment.end,
                          icon: const Icon(Icons.chevron_right),
                          label: Text(
                            next!.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
