import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../prayer_list/prayer_list_controller.dart';
import 'edit_decorations.dart';

/// "ทั้งหมด" and one chip per category, scrolling sideways.
class SectionChips extends StatelessWidget {
  const SectionChips({
    super.key,
    required this.sections,
    required this.selectedId,
    required this.onSelected,
  });

  final List<SectionPrayers> sections;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final dark = theme.brightness == Brightness.dark;
    Widget chip(String label, String? id) {
      final selected = selectedId == id;
      return Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          showCheckmark: false,
          onSelected: (_) => onSelected(id),
          backgroundColor: editBeige(theme),
          selectedColor: dark ? AppColors.darkGold : AppColors.gold,
          labelStyle: theme.textTheme.labelLarge?.copyWith(
            color: selected
                ? (dark ? AppColors.darkBackground : Colors.white)
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip(l10n.playlistFilterAll, null),
          for (final entry in sections)
            chip(entry.section.title, entry.section.id),
        ],
      ),
    );
  }
}
