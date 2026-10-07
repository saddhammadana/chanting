import 'package:flutter/material.dart';

import '../../shared/widgets/responsive.dart';

/// Icon registry available to sections. `sections-*.json` stores **names** from
/// this table.
///
/// **Do not store codePoint and construct `IconData(...)` at runtime.** Flutter
/// enables icon tree-shaking by default for release builds and fails immediately
/// when it finds non-const IconData:
///
/// ```
/// This application cannot tree shake icons fonts.
/// It has non-constant instances of IconData at the following locations…
/// ```
///
/// Storing names and mapping them to const values is not just cleaner; it is the
/// only release-build-safe approach. It also trades unlimited flexibility for a
/// curated set, which is better for a prayer app than arbitrary Material icons.
///
/// **New names may be added, but existing names must not be removed or
/// repurposed.** Data files reference them; removing one silently falls back to
/// the default icon for affected sections.
const kSectionIcons = <String, IconData>{
  'book': Icons.menu_book_outlined,
  // `wb_sunny` is a midday sun and `nights_stay` is a moon behind a cloud that
  // reads as a smudge at tile size; both names keep their meaning, they just
  // point at glyphs that actually draw it.
  'sunrise': Icons.wb_twilight,
  'night': Icons.nightlight_outlined,
  'sparkle': Icons.auto_awesome_outlined,
  'shield': Icons.shield_moon_outlined,
  'hands': Icons.volunteer_activism_outlined,
  'meditate': Icons.self_improvement,
  'lotus': Icons.spa_outlined,
  'group': Icons.groups_outlined,
  'school': Icons.school_outlined,
  'heart': Icons.favorite_border,
  'star': Icons.star_outline,
  'water': Icons.water_drop_outlined,
  'flame': Icons.local_fire_department_outlined,
  'leaf': Icons.eco_outlined,
  'clock': Icons.schedule,
  'calendar': Icons.event_outlined,
  'peace': Icons.brightness_low_outlined,
};

/// Fallback icon name for sections without `icon`, or with unknown future data.
/// The fallback is intentionally neutral.
const kDefaultSectionIcon = 'book';

/// Convert an icon name to IconData, falling back to [kDefaultSectionIcon].
IconData sectionIcon(String? name) =>
    kSectionIcons[name] ?? kSectionIcons[kDefaultSectionIcon]!;

/// Value returned by [showSectionIconPicker] when the user resets to the section default.
///
/// Empty string is safe because real icon names cannot be empty; tests pin this.
const kResetSectionIcon = '';

/// Dialog for selecting an icon from the registry. Shared by the **prayer
/// editor**, which edits shipped app data, and **all sections**, which stores a
/// per-device user override.
///
/// Those flows write to different places and mean different things, but the icon
/// grid is identical. Keeping it here avoids adding new icons in two places.
///
/// Returns `null` for cancel, [kResetSectionIcon] for reset when [resetLabel] is
/// provided, otherwise the selected icon name.
Future<String?> showSectionIconPicker(
  BuildContext context, {
  required String title,
  required String? current,
  required String cancelLabel,
  String? resetLabel,
}) => showDialog<String>(
  context: context,
  builder: (ctx) => AlertDialog(
    title: Text(title),
    content: SizedBox(
      width: responsiveDialogWidth(ctx, maxWidth: 320),
      child: Wrap(
        children: [
          for (final entry in kSectionIcons.entries)
            IconButton(
              key: ValueKey('icon_choice_${entry.key}'),
              icon: Icon(entry.value),
              tooltip: entry.key,
              isSelected: entry.key == (current ?? kDefaultSectionIcon),
              selectedIcon: Icon(
                entry.value,
                color: Theme.of(ctx).colorScheme.primary,
              ),
              onPressed: () => Navigator.pop(ctx, entry.key),
            ),
        ],
      ),
    ),
    actions: [
      if (resetLabel != null)
        TextButton(
          key: const ValueKey('icon_reset'),
          onPressed: () => Navigator.pop(ctx, kResetSectionIcon),
          child: Text(resetLabel),
        ),
      TextButton(onPressed: () => Navigator.pop(ctx), child: Text(cancelLabel)),
    ],
  ),
);
