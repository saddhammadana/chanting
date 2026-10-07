import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/content_width.dart';
import '../../shared/widgets/ornament_divider.dart';
import '../../shared/widgets/spotlight_tour.dart';
import 'widgets/settings_scaffold.dart';
import 'widgets/settings_tile.dart';

/// Company contact channel.
const _contactEmail = 'saddhammadana@gmail.com';

/// The About page: version, credits, licenses, and the contact channel.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    // Show the English translation note only in English UI. Only the English
    // edition uses informal English meanings; Thai uses prayer-book translations.
    final isEnglishEdition =
        Localizations.localeOf(context).languageCode == 'en';
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        leadingWidth: 64,
        title: Text(l10n.aboutApp),
      ),
      body: ContentWidth(
        maxWidth: ContentWidth.gridWidth,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/icon/app_icon.png',
                      width: 88,
                      height: 88,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.appName,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  // Read app version from package metadata instead of hardcoding.
                  FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (context, snapshot) => Text(
                      snapshot.hasData
                          ? l10n.aboutVersion(snapshot.data!.version)
                          : '',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 64),
                    child: OrnamentDivider(),
                  ),
                ],
              ),
            ),
            RaisedCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.aboutSectionAbout,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.secondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.aboutDescription,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                    ),
                  ],
                ),
              ),
            ),
            RaisedCard(
              child: Column(
                children: [
                  if (isEnglishEdition) ...[
                    ListTile(
                      leading: const Icon(Icons.translate_outlined),
                      title: Text(l10n.aboutTranslationTitle),
                      subtitle: Text(l10n.aboutTranslationNote),
                    ),
                    const Divider(height: 1),
                  ],
                  // The script guide is reference material used *while
                  // reading*, so it has its own page reachable from the reading
                  // menu too; About only points at it.
                  ListTile(
                    leading: const Icon(Icons.abc),
                    title: Text(l10n.aboutSectionScript),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/script'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.text_fields),
                    title: Text(l10n.aboutFontsTitle),
                    subtitle: Text(l10n.aboutFontsSubtitle),
                  ),
                  const Divider(height: 1),
                  // CC0 requires no attribution. Credited anyway, because this
                  // project records where everything came from — the fonts
                  // above and every prayer's meta.sources do the same.
                  ListTile(
                    leading: const Icon(Icons.notifications_active_outlined),
                    title: Text(l10n.aboutSoundTitle),
                    subtitle: Text(l10n.aboutSoundSubtitle),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.forest_outlined),
                    title: Text(l10n.aboutAmbientTitle),
                    subtitle: Text(l10n.aboutAmbientSubtitle),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    key: const ValueKey('about_replay_tour'),
                    leading: const Icon(Icons.tour_outlined),
                    title: Text(l10n.aboutReplayTour),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      homeTourReplayRequest.value = true;
                      context.go('/');
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.mail_outline),
                    title: Text(l10n.contactDeveloper),
                    subtitle: const Text(_contactEmail),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showContactDialog(context),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: Text(l10n.aboutLicenses),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final info = await PackageInfo.fromPlatform();
                      if (context.mounted) {
                        showLicensePage(
                          context: context,
                          applicationName: l10n.appName,
                          applicationVersion: info.version,
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Copies text and reports success through SnackBar.
Future<void> _copyWithFeedback(
  BuildContext context,
  String text,
  String message,
) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(appToast(message));
  }
}

void _showContactDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.contactDeveloper),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.contactDialogBody),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.mail_outline),
            title: const Text(_contactEmail),
            trailing: IconButton(
              icon: const Icon(Icons.copy_outlined),
              tooltip: l10n.copyEmail,
              onPressed: () =>
                  _copyWithFeedback(context, _contactEmail, l10n.copiedEmail),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(MaterialLocalizations.of(dialogContext).closeButtonLabel),
        ),
      ],
    ),
  );
}
