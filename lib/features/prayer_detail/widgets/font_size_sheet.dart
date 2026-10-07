import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';
import '../../settings/settings_controller.dart';

/// Font-size sheet for the reader, opened from the overflow menu.
///
/// It lives outside the reader because it does not read page-local state. All
/// values come from `settingsControllerProvider` and are written back there, so
/// the content behind the sheet updates immediately through the same provider.
///
/// **Text size stays reachable from the reader even though the settings page
/// owns it too.** It is the one reading setting somebody discovers they need
/// mid-prayer — too small in this light, at this distance, right now — and
/// walking out to settings costs the place they were reading, the auto-scroll
/// they had running and the immersive mode they were in. It is not a second
/// copy of the value, just a second door to it, and the sheet's last row is a
/// way through to the rest of the reading settings for anyone who came here
/// wanting line spacing or the page colour instead.
void showFontSizeSheet(BuildContext context) {
  // Captured before the sheet opens: the route push has to outlive the sheet's
  // own context, which is gone by the time the new page is pushed.
  final router = GoRouter.of(context);
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => Consumer(
      builder: (context, sheetRef, _) {
        final theme = Theme.of(context);
        final l10n = AppLocalizations.of(context);
        final scale = sheetRef.watch(
          settingsControllerProvider.select((s) => s.fontScale),
        );
        final controller = sheetRef.read(settingsControllerProvider.notifier);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    l10n.settingsFontSize,
                    style: theme.textTheme.titleMedium,
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      l10n.fontScalePercent((scale * 100).round()),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.text_decrease),
                    tooltip: l10n.fontDecrease,
                    onPressed: () => controller.stepFontSize(-1),
                  ),
                  Expanded(
                    child: Slider(
                      value: scale,
                      min: kFontScaleMin,
                      max: kFontScaleMax,
                      divisions:
                          ((kFontScaleMax - kFontScaleMin) / kFontScaleStep)
                              .round(),
                      label: l10n.fontScalePercent((scale * 100).round()),
                      onChanged: controller.setFontScale,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.text_increase),
                    tooltip: l10n.fontIncrease,
                    onPressed: () => controller.stepFontSize(1),
                  ),
                ],
              ),
              const Divider(height: 8),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  key: const ValueKey('reader_more_reading_settings'),
                  icon: const Icon(Icons.tune, size: 20),
                  label: Text(l10n.readingMoreSettings),
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    router.push('/settings/reading');
                  },
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
