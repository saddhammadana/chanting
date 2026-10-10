import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_toast.dart';
import '../content_update/content_update_controller.dart';
import 'widgets/settings_scaffold.dart';
import 'widgets/settings_tile.dart';

/// Where a corrected prayer book comes from after install.
///
/// The app asks dhammapanya.org whether a newer release exists and keeps the
/// files it fetches beside the bundled ones. This page is the whole of the
/// user's side of that: whether it asks by itself, which book is being read,
/// a button to ask now, and the way back to the bundled book. It also says
/// what the request is, because this is the only time the app goes online.
/// See docs/architecture/content-updates.md.
class ContentUpdateScreen extends ConsumerWidget {
  const ContentUpdateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(contentUpdateControllerProvider);
    final controller = ref.read(contentUpdateControllerProvider.notifier);
    final checking = state.status == ContentUpdateStatus.checking;

    ref.listen(contentUpdateControllerProvider.select((s) => s.status), (
      _,
      status,
    ) {
      final toast = switch (status) {
        ContentUpdateStatus.updated => appToast(
          l10n.contentUpdated(_versionOf(ref)),
        ),
        ContentUpdateStatus.upToDate => appToast(
          l10n.contentUpToDate,
          kind: ToastKind.info,
        ),
        ContentUpdateStatus.failed => appToast(
          l10n.contentCheckFailed,
          kind: ToastKind.error,
        ),
        _ => null,
      };
      if (toast != null) ScaffoldMessenger.of(context).showSnackBar(toast);
    });

    final active = state.active;
    final pending = state.pending;

    return SettingsScaffold(
      title: l10n.settingsContentUpdate,
      leading: const AppBackButton(),
      children: [
        SettingsSectionHeader(l10n.settingsContentUpdate),
        SettingsCard(
          children: [
            SettingsTile(
              icon: Icons.sync,
              title: l10n.contentAutoUpdate,
              subtitle: l10n.contentAutoUpdateSubtitle,
              trailing: Switch(
                key: const ValueKey('content_auto_update'),
                value: state.autoUpdate,
                onChanged: controller.setAutoUpdate,
              ),
              onTap: () => controller.setAutoUpdate(!state.autoUpdate),
            ),
            SettingsTile(
              key: const ValueKey('content_version'),
              icon: Icons.menu_book_outlined,
              title: l10n.contentVersionTitle,
              subtitle: active == null
                  ? l10n.contentVersionBundled
                  : l10n.contentVersionFetched(
                      active.version,
                      _date(context, active.publishedAt),
                    ),
              trailing: const SizedBox.shrink(),
            ),
          ],
        ),
        if (pending != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: _Note(l10n.contentPendingNote(pending.version)),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: FilledButton.icon(
            key: const ValueKey('content_check_now'),
            onPressed: checking ? null : controller.checkNow,
            icon: checking
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_download_outlined),
            label: Text(l10n.contentCheckNow),
          ),
        ),
        if (active != null || pending != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                key: const ValueKey('content_use_bundled'),
                onPressed: checking ? null : controller.useBundled,
                child: Text(l10n.contentUseBundled),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: _Note(l10n.contentPrivacyNote),
        ),
      ],
    );
  }

  int _versionOf(WidgetRef ref) =>
      ref.read(contentUpdateControllerProvider).active?.version ?? 0;

  /// The publication day in the reader's locale; the raw value if it is not
  /// a date, so a malformed stamp is shown rather than thrown on.
  String _date(BuildContext context, String iso) {
    final parsed = DateTime.tryParse(iso);
    return parsed == null
        ? iso
        : MaterialLocalizations.of(context).formatMediumDate(parsed.toLocal());
  }
}

/// A line the reader is meant to read, in the subtitle colour.
///
/// Not `SettingHint`: that tone sits under WCAG AA on the cream ground, and
/// the note saying what the app sends over the network is not the place to
/// add to that debt.
class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
