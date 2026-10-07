import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../data/local/ambient_sound.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_asset_image.dart';
import '../../../shared/widgets/gold_ring.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/dashboard_tokens.dart';
import 'meditation_ambient_card.dart';
import 'meditation_ornaments.dart';
import 'meditation_setup.dart' show meditationDurationLabel;

/// Room above the minute pill once the app bar is gone.
const _kSessionTopPad = 30.0;

/// Session control sizes, measured off the reference artwork.
///
/// The reference centres the two small circles on the pause disc itself, not on
/// the disc-plus-label column, so the row aligns to the top and offsets them by
/// half the difference instead of using `CrossAxisAlignment.center`.
const _kSessionPrimaryDiameter = 100.0;

const _kSessionSideDiameter = 62.0;

const _kSessionSideTopInset =
    (_kSessionPrimaryDiameter - _kSessionSideDiameter) / 2;

/// Slides its child down by [offset] without changing what it lays out.
class _SettleOffset extends StatelessWidget {
  const _SettleOffset({required this.offset, required this.child});

  final double offset;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    // `begin` is only the first build's value — the sitting always starts
    // with the controls up, so it starts unmoved and animates on every change.
    tween: Tween(begin: 0.0, end: offset),
    duration: kMeditationFade,
    curve: Curves.easeInOut,
    builder: (context, dy, child) =>
        Transform.translate(offset: Offset(0, dy), child: child),
    child: child,
  );
}

/// Focused session state shown after the user starts the countdown.
class MeditationSessionView extends StatelessWidget {
  const MeditationSessionView({
    super.key,
    required this.time,
    required this.totalMinutes,
    required this.progress,
    required this.running,
    required this.endSignal,
    required this.onPrimary,
    required this.onReset,
    required this.onEnd,
    required this.onSignal,
    required this.ambient,
    required this.ambientVolume,
    required this.onAmbient,
    required this.onAmbientVolume,
    required this.onAmbientVolumeEnd,
    required this.controls,
    required this.tapHint,
    required this.onTapBackground,
  });

  final String time;
  final int totalMinutes;
  final double progress;
  final bool running;
  final String endSignal;
  final VoidCallback onPrimary;
  final VoidCallback onReset;
  final VoidCallback onEnd;
  final VoidCallback onSignal;

  /// The nature sound under the sitting and its volume, 0-1.
  final AmbientSound ambient;
  final double ambientVolume;
  final VoidCallback onAmbient;
  final ValueChanged<double> onAmbientVolume;
  final ValueChanged<double> onAmbientVolumeEnd;

  /// Whether the controls and the ornament are up.
  final bool controls;

  /// Whether to say, once, that a tap brings them back.
  final bool tapHint;

  final VoidCallback onTapBackground;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    // Everything but the ring fades on the spot rather than being taken out of
    // the layout: nothing may jump on a screen someone is sitting in front of,
    // and the buttons come back exactly where they were left.
    Widget recede(Widget child) => IgnorePointer(
      ignoring: !controls,
      child: AnimatedOpacity(
        opacity: controls ? 1 : 0,
        duration: kMeditationFade,
        curve: Curves.easeOut,
        child: child,
      ),
    );

    return GestureDetector(
      key: const ValueKey('meditation_session_surface'),
      behavior: HitTestBehavior.opaque,
      onTap: onTapBackground,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final ring = math.min(constraints.maxWidth * 0.58, 320.0);
          // Left alone, the ring keeps the place the buttons gave it and the
          // screen reads as one where something went missing. So it settles
          // toward the middle instead — eased over the same duration as the
          // fade, which is a drift rather than the jump a reflow would be.
          // The block is the ring plus the minute pill above it; clamped, so a
          // short screen with content to scroll simply does not move.
          final settledTop = ((constraints.maxHeight - (ring * 1.25 + 70)) / 2)
              .clamp(_kSessionTopPad, 360.0);
          return Stack(
            children: [
              // Moved, not re-laid-out. Settling the ring by growing the
              // list's top padding made the list taller than the screen — on a
              // 900px window the sitting went from not scrolling at all to
              // 190px of scroll, so the ring could be dragged away from under
              // the person sitting in front of it. A transform leaves the
              // scrollable extent exactly as it is with the controls up.
              _SettleOffset(
                offset: controls ? 0 : settledTop - _kSessionTopPad,
                child: ListView(
                  key: const ValueKey('meditation_session'),
                  // The bar this used to sit under is gone, so the room it took
                  // comes back to the sitting instead of to a gap above the ring.
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    _kSessionTopPad,
                    20,
                    28,
                  ),
                  children: [
                    recede(
                      Center(
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 44),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: dark
                                ? scheme.surface
                                : DashboardTokens.tileFaceBottom,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: dark
                                  ? scheme.secondary.withValues(alpha: 0.4)
                                  : DashboardTokens.outlineEdge,
                            ),
                            boxShadow: dark
                                ? null
                                : [
                                    DashboardTokens.warmShadow(
                                      0.07,
                                      blur: 5,
                                      dy: 2,
                                    ),
                                  ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const AppAssetImage(
                                'assets/images/shared/golden_lotus_emblem.png',
                                width: 32,
                                height: 25,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                meditationDurationLabel(l10n, totalMinutes),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    // The bar's title used to be what said a sitting was running,
                    // and it was the screen's only heading. Shedding the bar must
                    // not take that from a screen reader, so it moves onto the one
                    // thing that never leaves. The ring's numerals stay excluded.
                    Semantics(
                      header: true,
                      label: l10n.meditationInProgress,
                      child: _MeditationSessionHero(
                        size: ring,
                        progress: progress,
                        time: time,
                        totalMinutes: totalMinutes,
                        ornament: controls,
                      ),
                    ),
                    const SizedBox(height: 14),
                    // The end signal stays one tap away on the bell button
                    // below, so where a nature sound can play it takes the card.
                    recede(
                      ambientSoundSupported
                          ? SessionAmbientCard(
                              key: const ValueKey('meditation_ambient_card'),
                              sound: ambient,
                              volume: ambientVolume,
                              onPick: onAmbient,
                              onVolume: onAmbientVolume,
                              onVolumeEnd: onAmbientVolumeEnd,
                            )
                          : _SessionSignalCard(
                              value: endSignal,
                              onTap: onSignal,
                            ),
                    ),
                    const SizedBox(height: 24),
                    recede(
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SessionCircleAction(
                            key: const ValueKey('meditation_reset'),
                            icon: Icons.replay_rounded,
                            label: l10n.meditationReset,
                            onTap: onReset,
                          ),
                          _SessionPrimaryAction(
                            key: ValueKey(
                              running
                                  ? 'meditation_pause'
                                  : 'meditation_resume',
                            ),
                            running: running,
                            label: running
                                ? l10n.meditationPause
                                : l10n.meditationResume,
                            onTap: onPrimary,
                          ),
                          _SessionCircleAction(
                            key: const ValueKey('meditation_session_signal'),
                            icon: Icons.notifications_none_rounded,
                            label: l10n.meditationEndSignal,
                            onTap: onSignal,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    recede(
                      OutlinedButton(
                        key: const ValueKey('meditation_end_practice'),
                        onPressed: onEnd,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          foregroundColor: scheme.onSurface,
                          side: BorderSide(
                            color: dark
                                ? scheme.secondary
                                : DashboardTokens.goldEdge,
                            width: 1.2,
                          ),
                          shape: const StadiumBorder(),
                          textStyle: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: Text(l10n.meditationEndPractice),
                      ),
                    ),
                    const SizedBox(height: 22),
                    recede(
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 72),
                        child: _SessionLotusDivider(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    recede(
                      Text(
                        l10n.meditationSessionGuidance,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Said once, when the controls leave — the same sentence the
              // reading screen uses for the same gesture.
              Positioned(
                left: 0,
                right: 0,
                bottom: 24,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: tapHint ? 1 : 0,
                    duration: kMeditationFade,
                    child: Text(
                      l10n.immersiveHint,
                      key: const ValueKey('meditation_tap_hint'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MeditationSessionHero extends StatelessWidget {
  const _MeditationSessionHero({
    required this.size,
    required this.progress,
    required this.time,
    required this.totalMinutes,
    required this.ornament,
  });

  final double size;
  final double progress;
  final String time;
  final int totalMinutes;

  /// Whether the lotus clouds and sparkles around the ring are drawn.
  ///
  /// `LotusTonalFade` already treats ornament strength as something computed
  /// rather than fixed; this is the same idea one level up, with the state of
  /// the sitting as the input instead of the distance from the flower.
  final bool ornament;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final ornamentWidth = size * 0.70;

    Widget fade(Widget child) => AnimatedOpacity(
      opacity: ornament ? 1 : 0,
      duration: kMeditationFade,
      curve: Curves.easeOut,
      child: child,
    );

    return Center(
      child: SizedBox(
        width: size * 1.64,
        height: size * 1.25,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 0,
              bottom: 0,
              child: fade(
                LotusTonalFade(
                  child: AppAssetImage(
                    'assets/images/meditation/meditation_lotus_cloud.png',
                    width: ornamentWidth,
                    height: size * 0.48,
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomLeft,
                  ),
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: fade(
                Transform.flip(
                  flipX: true,
                  child: LotusTonalFade(
                    child: AppAssetImage(
                      'assets/images/meditation/meditation_lotus_cloud.png',
                      width: ornamentWidth,
                      height: size * 0.48,
                      fit: BoxFit.contain,
                      alignment: Alignment.bottomLeft,
                    ),
                  ),
                ),
              ),
            ),
            TimerSparkles(size: size, visible: ornament),
            Positioned(
              top: size * 0.07,
              child: GoldRing(
                size: size,
                progress: progress,
                child: ExcludeSemantics(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        time,
                        style: theme.textTheme.displayLarge?.copyWith(
                          fontFamily: theme.textTheme.bodyLarge?.fontFamily,
                          fontSize: size * 0.25,
                          height: 1,
                          letterSpacing: 0,
                          fontWeight: FontWeight.w400,
                          color: dark ? scheme.secondary : AppColors.goldDark,
                        ),
                      ),
                      SizedBox(height: size * 0.035),
                      Text(
                        l10n.meditationRemaining,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: size * 0.072,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: size * 0.025),
                      Container(
                        width: size * 0.34,
                        height: 1,
                        color: scheme.outlineVariant,
                      ),
                      SizedBox(height: size * 0.025),
                      Text(
                        meditationDurationLabel(l10n, totalMinutes),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: size * 0.056,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionSignalCard extends StatelessWidget {
  const _SessionSignalCard({required this.value, required this.onTap});

  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    return Semantics(
      button: true,
      label: '${l10n.meditationEndSignal}, $value',
      child: Container(
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
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
                    child: Icon(
                      Icons.notifications_none_rounded,
                      color: dark
                          ? scheme.secondary
                          : DashboardTokens.goldGlyph,
                      size: 27,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.meditationEndSignal,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          value,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SessionCircleAction extends StatelessWidget {
  const _SessionCircleAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: label,
      child: Padding(
        padding: const EdgeInsets.only(top: _kSessionSideTopInset),
        child: Material(
          color: Colors.transparent,
          shape: CircleBorder(side: BorderSide(color: scheme.secondary)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox.square(
              dimension: _kSessionSideDiameter,
              child: Icon(icon, color: scheme.secondary, size: 28),
            ),
          ),
        ),
      ),
    );
  }
}

class _SessionPrimaryAction extends StatelessWidget {
  const _SessionPrimaryAction({
    super.key,
    required this.running,
    required this.label,
    required this.onTap,
  });

  final bool running;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    return Semantics(
      button: true,
      label: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Three nested discs, outside in: gold band, cream ring, lit face.
          // Widths are the artwork's, scaled to this diameter. On a dark
          // ground the ring and the glyph turn dark and the gold dims, so the
          // disc does not glare in a dim room.
          Container(
            width: _kSessionPrimaryDiameter,
            height: _kSessionPrimaryDiameter,
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: dark
                    ? const [AppColors.darkGold, AppColors.goldDark]
                    : const [
                        DashboardTokens.discBandTop,
                        DashboardTokens.discBandBottom,
                      ],
              ),
              boxShadow: [DashboardTokens.warmShadow(0.22, blur: 9, dy: 3)],
            ),
            child: Container(
              padding: const EdgeInsets.all(2.4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dark
                    ? AppColors.darkBackground
                    : DashboardTokens.discRing,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: dark
                        ? const [
                            AppColors.darkGold,
                            AppColors.darkGold,
                            AppColors.gold,
                          ]
                        : const [
                            DashboardTokens.discFaceTop,
                            DashboardTokens.discFaceMid,
                            DashboardTokens.discFaceBottom,
                          ],
                    stops: const [0, 0.45, 1],
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onTap,
                    child: Icon(
                      running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: dark ? AppColors.darkBackground : Colors.white,
                      size: 54,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionLotusDivider extends StatelessWidget {
  const _SessionLotusDivider();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Divider(
            endIndent: 12,
            color: scheme.secondary.withValues(alpha: 0.65),
          ),
        ),
        const AppAssetImage(
          'assets/images/shared/golden_lotus_emblem.png',
          width: 34,
          height: 27,
          fit: BoxFit.contain,
        ),
        Expanded(
          child: Divider(
            indent: 12,
            color: scheme.secondary.withValues(alpha: 0.65),
          ),
        ),
      ],
    );
  }
}
