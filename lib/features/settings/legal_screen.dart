import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'widgets/settings_scaffold.dart';
import 'widgets/settings_tile.dart';

/// Privacy policy and terms, readable offline.
///
/// The text mirrors `web/privacy.html`, which is the canonical version — an app
/// that ships with no network must be able to state its own privacy position
/// without one, so update the two together.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    Widget section(String title, String body) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.secondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(body, style: theme.textTheme.bodyMedium?.copyWith(height: 1.7)),
        ],
      ),
    );

    return SettingsScaffold(
      title: l10n.settingsLegal,
      leading: const AppBackButton(),
      children: [
        SettingsSectionHeader(l10n.legalPrivacyTitle),
        SettingsCard(
          children: [
            section(l10n.legalPrivacyTitle, l10n.legalPrivacyBody),
            section(l10n.legalDataTitle, l10n.legalDataBody),
            section(l10n.legalPermissionsTitle, l10n.legalPermissionsBody),
          ],
        ),
        SettingsSectionHeader(l10n.legalTermsTitle),
        SettingsCard(
          children: [
            section(l10n.legalTermsTitle, l10n.legalTermsBody),
            section(l10n.legalContentTitle, l10n.legalContentBody),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: SettingHint(l10n.legalUpdated),
        ),
      ],
    );
  }
}
