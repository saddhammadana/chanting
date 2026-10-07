import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_back_button.dart';
import '../../shared/widgets/content_width.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading_indicator.dart';
import 'prayer_list_controller.dart';
import 'widgets/grouped_prayer_list.dart';

/// Searchable directory owned by the Prayers bottom-navigation destination.
class AllPrayersScreen extends ConsumerStatefulWidget {
  const AllPrayersScreen({super.key});

  @override
  ConsumerState<AllPrayersScreen> createState() => _AllPrayersScreenState();
}

class _AllPrayersScreenState extends ConsumerState<AllPrayersScreen> {
  static const _searchMaxWidth = ContentWidth.gridWidth;

  final _searchFocus = FocusNode();
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(searchQueryProvider),
    );
    _searchFocus.addListener(_onFocusChanged);
  }

  void _onFocusChanged() => setState(() {});

  @override
  void dispose() {
    _searchFocus
      ..removeListener(_onFocusChanged)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _openPrayer(String id) {
    final query = ref.read(searchQueryProvider);
    if (query.trim().isNotEmpty) {
      ref.read(searchHistoryProvider.notifier).add(query);
    }
    FocusManager.instance.primaryFocus?.unfocus();
    context.push('/prayer/$id');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final prayersAsync = ref.watch(filteredPrayersProvider);
    final query = ref.watch(searchQueryProvider);
    final history = ref.watch(searchHistoryProvider);
    final showSuggestions =
        _searchFocus.hasFocus && query.isEmpty && history.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.homeAllPrayers),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 16),
            child: IconButton(
              key: const ValueKey('prayers_favorites'),
              icon: const Icon(Icons.favorite_outline),
              tooltip: l10n.favoritesTitle,
              style: appCircleIconButtonStyle(Theme.of(context)),
              onPressed: () => context.push('/favorites'),
            ),
          ),
        ],
      ),
      body: ContentWidth(
        maxWidth: ContentWidth.gridWidth,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: LayoutBuilder(
                builder: (context, constraints) => SearchBar(
                  key: const ValueKey('prayers_search'),
                  controller: _searchController,
                  focusNode: _searchFocus,
                  hintText: l10n.searchHint,
                  leading: const Icon(Icons.search),
                  constraints: BoxConstraints(
                    minWidth: 0,
                    maxWidth: constraints.maxWidth,
                    minHeight: 56,
                  ),
                  elevation: const WidgetStatePropertyAll(0),
                  trailing: [
                    if (query.isNotEmpty)
                      IconButton(
                        key: const ValueKey('search_clear'),
                        icon: const Icon(Icons.close),
                        tooltip: l10n.searchClear,
                        onPressed: () {
                          _searchController.clear();
                          ref.read(searchQueryProvider.notifier).set('');
                          _searchFocus.requestFocus();
                        },
                      ),
                  ],
                  onChanged: (value) =>
                      ref.read(searchQueryProvider.notifier).set(value),
                  onSubmitted: (value) =>
                      ref.read(searchHistoryProvider.notifier).add(value),
                ),
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  prayersAsync.when(
                    skipLoadingOnReload: true,
                    loading: () => const LoadingIndicator(),
                    error: (e, _) => EmptyState(
                      icon: Icons.error_outline,
                      message: l10n.prayerLoadError,
                      detail: '$e',
                    ),
                    data: (sections) {
                      if (sections.isEmpty) {
                        return EmptyState(
                          icon: query.isEmpty
                              ? Icons.menu_book_outlined
                              : Icons.search_off,
                          message: query.isEmpty
                              ? l10n.prayerListEmpty
                              : l10n.searchNoResults,
                        );
                      }
                      return GroupedPrayerList(
                        sections: sections,
                        highlight: query.trim(),
                        onTapPrayer: (prayer) => _openPrayer(prayer.id),
                      );
                    },
                  ),
                  if (showSuggestions) ...[
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _searchFocus.unfocus,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      left: 16,
                      right: 16,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: _searchMaxWidth,
                          ),
                          child: TextFieldTapRegion(
                            child: _SearchHistoryPanel(
                              history: history,
                              onPick: (value) {
                                _searchController.text = value;
                                ref
                                    .read(searchQueryProvider.notifier)
                                    .set(value);
                                ref
                                    .read(searchHistoryProvider.notifier)
                                    .add(value);
                                _searchFocus.unfocus();
                              },
                              onRemove: (value) => ref
                                  .read(searchHistoryProvider.notifier)
                                  .remove(value),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchHistoryPanel extends StatelessWidget {
  const _SearchHistoryPanel({
    required this.history,
    required this.onPick,
    required this.onRemove,
  });

  final List<String> history;
  final void Function(String query) onPick;
  final void Function(String query) onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      elevation: 3,
      color: scheme.surface,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(
              AppLocalizations.of(context).searchRecentHeader.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          for (final query in history)
            ListTile(
              leading: Icon(
                Icons.search,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
              title: Text(query),
              trailing: IconButton(
                icon: Icon(
                  Icons.close,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                tooltip: AppLocalizations.of(context).searchClear,
                onPressed: () => onRemove(query),
              ),
              dense: true,
              visualDensity: VisualDensity.compact,
              onTap: () => onPick(query),
            ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}
