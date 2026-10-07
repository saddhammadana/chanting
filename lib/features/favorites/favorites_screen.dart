import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_back_button.dart';
import '../../shared/widgets/content_width.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../prayer_list/prayer_list_controller.dart';
import '../prayer_list/section_icon_overrides.dart';
import '../prayer_list/widgets/home_cards.dart';
import 'favorites_controller.dart';

/// Saved prayers, drawn as the all-categories list is: each row carries the
/// icon and the name of the category the prayer is filed under.
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final favoritesAsync = ref.watch(favoritePrayersProvider);
    // Prayer id -> the first category it is filed under. A prayer may sit in
    // several; the first is the one the reader falls back to as well.
    final sections = ref.watch(prayerListControllerProvider).value ?? const [];
    final iconOverrides = ref.watch(sectionIconOverridesProvider);
    final home = {
      for (final entry in sections.reversed)
        for (final prayer in entry.prayers) prayer.id: entry.section,
    };

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        leadingWidth: appBackButtonLeadingWidth,
        title: Text(l10n.favoritesTitle),
      ),
      body: favoritesAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          message: l10n.favoritesLoadError,
          detail: '$e',
        ),
        data: (prayers) {
          if (prayers.isEmpty) {
            return EmptyState(
              icon: Icons.favorite_outline,
              message: l10n.favoritesEmptyMessage,
              detail: l10n.favoritesEmptyDetail,
            );
          }
          return ContentWidth(
            maxWidth: ContentWidth.gridWidth,
            child: ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              children: [
                for (final prayer in prayers)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 5, 16, 5),
                    child: GoldenRowCard(
                      key: ValueKey('favorite_row_${prayer.id}'),
                      title: prayer.title,
                      icon: switch (home[prayer.id]) {
                        final section? => resolvedSectionIcon(
                          section,
                          iconOverrides,
                        ),
                        null => Icons.menu_book_outlined,
                      },
                      subtitle: home[prayer.id]?.title,
                      onTap: () => context.push('/prayer/${prayer.id}'),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
