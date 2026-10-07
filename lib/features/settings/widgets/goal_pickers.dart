import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/dashboard_tokens.dart';

/// A time-of-day tile on the goal page: icon over label, gold when it is the
/// one being edited, with a check when its reminder is switched on.
///
/// Two marks because they are two different facts. The gold face answers
/// "which slot do the controls below belong to", and the check answers "will
/// this one actually notify me" — collapsing them would make selecting a tile
/// look like switching its reminder on.
class SlotTile extends StatelessWidget {
  const SlotTile({
    super.key,
    required this.icon,
    required this.label,
    required this.editing,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool editing;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final onGold = dark ? AppColors.darkBackground : Colors.white;
    // The artwork's selected tile is pale gold, so its label stays dark and
    // its icon is drawn in gold; dark mode keeps a dark glyph on its gold.
    final labelColor = editing && dark ? onGold : scheme.onSurface;
    final iconColor = editing
        ? (dark ? onGold : DashboardTokens.slotGlyph)
        : scheme.onSurface;

    return Semantics(
      button: true,
      selected: editing,
      label: label,
      child: Stack(
        // passthrough, or the Stack would size to the label and each tile
        // would come out a different width; Clip.none lets the badge overhang.
        fit: StackFit.passthrough,
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 76,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: editing
                    ? (dark
                          ? [AppColors.darkGold, AppColors.gold]
                          : const [
                              DashboardTokens.slotFaceTop,
                              DashboardTokens.slotFaceBottom,
                            ])
                    : (dark
                          ? [scheme.surface, scheme.surface]
                          : const [
                              DashboardTokens.tileFaceTop,
                              DashboardTokens.tileFaceBottom,
                            ]),
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: editing
                    ? (dark ? AppColors.goldDark : DashboardTokens.slotEdge)
                    : (dark
                          ? scheme.secondary.withValues(alpha: 0.34)
                          : DashboardTokens.tileEdge),
                width: editing ? 1.3 : 1,
              ),
              boxShadow: editing && !dark
                  ? [DashboardTokens.warmShadow(0.12, blur: 4, dy: 2)]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12.7),
                    border: editing && !dark
                        ? Border.all(color: DashboardTokens.slotRim, width: 1)
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 26, color: iconColor),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            label,
                            maxLines: 1,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: labelColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (enabled)
            PositionedDirectional(
              end: -5,
              top: -5,
              child: IgnorePointer(
                child: Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: dark ? AppColors.darkGold : AppColors.goldDark,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.scaffoldBackgroundColor,
                      width: 2,
                    ),
                  ),
                  child: Icon(Icons.check, size: 12, color: onGold),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The seven day circles, Monday first as the artwork draws them.
///
/// Names come from `MaterialLocalizations.narrowWeekdays`, so they follow the
/// device's own calendar wording in every language instead of a table of ours
/// that would have to be translated again for each new locale.
class WeekdayPicker extends StatelessWidget {
  const WeekdayPicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
  });

  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final narrow = MaterialLocalizations.of(context).narrowWeekdays;

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Row(
        children: [
          for (
            var weekday = DateTime.monday;
            weekday <= DateTime.sunday;
            weekday++
          )
            Expanded(
              // The tap target is the whole slot, gap included, not just the
              // circle drawn inside it: seven circles across a phone are about
              // 39px each, well under a comfortable target, and the space
              // between them would otherwise be dead.
              child: InkResponse(
                radius: 32,
                onTap: !enabled
                    ? null
                    : () {
                        final next = {...selected};
                        if (!next.remove(weekday)) {
                          next.add(weekday);
                        }
                        // Emptying the set would leave an enabled reminder
                        // that never arrives, which reads as a broken
                        // notification rather than a setting.
                        if (next.isNotEmpty) onChanged(next);
                      },
                // A fixed circle centred in its slot: stretched to the slot
                // it grew to ~52px on a phone and dwarfed its one letter.
                // The artwork draws them a little under the tiles' height
                // with the letter at body size.
                //
                // The slot is held to [kMinInteractiveDimension] so the whole
                // target clears 48 in both directions; the circle keeps the
                // size the artwork draws it at.
                child: SizedBox(
                  height: kMinInteractiveDimension,
                  child: Center(
                    child: SizedBox.square(
                      dimension: _dayCircle,
                      child: _DayCircle(
                        key: ValueKey('weekday_$weekday'),
                        // narrowWeekdays is indexed 0 = Sunday, so Sunday (7)
                        // wraps back to 0 rather than running off the end.
                        label: narrow[weekday % 7],
                        on: selected.contains(weekday),
                        dark: dark,
                        scheme: scheme,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Diameter of a day in [WeekdayPicker].
const double _dayCircle = 40;

/// One day, drawn. The tap lives on the slot around it; see [WeekdayPicker].
class _DayCircle extends StatelessWidget {
  const _DayCircle({
    super.key,
    required this.label,
    required this.on,
    required this.dark,
    required this.scheme,
  });

  final String label;
  final bool on;
  final bool dark;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final onGold = dark ? AppColors.darkBackground : Colors.white;

    return Semantics(
      button: true,
      selected: on,
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          fit: StackFit.passthrough,
          clipBehavior: Clip.none,
          children: [
            _circleFace(context),
            if (on)
              // Inside the square the circle is inscribed in, so the badge
              // sits on the circle's lower-right arc without reaching into the
              // next day's space — which is what made the row read as one
              // gold band instead of seven days.
              PositionedDirectional(
                end: 0,
                bottom: 0,
                child: IgnorePointer(
                  // The artwork's badge is a white disc with a gold ring and
                  // a gold tick; dark mode keeps its filled gold one.
                  child: Container(
                    width: 15,
                    height: 15,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: dark ? AppColors.darkGold : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: dark ? scheme.surface : DashboardTokens.dayEdge,
                        width: dark ? 1.5 : 1.2,
                      ),
                    ),
                    child: Icon(
                      Icons.check,
                      size: 10,
                      color: dark ? onGold : DashboardTokens.slotGlyph,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _circleFace(BuildContext context) {
    final theme = Theme.of(context);
    final onGold = dark ? AppColors.darkBackground : Colors.white;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: on
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: dark
                    ? [AppColors.darkGold, AppColors.gold]
                    : const [
                        DashboardTokens.dayFaceTop,
                        DashboardTokens.dayFaceBottom,
                      ],
              )
            : null,
        color: on ? null : scheme.surface,
        border: Border.all(
          color: on
              ? (dark ? AppColors.goldDark : DashboardTokens.dayEdge)
              : scheme.outlineVariant,
          width: on ? 1.2 : 1,
        ),
      ),
      // The pale line the artwork runs just inside a chosen day's edge. A
      // DecoratedBox does not inset its child by its border, so the edge's
      // own width is stepped over here.
      child: Container(
        margin: const EdgeInsets.all(1.2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: on && !dark
              ? Border.all(color: DashboardTokens.dayRim, width: 1)
              : null,
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                label,
                maxLines: 1,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: on ? onGold : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "ทุกวัน", or the chosen days in the device's own narrow weekday names.
String describeWeekdays(BuildContext context, Set<int> days) {
  if (days.length == 7) return AppLocalizations.of(context).goalEveryDay;
  final narrow = MaterialLocalizations.of(context).narrowWeekdays;
  return [
    for (var weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++)
      if (days.contains(weekday)) narrow[weekday % 7],
  ].join(' ');
}
