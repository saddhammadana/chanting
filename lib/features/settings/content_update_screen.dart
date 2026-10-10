import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_toast.dart';
import '../content_update/content_update_controller.dart';
import '../prayer_list/prayer_list_controller.dart';
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
    final theme = Theme.of(context);
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
    final changed =
        ref
            .watch(
              contentChangesProvider(
                ref.watch(prayerRepositoryProvider).languageCode,
              ),
            )
            .value
            ?.length ??
        0;

    // The page's one sentence about where things stand. A check in progress
    // or just failed is said first; then a release waiting for a launch.
    // "Up to date" is only claimed once a check in this visit has said so.
    final (mark, title, subtitle) = switch (state.status) {
      ContentUpdateStatus.checking => (
        Icons.sync,
        l10n.contentStatusChecking,
        l10n.contentStatusCheckingSubtitle,
      ),
      ContentUpdateStatus.failed => (
        Icons.priority_high,
        l10n.contentStatusFailed,
        l10n.contentStatusFailedSubtitle,
      ),
      _ when pending != null => (
        Icons.arrow_downward,
        l10n.contentStatusPending(pending.version),
        l10n.contentStatusPendingSubtitle,
      ),
      ContentUpdateStatus.upToDate || ContentUpdateStatus.updated => (
        Icons.check,
        l10n.contentStatusLatest,
        l10n.contentStatusOffline,
      ),
      _ => (Icons.check, l10n.contentStatusReady, l10n.contentStatusOffline),
    };

    return SettingsScaffold(
      title: l10n.settingsContentUpdate,
      leading: const AppBackButton(),
      children: [
        _StatusHero(
          key: const ValueKey('content_status'),
          mark: mark,
          title: title,
          subtitle: subtitle,
        ),
        SettingsCard(
          children: [
            SettingsTile(
              key: const ValueKey('content_version'),
              icon: Icons.menu_book,
              title: l10n.contentVersionTitle,
              subtitle: active == null
                  ? l10n.contentVersionBundled
                  : l10n.contentVersionFetched(
                      active.version,
                      _date(context, active.publishedAt),
                    ),
              trailing: const SizedBox.shrink(),
            ),
            // What that release changed from the book read before it. Only
            // for a fetched release: the bundled book has nothing before it.
            if (active != null)
              SettingsTile(
                key: const ValueKey('content_changes'),
                icon: Icons.description,
                title: l10n.contentChangesTitle,
                subtitle: l10n.contentChangesCount(changed),
                onTap: () => context.push('/settings/content/changes'),
              ),
          ],
        ),
        const SizedBox(height: 4),
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
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: FilledButton.icon(
            key: const ValueKey('content_check_now'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              textStyle: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            onPressed: checking ? null : controller.checkNow,
            icon: checking
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_download_outlined, size: 26),
            label: Text(l10n.contentCheckNow),
          ),
        ),
        if (active != null || pending != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Center(
              child: TextButton(
                key: const ValueKey('content_use_bundled'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurface,
                ),
                onPressed: checking ? null : controller.useBundled,
                child: Text(l10n.contentUseBundled),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _PrivacyCard(
            privacy: l10n.contentPrivacyNote,
            offline: l10n.contentOfflineNote,
          ),
        ),
      ],
    );
  }

  int _versionOf(WidgetRef ref) =>
      ref.read(contentUpdateControllerProvider).active?.version ?? 0;

  /// The publication day in the reader's locale, with the year only when
  /// it is not this one; the raw value if it is not a date, so a malformed
  /// stamp is shown rather than thrown on.
  String _date(BuildContext context, String iso) {
    final parsed = DateTime.tryParse(iso)?.toLocal();
    if (parsed == null) return iso;
    final format = MaterialLocalizations.of(context);
    final day = format.formatShortMonthDay(parsed);
    return parsed.year == DateTime.now().year
        ? day
        : '$day ${format.formatYear(parsed)}';
  }
}

/// The head of the page: the prayer book in a soft gold disc, a small mark
/// on it for how things stand, and that said in a line and a half.
class _StatusHero extends StatelessWidget {
  const _StatusHero({
    super.key,
    required this.mark,
    required this.title,
    required this.subtitle,
  });

  final IconData mark;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final soft = scheme.secondaryContainer.withValues(
      alpha: theme.brightness == Brightness.light ? 0.7 : 1,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 18),
      child: Column(
        children: [
          ExcludeSemantics(
            child: CustomPaint(
              painter: _RaysPainter(soft),
              child: SizedBox(
                width: 180,
                height: 116,
                child: Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 116,
                        height: 116,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: soft,
                        ),
                        child: Icon(
                          Icons.menu_book,
                          size: 60,
                          color: scheme.secondary,
                        ),
                      ),
                      PositionedDirectional(
                        end: 2,
                        bottom: 12,
                        child: Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: scheme.secondary,
                            border: Border.all(color: soft, width: 3),
                          ),
                          child: Icon(mark, size: 20, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Announced when it changes: the check's answer lands here.
          Semantics(
            liveRegion: true,
            child: Column(
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
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

/// Three short rays either side of the disc, as the artwork draws them.
class _RaysPainter extends CustomPainter {
  const _RaysPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final centre = size.center(Offset.zero);
    for (final side in const [-1.0, 1.0]) {
      for (final slope in const [-0.5, 0.0, 0.5]) {
        final direction = Offset(side, slope) / Offset(side, slope).distance;
        canvas.drawLine(
          centre + direction * 70,
          centre + direction * 84,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RaysPainter old) => old.color != color;
}

/// What the app sends over the network and what works without it, set apart
/// from the settings cards: flat and quieter, because it is read, not used.
class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard({required this.privacy, required this.offline});

  final String privacy;
  final String offline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurface);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.12),
            ),
            child: ExcludeSemantics(
              child: Icon(
                Icons.security,
                size: 23,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(privacy, style: style),
                const Divider(height: 22),
                Text(offline, style: style),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
