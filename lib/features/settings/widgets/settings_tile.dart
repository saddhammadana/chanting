import 'package:flutter/material.dart';

import '../../../shared/widgets/app_asset_image.dart';
import '../../../theme/dashboard_tokens.dart';

/// Building blocks for the settings pages, drawn from the reference artwork.
///
/// The artwork groups settings as a heading followed by a bordered card of
/// rows, each row a round icon badge, a title, a subtitle and one control on
/// the right. Keeping the three pieces here stops the hub and its five
/// sub-pages from each inventing their own spacing.

/// Heading above a settings card, such as "การอ่าน".
class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 6),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}

/// The theme's [Card] with the home dashboard's warm shadow under it.
///
/// Every card on the settings pages goes through this, so none of them sits
/// flat beside one that is raised. The reading page's text sample is the
/// exception and uses a plain [Card]: it stands for the reader's paper, not
/// for a group of settings.
///
/// The shadow is drawn outside the Card because Material elevation only casts
/// grey, and the artwork's shadows are warm. The Card's margin moves outside
/// the shadow, or the shadow would be cast around the margin's empty box.
class RaisedCard extends StatelessWidget {
  const RaisedCard({
    super.key,
    required this.child,
    this.clipBehavior = Clip.none,
  });

  final Widget child;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shape = theme.cardTheme.shape;
    final radius = shape is RoundedRectangleBorder
        ? shape.borderRadius
        : BorderRadius.circular(12);
    return Padding(
      padding: theme.cardTheme.margin ?? const EdgeInsets.all(4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: DashboardTokens.cardShadows(theme, glow: 0.2),
        ),
        child: Card(
          margin: EdgeInsets.zero,
          clipBehavior: clipBehavior,
          child: child,
        ),
      ),
    );
  }
}

/// Card holding a group of settings rows, with hairlines between them.
///
/// The optional lotus watermark is the artwork's own: it sits in the first
/// card only, so it is a parameter rather than something every card carries.
class SettingsCard extends StatelessWidget {
  const SettingsCard({
    super.key,
    required this.children,
    this.watermark = false,
  });

  final List<Widget> children;
  final bool watermark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = <Widget>[];
    for (final child in children) {
      // Inset to the text column, so the hairline reads as separating rows
      // rather than cutting the icon badges off.
      if (rows.isNotEmpty) rows.add(const Divider(height: 1, indent: 72));
      rows.add(child);
    }
    final column = Column(mainAxisSize: MainAxisSize.min, children: rows);

    return RaisedCard(
      clipBehavior: Clip.antiAlias,
      child: watermark
          ? Stack(
              children: [
                // Cropped at the card's foot, the way the artwork sets it —
                // clipped at the top instead it reads as a hard rule across
                // the row rather than as a watermark.
                PositionedDirectional(
                  end: -10,
                  bottom: -20,
                  child: IgnorePointer(
                    child: ExcludeSemantics(
                      child: Opacity(
                        // Lighter than the outline watermark's 0.32 would
                        // suggest in the dark, because this artwork is pale
                        // cream: tinted gold-on-dark it disappeared, untinted
                        // it reads as a bright blob behind the title.
                        opacity: theme.brightness == Brightness.light
                            ? 0.22
                            : 0.14,
                        // No `srcIn` tint: this emblem carries its own cream
                        // and gold shading, and flattening it to one colour
                        // turns the petals into a single blob. The outline
                        // artwork it replaced was a line drawing, which is
                        // what made a tint the right call there.
                        child: const AppAssetImage(
                          'assets/images/settings/elegant_golden_lotus_emblem.png',
                          width: 200,
                        ),
                      ),
                    ),
                  ),
                ),
                column,
              ],
            )
          : column,
    );
  }
}

/// One settings row: round icon badge, title, subtitle, trailing control.
///
/// [trailing] defaults to the chevron the artwork puts on every row that opens
/// another page; pass a `Switch` for a row that toggles in place.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dim = enabled ? 1.0 : 0.4;

    // One node for the row, so a trailing switch is announced with the row's
    // title instead of as an unnamed switch.
    return MergeSemantics(
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
          child: Row(
            children: [
              Opacity(
                opacity: dim,
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.secondaryContainer.withValues(alpha: 0.45),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Icon(icon, size: 23, color: scheme.secondary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Opacity(
                  opacity: dim,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              trailing ??
                  Icon(
                    Icons.chevron_right,
                    color: scheme.onSurfaceVariant.withValues(alpha: dim),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One settings row on a sub-page: icon, label, optional value badge, and the
/// control below.
///
/// Kept from the single-page settings screen the hub replaced — the sub-pages
/// still lay out sliders and segmented buttons exactly this way.
class SettingGroup extends StatelessWidget {
  const SettingGroup({
    super.key,
    required this.icon,
    required this.label,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: theme.colorScheme.secondary),
              const SizedBox(width: 14),
              Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Current settings value badge, such as "100%" or a color label.
class ValueBadge extends StatelessWidget {
  const ValueBadge(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Hint text under a control, in the muted tone the settings pages use.
class SettingHint extends StatelessWidget {
  const SettingHint(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
      ),
    );
  }
}
