import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/prayer.dart';
import '../../../l10n/app_localizations.dart';
import '../../favorites/favorites_controller.dart';
import 'reading_menu.dart';

/// Favourite toggle and overflow menu for the prayer the reader is on.
class ReadingActions extends ConsumerWidget {
  const ReadingActions({
    super.key,
    required this.prayerId,
    required this.prayer,
    required this.malaOpen,
    required this.onToggleMala,
    required this.showPali,
    required this.showMeaning,
  });

  final String prayerId;

  /// Open prayer, null while loading.
  final Prayer? prayer;

  final bool malaOpen;
  final VoidCallback onToggleMala;

  /// The reader's current display choices, copied by [ReadingMenu].
  final bool showPali;
  final bool showMeaning;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isFavorite = ref
        .watch(favoritesControllerProvider)
        .contains(prayerId);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            isFavorite ? Icons.favorite : Icons.favorite_outline,
            color: isFavorite ? Theme.of(context).colorScheme.secondary : null,
          ),
          tooltip: isFavorite ? l10n.favoriteRemove : l10n.favoriteAdd,
          onPressed: () =>
              ref.read(favoritesControllerProvider.notifier).toggle(prayerId),
        ),
        ReadingMenu(
          prayerId: prayerId,
          prayer: prayer,
          malaOpen: malaOpen,
          onToggleMala: onToggleMala,
          // Copy the user's current display choices.
          showPali: showPali,
          showMeaning: showMeaning,
        ),
      ],
    );
  }
}
