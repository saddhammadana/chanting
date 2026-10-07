import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/prefs_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/language_dropdown.dart';
import '../../../shared/widgets/spotlight_tour.dart';

/// Welcome sheet content version. Increment when a new feature should be
/// announced once to existing users.
const kWelcomeSheetVersion = 6;

/// Features added in the latest version; existing users who update see only
/// these. For a new release, replace the items here. Strings of retired rows
/// stay in .arb as a pool a later announcement can reuse.
///
/// **This used to be a const list; do not change it back.** Text lives in .arb,
/// so `l10n` must be passed at build time instead of using compile-time values.
List<Widget> _whatsNew(AppLocalizations l10n) => [
  _FeatureRow(
    icon: Icons.music_note_outlined,
    // Same name as the session card; share the localization key.
    title: l10n.meditationAmbient,
    detail: l10n.welcomeAmbientDetail,
  ),
  _FeatureRow(
    icon: Icons.flag_outlined,
    title: l10n.homeTodayGoal,
    detail: l10n.welcomeDailyGoalDetail,
  ),
  _FeatureRow(
    icon: Icons.auto_awesome_outlined,
    title: l10n.homeRecommendedTitle,
    detail: l10n.tourRecommendedBody,
  ),
];

/// The language picker on the tour's opening card. A new user chooses the UI
/// language here, and the tour's own cards follow it at once.
class TourLanguagePicker extends StatelessWidget {
  const TourLanguagePicker({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              Icons.language_outlined,
              size: 20,
              color: theme.colorScheme.secondary,
            ),
            const SizedBox(width: 8),
            Text(
              l10n.settingsLanguage,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const LanguageDropdown(),
      ],
    );
  }
}

/// Greets the user once per [kWelcomeSheetVersion], and reports whether this
/// was a fresh install rather than an update.
///
/// A fresh install gets a tour of the home screen built from [tourSteps]: the
/// features it used to list in a sheet are shown where they are instead. An
/// existing user who just updated gets the "what's new" sheet and no tour.
/// Either is marked seen as soon as it appears, so it does not repeat after
/// being dismissed.
///
/// The caller uses the result to decide whether to offer the goal page: an
/// existing user has their own habits already and should not be sent to a
/// setup screen.
Future<bool> showWelcomeIfNeeded(
  BuildContext context,
  WidgetRef ref, {
  required List<TourStep> Function(BuildContext context) tourSteps,
}) async {
  final prefs = ref.read(prefsServiceProvider);
  final seen = prefs.getWelcomeSeenVersion();
  if (seen >= kWelcomeSheetVersion) return false;
  unawaited(prefs.setWelcomeSeenVersion(kWelcomeSheetVersion));
  if (seen == 0) {
    await showSpotlightTour(context, steps: tourSteps);
    return true;
  }
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => const _WhatsNewSheet(),
  );
  return false;
}

/// What an existing user sees after an update: only the new items, so they
/// do not have to reread old highlights to find the changes. No language
/// picker, because they chose one already.
class _WhatsNewSheet extends StatelessWidget {
  const _WhatsNewSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  width: 56,
                  height: 56,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                l10n.welcomeWhatsNewTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                l10n.welcomeWhatsNewSubtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ..._whatsNew(l10n),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.welcomeWhatsNewButton),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer.withValues(
                alpha: 0.5,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 22, color: theme.colorScheme.secondary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
