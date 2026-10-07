import 'package:flutter/material.dart';

import '../../../data/models/prayer.dart';
import '../prayer_list_controller.dart' show SectionPrayers;
import 'prayer_card.dart';

/// Prayer list grouped by section with section headers. Used by home search
/// results and the "all prayers" page.
class GroupedPrayerList extends StatelessWidget {
  const GroupedPrayerList({
    super.key,
    required this.sections,
    required this.onTapPrayer,
    this.highlight = '',
  });

  final List<SectionPrayers> sections;
  final void Function(Prayer prayer) onTapPrayer;
  final String highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      itemCount: sections.length,
      itemBuilder: (context, index) {
        final entry = sections[index];
        final prayers = entry.prayers;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 16,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    entry.section.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.secondary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(child: Divider()),
                ],
              ),
            ),
            // Number within each section. A prayer can appear in multiple
            // sections at different positions, so this is not a global order.
            for (final (i, prayer) in prayers.indexed)
              PrayerCard(
                prayer: prayer,
                order: i + 1,
                highlight: highlight,
                onTap: () => onTapPrayer(prayer),
              ),
          ],
        );
      },
    );
  }
}
