import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/pinned_ref.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_back_button.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/content_width.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../playlists/playlists_controller.dart';
import 'categories_screen.dart' show PinButton;
import 'prayer_list_controller.dart';
import 'section_extras_controller.dart';
import 'widgets/grouped_prayer_list.dart';
import 'widgets/prayer_card.dart';

/// Prayer list for one category, or all categories when [sectionId] is null.
class CategoryScreen extends ConsumerWidget {
  const CategoryScreen({super.key, this.sectionId});

  /// `PrayerSection.id`, not a category title.
  ///
  /// Titles vary by content language, so title-based URLs would not work across
  /// languages. Null means all prayers.
  final String? sectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final prayersAsync = ref.watch(prayerListControllerProvider);
    final title = sectionId == null
        ? l10n.homeAllPrayers
        : prayersAsync.value
                  ?.where((e) => e.section.id == sectionId)
                  .firstOrNull
                  ?.section
                  .title ??
              '';

    final entry = sectionId == null
        ? null
        : prayersAsync.value
              ?.where((e) => e.section.id == sectionId)
              .firstOrNull;

    final canGoBack = ModalRoute.of(context)?.canPop ?? false;

    return Scaffold(
      // Keep pin as an icon and move other commands into the menu. Three bare
      // icons (`add`, `playlist_add`, pin) were ambiguous, the first two looked
      // similar, and long category titles were squeezed on mobile.
      //
      // Pin remains visible because its state matters at a glance. The other two
      // commands are occasional actions, matching category rows on the all
      // categories page.
      appBar: AppBar(
        // Only where there is a page to go back to. This screen is also the
        // Start tab, a bottom-bar destination with nothing under it, and a
        // back button there is a control that does nothing.
        leading: canGoBack ? const AppBackButton() : null,
        leadingWidth: canGoBack ? appBackButtonLeadingWidth : null,
        automaticallyImplyLeading: false,
        title: Text(title),
        actions: [
          if (sectionId != null) ...[
            PinButton(
              key: const ValueKey('pin_section_appbar'),
              pin: PinnedRef(PinnedType.section, sectionId!),
            ),
            PopupMenuButton<String>(
              key: const ValueKey('category_menu'),
              icon: const Icon(Icons.more_vert),
              tooltip: l10n.menuMore,
              enabled: entry != null,
              itemBuilder: (context) => [
                PopupMenuItem(
                  key: const ValueKey('section_add_prayer'),
                  value: 'add',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.add),
                    title: Text(l10n.sectionAddPrayer),
                  ),
                ),
                // Copy the shipped category into a user playlist. Shipped
                // categories are not user-editable so future app updates can fix
                // content for existing users; custom ordering belongs in a
                // device-local playlist.
                PopupMenuItem(
                  key: const ValueKey('category_to_playlist'),
                  value: 'playlist',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.playlist_add),
                    title: Text(l10n.categoryCreatePlaylist),
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'add') {
                  _addPrayerToSection(context, ref, sectionId!);
                } else {
                  _createPlaylist(context, ref, entry!);
                }
              },
            ),
          ],
        ],
      ),
      body: prayersAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          message: l10n.prayerLoadError,
          detail: '$e',
        ),
        data: (sections) {
          final extras = sectionId == null
              ? const <String>[]
              : ref.watch(sectionExtrasProvider)[sectionId] ?? const <String>[];
          if (sectionId == null) {
            return ContentWidth(
              maxWidth: ContentWidth.gridWidth,
              child: GroupedPrayerList(
                sections: sections,
                onTapPrayer: (p) => context.push('/prayer/${p.id}'),
              ),
            );
          }
          // Old links may point at categories that no longer exist.
          final current = sections
              .where((e) => e.section.id == sectionId)
              .firstOrNull;
          if (current == null) {
            return EmptyState(icon: Icons.search_off, message: l10n.notFound);
          }
          // Categories can remain in the file after every prayer was moved out so
          // they can be filled again. Show an explicit empty state instead of a
          // blank page.
          if (current.prayers.isEmpty) {
            return EmptyState(
              icon: Icons.menu_book_outlined,
              message: l10n.categoryEmptyMessage,
              detail: l10n.categoryEmptyDetail,
            );
          }
          return ContentWidth(
            maxWidth: ContentWidth.gridWidth,
            child: ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              children: [
                // Show the prayer count at the top; category tiles already show
                // this context, and it can scroll away because it is supporting
                // metadata rather than required chrome.
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                  child: Text(
                    l10n.playlistPrayerCount(current.prayers.length),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                for (final (i, prayer) in current.prayers.indexed)
                  PrayerCard(
                    key: ValueKey('card_${prayer.id}'),
                    prayer: prayer,
                    // Chant order in this category. User-added extras count at
                    // the end, matching the order they will be chanted.
                    order: i + 1,
                    // Mark user-added extras because only those are removable;
                    // shipped category members are not user-editable.
                    badge: extras.contains(prayer.id)
                        ? l10n.sectionExtraBadge
                        : null,
                    trailing: extras.contains(prayer.id)
                        ? IconButton(
                            key: ValueKey('remove_extra_${prayer.id}'),
                            icon: const Icon(Icons.close),
                            tooltip: l10n.sectionExtraRemove,
                            onPressed: () {
                              ref
                                  .read(sectionExtrasProvider.notifier)
                                  .remove(sectionId!, prayer.id);
                              // This button sits where other rows have a chevron,
                              // so accidental taps are plausible. The removed
                              // value is user-owned, and add always appends, so
                              // undo restores the exact visible position.
                              _snack(
                                context,
                                l10n.sectionExtraRemoved,
                                undo: () => ref
                                    .read(sectionExtrasProvider.notifier)
                                    .add(sectionId!, prayer.id),
                              );
                            },
                          )
                        : null,
                    // Pass the source category to the reader. One prayer can
                    // appear in multiple categories, and continuous reading needs
                    // to know which order to follow.
                    onTap: () =>
                        context.push('/prayer/${prayer.id}?section=$sectionId'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Copies a shipped category into a user playlist.
///
/// The source category is untouched. Categories are shipped content and must stay
/// updatable for existing users; playlists live in prefs and are fully
/// user-editable.
void _createPlaylist(
  BuildContext context,
  WidgetRef ref,
  SectionPrayers entry,
) {
  final l10n = AppLocalizations.of(context);
  // Reuse the import path used for shared playlists so duplicate names get the
  // same "(2)" handling.
  final created = ref.read(playlistsControllerProvider.notifier).import(
    entry.section.title,
    [for (final p in entry.prayers) p.id],
  );
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      appToast(
        l10n.categoryPlaylistCreated(created.name),
        duration: const Duration(seconds: 4),
        actionLabel: l10n.openAction,
        onAction: () => context.push('/playlists/${created.id}'),
      ),
    );
}

/// Short snackbar; with [undo], it shows an undo action and lasts longer.
void _snack(BuildContext context, String message, {VoidCallback? undo}) {
  final l10n = AppLocalizations.of(context);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      appToast(
        message,
        kind: ToastKind.info,
        duration: Duration(milliseconds: undo == null ? 1500 : 4000),
        actionLabel: undo == null ? null : l10n.undoAction,
        onAction: undo,
      ),
    );
}

/// Picks a prayer to append to a category.
///
/// Prayers already in the category are filtered out. This lets users add their
/// own category extras while the shipped category can still receive updates,
/// unlike copying the category into a separate playlist; see
/// [sectionExtrasProvider].
Future<void> _addPrayerToSection(
  BuildContext context,
  WidgetRef ref,
  String sectionId,
) async {
  final l10n = AppLocalizations.of(context);
  final sections = ref.read(prayerListControllerProvider).value ?? const [];
  final already = {
    for (final e in sections)
      if (e.section.id == sectionId)
        for (final p in e.prayers) p.id,
  };

  // Same reason as the playlist sheet: selecting prayers, not (category, prayer)
  // pairs.
  final seen = <String>{};
  final picked = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      builder: (ctx, controller) => ListView(
        controller: controller,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              l10n.sectionAddPrayer,
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
          ),
          for (final entry in sections)
            for (final prayer in entry.prayers)
              if (!already.contains(prayer.id) && seen.add(prayer.id))
                ListTile(
                  key: ValueKey('pick_${entry.section.id}_${prayer.id}'),
                  title: Text(prayer.title),
                  subtitle: Text(entry.section.title),
                  onTap: () => Navigator.pop(ctx, prayer.id),
                ),
        ],
      ),
    ),
  );
  if (picked == null || !context.mounted) return;
  ref.read(sectionExtrasProvider.notifier).add(sectionId, picked);
  _snack(context, l10n.sectionExtraAdded);
}
