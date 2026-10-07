import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_asset_image.dart';
import '../../../shared/widgets/golden_pill_button.dart';
import '../share_page_parts.dart';

/// The lotus tick after a new set is saved. Pops true for "ดูชุดสวด", false
/// for "กลับหน้าหลัก".
class SavedDialog extends StatelessWidget {
  const SavedDialog({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Supplied artwork: the glowing lotus tick, cropped to its glow
            // and sized to ~4x its drawn width.
            const ExcludeSemantics(
              child: AppAssetImage(
                'assets/images/playlists/golden_lotus_checkmark_glow.png',
                width: 120,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.playlistSavedTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.playlistSavedMessage(name),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: shareGold(theme),
              ),
            ),
            const SizedBox(height: 20),
            GoldenPillButton(
              label: l10n.playlistViewSet,
              height: 48,
              expand: true,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.playlistBackHome),
            ),
          ],
        ),
      ),
    );
  }
}
