import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'edit_decorations.dart';

/// Name and description, in one card.
class EditFormCard extends StatelessWidget {
  const EditFormCard({
    super.key,
    required this.name,
    required this.description,
    required this.nameMissing,
  });

  final TextEditingController name;
  final TextEditingController description;
  final bool nameMissing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final label = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: editPanelDecoration(theme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              text: l10n.playlistNameLabel,
              children: [
                TextSpan(
                  text: ' *',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
            ),
            style: label,
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder(
            valueListenable: name,
            builder: (context, value, _) => TextField(
              key: const ValueKey('playlist_name_field'),
              controller: name,
              textInputAction: TextInputAction.next,
              decoration: editFieldDecoration(
                theme,
                hint: l10n.playlistNameHint,
                error: nameMissing ? l10n.playlistNameRequired : null,
                suffix: value.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).deleteButtonTooltip,
                        onPressed: name.clear,
                      ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(l10n.playlistDescriptionLabel, style: label),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('playlist_description_field'),
            controller: description,
            minLines: 2,
            maxLines: 3,
            decoration: editFieldDecoration(
              theme,
              hint: l10n.playlistDescriptionHint,
            ),
          ),
        ],
      ),
    );
  }
}
