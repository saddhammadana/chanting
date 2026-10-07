import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/notification_service.dart';
import '../../../l10n/app_localizations.dart';
import '../reminders_controller.dart';

/// The two reminder blocks that are about the platform rather than the goal.
///
/// They were part of the reminders page before it became the goal page, and
/// they are here so that page stays about when you chant.

/// Explanation box for exact-alarm permission and late reminders.
class ExactAlarmNotice extends ConsumerStatefulWidget {
  const ExactAlarmNotice({super.key});

  @override
  ConsumerState<ExactAlarmNotice> createState() => ExactAlarmNoticeState();
}

/// Re-checks the exact-alarm permission whenever the app is resumed.
class ExactAlarmNoticeState extends ConsumerState<ExactAlarmNotice>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning from system settings; re-check permission and hide if enabled.
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(exactAlarmAllowedProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    // While checking, or once allowed, show nothing.
    final allowed = ref.watch(exactAlarmAllowedProvider).asData?.value ?? true;
    if (allowed) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.alarm_outlined,
                  size: 20,
                  color: theme.colorScheme.onTertiaryContainer,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.reminderExactAlarmTitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onTertiaryContainer,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.reminderExactAlarmBody,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onTertiaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: () => ref
                    .read(notificationServiceProvider)
                    .openExactAlarmSettings(),
                child: Text(l10n.reminderExactAlarmAction),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
