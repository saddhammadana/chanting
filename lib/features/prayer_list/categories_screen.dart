import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/pinned_ref.dart';
import '../../data/models/prayer_section.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_back_button.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/content_width.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading_indicator.dart';
import 'pinned_controller.dart';
import 'prayer_list_controller.dart';
import 'section_icon_overrides.dart';
import 'section_icons.dart';
import 'widgets/home_cards.dart';

/// List of all categories, including those not pinned to the home screen.
///
/// The home screen no longer shows every category tile because the full set plus
/// fixed feature tiles does not work well on mobile. This page is the entry point
/// for the rest and the only place where all categories can be pinned to home.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final sectionsAsync = ref.watch(prayerListControllerProvider);
    final pinned = ref.watch(pinnedControllerProvider);
    final iconOverrides = ref.watch(sectionIconOverridesProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        leadingWidth: appBackButtonLeadingWidth,
        title: Text(l10n.homeAllCategories),
      ),
      body: sectionsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          message: l10n.prayerLoadError,
          detail: '$e',
        ),
        data: (sections) => ContentWidth(
          maxWidth: ContentWidth.gridWidth,
          child: ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            children: [
              for (final entry in sections)
                Builder(
                  builder: (context) {
                    final pin = PinnedRef(PinnedType.section, entry.section.id);
                    final isPinned = pinned.contains(pin);
                    // The row opens the category; the commands that are not
                    // "open" live in the trailing menu.
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 5, 16, 5),
                      child: CategoryCard(
                        key: ValueKey('category_row_${entry.section.id}'),
                        entry: entry,
                        icon: resolvedSectionIcon(entry.section, iconOverrides),
                        subtitle: l10n.playlistPrayerCount(
                          entry.prayers.length,
                        ),
                        onTap: () =>
                            context.push('/category/${entry.section.id}'),
                        trailing: PopupMenuButton<String>(
                          key: ValueKey('category_menu_${entry.section.id}'),
                          icon: const Icon(Icons.more_vert),
                          tooltip: l10n.menuMore,
                          itemBuilder: (context) => [
                            // Device-local override only. The prayer editor
                            // changes the shipped value for everyone.
                            PopupMenuItem(
                              key: ValueKey('section_icon_${entry.section.id}'),
                              value: 'icon',
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.palette_outlined),
                                title: Text(l10n.sectionIconChange),
                              ),
                            ),
                            PopupMenuItem(
                              key: ValueKey('pin_section_${entry.section.id}'),
                              value: 'pin',
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  isPinned
                                      ? Icons.push_pin
                                      : Icons.push_pin_outlined,
                                ),
                                title: Text(
                                  isPinned
                                      ? l10n.unpinFromHome
                                      : l10n.pinToHome,
                                ),
                              ),
                            ),
                          ],
                          onSelected: (value) {
                            if (value == 'icon') {
                              _pickIcon(context, ref, entry.section);
                            } else {
                              togglePin(context, ref, pin);
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lets the user pick a device-local section icon override.
///
/// Reset deletes the override rather than writing the current shipped value, so
/// the section can receive a new shipped icon in a future release.
Future<void> _pickIcon(
  BuildContext context,
  WidgetRef ref,
  PrayerSection section,
) async {
  final l10n = AppLocalizations.of(context);
  final overrides = ref.read(sectionIconOverridesProvider);
  final picked = await showSectionIconPicker(
    context,
    title: l10n.sectionIconTitle(section.title),
    current: overrides[section.id] ?? section.icon,
    cancelLabel: MaterialLocalizations.of(context).cancelButtonLabel,
    resetLabel: overrides.containsKey(section.id)
        ? l10n.sectionIconReset
        : null,
  );
  if (picked == null) return;
  final notifier = ref.read(sectionIconOverridesProvider.notifier);
  if (picked == kResetSectionIcon) {
    notifier.reset(section.id);
  } else {
    notifier.set(section.id, picked);
  }
}

/// Toggles a pin and reports the result with the shared snackbar behavior.
void togglePin(BuildContext context, WidgetRef ref, PinnedRef pin) {
  final l10n = AppLocalizations.of(context);
  final nowPinned = ref.read(pinnedControllerProvider.notifier).toggle(pin);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      appToast(
        nowPinned ? l10n.pinnedAdded : l10n.pinnedRemoved,
        kind: nowPinned ? ToastKind.success : ToastKind.info,
        duration: const Duration(milliseconds: 1500),
      ),
    );
}

/// Pin button reused by other screens, with the same logic as this page.
class PinButton extends ConsumerWidget {
  const PinButton({super.key, required this.pin, this.dense = false});

  final PinnedRef pin;
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isPinned = ref.watch(pinnedControllerProvider).contains(pin);
    return IconButton(
      icon: Icon(
        isPinned ? Icons.push_pin : Icons.push_pin_outlined,
        size: dense ? 20 : null,
      ),
      tooltip: isPinned ? l10n.unpinFromHome : l10n.pinToHome,
      onPressed: () => togglePin(context, ref, pin),
    );
  }
}
