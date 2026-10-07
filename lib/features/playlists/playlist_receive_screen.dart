import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_asset_image.dart';
import '../../theme/dashboard_tokens.dart';
import 'playlist_scan_screen.dart';
import 'share_page_parts.dart';
import 'widgets/edit_decorations.dart' show editPanelDecoration;

/// The edit page's card face made flat, with the stronger edge the round
/// controls use, so the cards hold their shape without a shadow.
BoxDecoration _cardDecoration(ThemeData theme) =>
    editPanelDecoration(theme).copyWith(
      border: Border.all(color: DashboardTokens.controlEdge(theme)),
      boxShadow: const [],
    );

/// Landing page for receiving another device's prayer set, drawn from
/// `design/mobile/icon/wait/02/Refined Thai prayer app screen.png`.
///
/// It only chooses the way in: a scan (or a picked QR image) goes straight
/// to the received set's preview (`/playlists/preview`), and pasting reaches
/// the same page through the paste page, so the decode, the unknown-prayer
/// notice and the import itself stay in one place.
class PlaylistReceiveScreen extends StatelessWidget {
  const PlaylistReceiveScreen({super.key});

  static const _giftBox =
      'assets/images/playlists/champagne_gift_box_lotus.png';

  /// Flanks the gift box on both sides — mirrored on the right, so the pair
  /// frames it symmetrically.
  static const _lotus =
      'assets/images/playlists/ivory_lotus_cloud_ornament.png';

  Future<void> _scan(BuildContext context) async {
    final code = await context.push<String>('/playlists/scan');
    if (code != null && context.mounted) {
      await context.push('/playlists/preview', extra: code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final dark = theme.brightness == Brightness.dark;

    // Scanning needs a phone camera. Elsewhere the card still shows, as the
    // artwork draws it, but disabled and saying where it works — hidden, it
    // read as a missing feature rather than a phone-only one.
    final scan = _OptionCard(
      key: const ValueKey('receive_scan'),
      icon: Icons.qr_code_2,
      title: l10n.playlistReceiveScanTitle,
      detail: playlistScanSupported
          ? l10n.playlistReceiveScanDetail
          : l10n.playlistReceiveScanMobileOnly,
      onTap: playlistScanSupported ? () => _scan(context) : null,
    );
    final paste = _OptionCard(
      key: const ValueKey('receive_paste'),
      icon: Icons.file_copy_outlined,
      title: l10n.playlistReceivePasteTitle,
      detail: l10n.playlistReceivePasteDetail,
      onTap: () => context.push('/playlists/paste'),
    );

    return SharePageScaffold(
      title: l10n.playlistImportTitle,
      subtitle: l10n.playlistReceiveSubtitle,
      children: [
        // Box in the middle, a faint lotus cloud to either side of it.
        SizedBox(
          height: 320,
          child: ExcludeSemantics(
            child: Stack(
              alignment: Alignment.center,
              // The clouds run out to the screen edge, past the list's side
              // padding; clipped at the Stack they lost their outer leaves
              // and tails along a hard vertical line.
              clipBehavior: Clip.none,
              children: [
                for (final left in [true, false])
                  Positioned(
                    left: left ? -20 : null,
                    right: left ? null : -20,
                    bottom: 0,
                    width: 175,
                    child: Opacity(
                      // Ivory clouds read as grey smoke on the dark ground.
                      opacity: dark ? 0.08 : 0.8,
                      child: Transform.flip(
                        flipX: !left,
                        child: const AppAssetImage(_lotus, fit: BoxFit.contain),
                      ),
                    ),
                  ),
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: AppAssetImage(
                    _giftBox,
                    height: 290,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.playlistReceiveHeading,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: scan),
              const SizedBox(width: 12),
              Expanded(child: paste),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const _QuoteCard(),
      ],
    );
  }
}

/// One way in: a large brown glyph over a title and a line of help.
class _OptionCard extends StatelessWidget {
  const _OptionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;

  /// Null draws the card disabled: faded, and not tappable.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final decoration = _cardDecoration(theme);
    return DecoratedBox(
      decoration: decoration,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: decoration.borderRadius as BorderRadius?,
          onTap: onTap,
          child: Opacity(
            opacity: onTap == null ? 0.45 : 1,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 22, 12, 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 52, color: shareGold(theme)),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // One line, as drawn: a wrapped detail breaks mid-phrase in
                  // half a phone's width, so it shrinks a little instead.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      detail,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The artwork's closing card: a seedling, a line on the gift of Dhamma, and
/// a lotus watermark fading into the corner.
class _QuoteCard extends StatelessWidget {
  const _QuoteCard();

  static const _seedling = 'assets/images/playlists/golden_seedling.png';
  static const _watermark =
      'assets/images/playlists/champagne_lotus_cloud_watermark.png';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final dark = theme.brightness == Brightness.dark;
    final decoration = _cardDecoration(theme);
    return DecoratedBox(
      decoration: decoration,
      child: ClipRRect(
        borderRadius: decoration.borderRadius!,
        child: Stack(
          children: [
            Positioned(
              right: -10,
              bottom: -10,
              width: 150,
              child: ExcludeSemantics(
                child: Opacity(
                  opacity: dark ? 0.08 : 0.8,
                  child: const AppAssetImage(_watermark, fit: BoxFit.contain),
                ),
              ),
            ),
            // The seedling sits in the left corner on its own layer, so the
            // quote centres on the card rather than on what is left of it.
            Positioned(
              left: 10,
              bottom: 12,
              child: ExcludeSemantics(
                child: Opacity(
                  opacity: dark ? 0.7 : 1,
                  child: const AppAssetImage(
                    _seedling,
                    width: 76,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Padding(
              // Equal insets both sides keep the centre true; the left one
              // clears the seedling.
              padding: const EdgeInsets.symmetric(horizontal: 70, vertical: 22),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        l10n.playlistReceiveQuote,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const LotusRule(width: 180, lotus: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
