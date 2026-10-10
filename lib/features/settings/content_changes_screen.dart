import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/content_diff.dart';
import '../../l10n/app_localizations.dart';
import '../content_update/content_update_controller.dart';
import '../prayer_list/prayer_list_controller.dart';
import 'widgets/settings_scaffold.dart';
import 'widgets/settings_tile.dart';

/// What the prayer book fetched after install changed, line by line.
///
/// These texts are chanted from memory, so a corrected word is the thing a
/// reader most needs pointed at — and a release arrives with no changelog.
/// Each prayer that differs from the book read before is listed with the
/// lines that changed, as they were and as they are, and opens on a tap.
///
/// A prayer whose chant text is untouched is still listed when its record
/// changed, with a line saying what kind of change that was: leaving it out
/// would make "nothing here" mean two different things.
/// See docs/architecture/content-updates.md.
class ContentChangesScreen extends ConsumerWidget {
  const ContentChangesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final language = ref.watch(prayerRepositoryProvider).languageCode;
    final changes =
        ref.watch(contentChangesProvider(language)).value ?? const [];

    String kind(PrayerChangeKind kind) => switch (kind) {
      PrayerChangeKind.added => l10n.contentChangeAdded,
      PrayerChangeKind.changed => l10n.contentChangeEdited,
      PrayerChangeKind.removed => l10n.contentChangeRemoved,
    };

    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    Widget line(String label, String text, {bool struck = false}) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 44, child: Text(label, style: muted)),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.6,
                color: struck ? theme.colorScheme.onSurfaceVariant : null,
                decoration: struck ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ],
      ),
    );

    return SettingsScaffold(
      title: l10n.contentChangesTitle,
      leading: const AppBackButton(),
      children: [
        if (changes.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Text(l10n.contentChangesEmpty, style: muted),
          ),
        for (final change in changes)
          SettingsCard(
            children: [
              ListTile(
                key: ValueKey('content_change_${change.id}'),
                title: Text(
                  change.title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(kind(change.kind), style: muted),
                // A prayer taken out of the book has nowhere to open.
                trailing: change.kind == PrayerChangeKind.removed
                    ? null
                    : const Icon(Icons.chevron_right),
                onTap: change.kind == PrayerChangeKind.removed
                    ? null
                    : () => context.push('/prayer/${change.id}'),
              ),
              if (change.kind == PrayerChangeKind.changed)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                  child: change.lines.isEmpty
                      ? Text(l10n.contentChangeOther, style: muted)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final (index, entry)
                                in change.lines.indexed) ...[
                              if (index > 0) const Divider(height: 20),
                              if (entry.before != null)
                                line(
                                  l10n.contentChangeBefore,
                                  entry.before!,
                                  struck: true,
                                ),
                              if (entry.after != null)
                                line(l10n.contentChangeAfter, entry.after!),
                            ],
                          ],
                        ),
                ),
            ],
          ),
      ],
    );
  }
}
