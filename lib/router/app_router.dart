import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/favorites/favorites_screen.dart';
import '../features/meditation/meditation_timer_screen.dart';
import '../features/playlists/playlist_detail_screen.dart';
import '../features/playlists/playlist_edit_screen.dart';
import '../features/playlists/playlist_paste_screen.dart';
import '../features/playlists/playlist_receive_screen.dart';
import '../features/playlists/playlist_scan_screen.dart';
import '../features/playlists/playlist_share_screen.dart';
import '../features/playlists/playlists_screen.dart';
import '../features/prayer_detail/prayer_detail_screen.dart';
import '../features/prayer_list/all_prayers_screen.dart';
import '../features/prayer_list/categories_screen.dart';
import '../features/prayer_list/category_screen.dart';
import '../features/prayer_list/day_part.dart';
import '../features/prayer_list/prayer_list_screen.dart';
import '../features/settings/about_screen.dart';
import '../features/settings/content_update_screen.dart';
import '../features/settings/goal_screen.dart';
import '../features/settings/language_screen.dart';
import '../features/settings/legal_screen.dart';
import '../features/settings/reading_settings_screen.dart';
import '../features/settings/script_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/settings/settings_search_screen.dart';
import '../features/settings/sound_screen.dart';
import '../features/settings/theme_screen.dart';
import '../l10n/app_localizations.dart';
import '../shared/widgets/app_back_button.dart';
import '../shared/widgets/app_bottom_navigation.dart';
import '../shared/widgets/empty_state.dart';

/// Keeps all routes in one file while the app remains small.
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) =>
          AppNavigationShell(location: state.uri.path, child: child),
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const PrayerListScreen(),
        ),
        GoRoute(
          path: '/all',
          builder: (context, state) => const AllPrayersScreen(),
        ),
        GoRoute(
          path: '/start',
          // The service for this part of the day, the same one the home
          // card names.
          builder: (context, state) => CategoryScreen(
            sectionId: DayPart.of(DateTime.now()).serviceSectionId,
          ),
        ),
        GoRoute(
          path: '/playlists',
          builder: (context, state) => const PlaylistsScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    ),
    // Entry points from home tiles: /all is every category, /category/<id> is
    // one category. Use ids instead of names because category titles vary by
    // content language; see PrayerSection.
    // Home for categories that are not pinned to the front page.
    GoRoute(
      path: '/categories',
      builder: (context, state) => const CategoriesScreen(),
    ),
    GoRoute(
      path: '/category/:id',
      builder: (context, state) =>
          CategoryScreen(sectionId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/prayer/:id',
      pageBuilder: (context, state) {
        final child = PrayerDetailScreen(
          prayerId: state.pathParameters['id']!,
          // ?pl=<id> opens from a playlist, so next/previous follows playlist order.
          playlistId: state.uri.queryParameters['pl'],
          // ?section=<id> identifies the source category because one prayer can
          // appear in multiple categories. Missing means deep links and resume
          // cards fall back to the first category containing this prayer.
          sectionId: state.uri.queryParameters['section'],
          // ?resume=1 restores the last scroll offset from the resume card.
          resumeReading: state.uri.queryParameters['resume'] == '1',
        );
        // ?dir=next|prev|up|down comes from swipes or navigation buttons and
        // controls the incoming page-slide direction. Missing dir uses the
        // normal route transition.
        final dir = state.uri.queryParameters['dir'];
        if (dir != 'next' && dir != 'prev' && dir != 'up' && dir != 'down') {
          return MaterialPage(key: state.pageKey, child: child);
        }
        final begin = switch (dir) {
          'prev' => const Offset(-1, 0),
          'up' => const Offset(0, 1),
          'down' => const Offset(0, -1),
          _ => const Offset(1, 0),
        };
        return CustomTransitionPage<void>(
          key: state.pageKey,
          child: child,
          transitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final slideIn = Tween<Offset>(
              begin: begin,
              end: Offset.zero,
            ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation);
            return SlideTransition(
              position: slideIn,
              // Edge shadow makes the sliding page read as stacked paper.
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: child,
              ),
            );
          },
        );
      },
    ),
    GoRoute(
      path: '/favorites',
      builder: (context, state) => const FavoritesScreen(),
    ),
    // Must be declared before /playlists/:id so "scan", "receive", "paste"
    // and "new" are not parsed as ids.
    GoRoute(
      path: '/playlists/scan',
      builder: (context, state) => const PlaylistScanScreen(),
    ),
    GoRoute(
      path: '/playlists/receive',
      builder: (context, state) => const PlaylistReceiveScreen(),
    ),
    GoRoute(
      path: '/playlists/paste',
      builder: (context, state) => const PlaylistPasteScreen(),
    ),
    // A received set before it is saved; the code (pasted or scanned)
    // arrives as `extra`. Declared before `/playlists/:id`, which would
    // otherwise take "preview" for an id.
    GoRoute(
      path: '/playlists/preview',
      builder: (context, state) =>
          PlaylistPreviewScreen(code: state.extra as String? ?? ''),
    ),
    GoRoute(
      path: '/playlists/new',
      builder: (context, state) => const PlaylistEditScreen(),
    ),
    GoRoute(
      path: '/playlists/:id',
      builder: (context, state) =>
          PlaylistDetailScreen(playlistId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/playlists/:id/edit',
      builder: (context, state) => PlaylistEditScreen(
        playlistId: state.pathParameters['id']!,
        // "จัดลำดับ" on the set page opens straight on the chosen tab.
        startOnSelected: state.uri.queryParameters['tab'] == 'selected',
      ),
    ),
    GoRoute(
      path: '/playlists/:id/share',
      builder: (context, state) =>
          PlaylistShareScreen(playlistId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/meditation',
      builder: (context, state) => const MeditationTimerScreen(),
    ),
    GoRoute(path: '/about', builder: (context, state) => const AboutScreen()),
    GoRoute(path: '/legal', builder: (context, state) => const LegalScreen()),
    // Settings sub-pages sit outside the shell on purpose: they are a stack
    // the back button walks up, not destinations, and leaving them inside it
    // would light up the wrong bottom-nav tab.
    GoRoute(
      path: '/settings/reading',
      builder: (context, state) => const ReadingSettingsScreen(),
    ),
    GoRoute(
      path: '/settings/goal',
      // ?first=1 is the once-after-install visit, which gains a ข้าม action.
      builder: (context, state) =>
          GoalScreen(onboarding: state.uri.queryParameters['first'] == '1'),
    ),
    GoRoute(
      path: '/settings/language',
      builder: (context, state) => const LanguageScreen(),
    ),
    GoRoute(
      path: '/settings/theme',
      builder: (context, state) => const ThemeScreen(),
    ),
    GoRoute(
      path: '/settings/sound',
      builder: (context, state) => const SoundScreen(),
    ),
    GoRoute(
      path: '/settings/content',
      builder: (context, state) => const ContentUpdateScreen(),
    ),
    GoRoute(
      path: '/settings/search',
      builder: (context, state) => const SettingsSearchScreen(),
    ),
    // Reference page for the two scripts; reached from About and from the
    // reading screen's menu, which is where the question actually comes up.
    GoRoute(path: '/script', builder: (context, state) => const ScriptScreen()),
  ],
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(
      leading: const AppBackButton(),
      leadingWidth: appBackButtonLeadingWidth,
    ),
    body: EmptyState(
      icon: Icons.search_off,
      message: AppLocalizations.of(context).notFound,
    ),
  ),
);
