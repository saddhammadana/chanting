import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/app_toast.dart';

/// AppBar "คืนค่า" pill; confirms before touching anything.
class ReadingResetButton extends StatelessWidget {
  const ReadingResetButton({super.key, required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppPillButton(
      key: const ValueKey('reading_reset'),
      label: l10n.settingsReset,
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.settingsResetConfirmTitle),
            content: Text(l10n.settingsResetConfirmBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(
                  MaterialLocalizations.of(dialogContext).cancelButtonLabel,
                ),
              ),
              FilledButton(
                key: const ValueKey('reading_reset_confirm'),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.settingsReset),
              ),
            ],
          ),
        );
        if (confirmed ?? false) {
          onReset();
          messenger.showSnackBar(appToast(l10n.settingsResetDone));
        }
      },
    );
  }
}
