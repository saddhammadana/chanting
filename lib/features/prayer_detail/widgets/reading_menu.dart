import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/pinned_ref.dart';
import '../../../data/models/prayer.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../prayer_list/pinned_controller.dart';
import '../../prayer_list/prayer_list_controller.dart';
import '../prayer_report_sheet.dart';
import 'font_size_sheet.dart';

/// Reader AppBar overflow menu for secondary actions.
///
/// Keep AppBar icons minimal so category/playlist titles have room. Other actions
/// live here.
///
/// This can live outside the reader screen because most actions talk directly to
/// providers or router. The mala counter is the only reader-local state, passed
/// in through [malaOpen] and [onToggleMala].
class ReadingMenu extends ConsumerWidget {
  const ReadingMenu({
    super.key,
    required this.prayerId,
    required this.prayer,
    required this.malaOpen,
    required this.onToggleMala,
    this.showPali = false,
    this.showMeaning = false,
  });

  final String prayerId;

  /// Open prayer, null while loading; content-dependent actions are disabled.
  final Prayer? prayer;

  final bool malaOpen;
  final VoidCallback onToggleMala;

  /// Whether Pali/meaning chips are active; copying follows these flags.
  final bool showPali;
  final bool showMeaning;

  /// Copies real prayer content as stored in data, without translation.
  ///
  /// Copy what is visible: active Pali/meaning chips include those blocks, while
  /// inactive chips copy only the main text. Users sharing while reading meaning
  /// expect the same content they are seeing.
  ///
  /// Blocks with headings are easier to read than inline interleaving in pasted
  /// chat text. Inline display requires line pairing (`PrayerContent.canInlinePali`)
  /// and screen styling that pasted text does not have.
  Future<void> _copyPrayer(BuildContext context, Prayer prayer) async {
    final l10n = AppLocalizations.of(context);
    final copied = l10n.prayerCopied;
    final pali = prayer.hasDistinctPali ? prayer.paliText : null;
    await Clipboard.setData(
      ClipboardData(
        text: [
          prayer.title,
          '',
          prayer.text,
          if (showPali && pali != null) ...['', '[${l10n.labelPali}]', pali],
          if (showMeaning && prayer.meaning != null) ...[
            '',
            '[${l10n.labelMeaning}]',
            prayer.meaning!,
          ],
        ].join('\n'),
      ),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(appToast(copied, duration: const Duration(seconds: 2)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final pinRef = PinnedRef(PinnedType.prayer, prayerId);
    final isPinned = ref.watch(pinnedControllerProvider).contains(pinRef);
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      tooltip: l10n.menuMore,
      onSelected: (value) {
        switch (value) {
          case 'fontSize':
            showFontSizeSheet(context);
          case 'mala':
            onToggleMala();
          case 'copy':
            _copyPrayer(context, prayer!);
          case 'report':
            showPrayerReportSheet(
              context,
              prayer: prayer!,
              contentLanguage: ref.read(prayerRepositoryProvider).languageCode,
            );
          case 'pin':
            final pinned = ref
                .read(pinnedControllerProvider.notifier)
                .toggle(pinRef);
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                appToast(
                  pinned ? l10n.pinnedAdded : l10n.pinnedRemoved,
                  kind: pinned ? ToastKind.success : ToastKind.info,
                  duration: const Duration(milliseconds: 1500),
                ),
              );
          case 'script':
            context.push('/script');
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'fontSize',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.format_size),
            title: Text(l10n.settingsFontSize),
          ),
        ),
        PopupMenuItem(
          value: 'mala',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              malaOpen
                  ? Icons.radio_button_checked
                  : Icons.blur_circular_outlined,
            ),
            title: Text(l10n.malaTitle),
          ),
        ),
        PopupMenuItem(
          value: 'pin',
          child: ListTile(
            key: const ValueKey('pin_prayer_item'),
            contentPadding: EdgeInsets.zero,
            leading: Icon(isPinned ? Icons.push_pin : Icons.push_pin_outlined),
            title: Text(isPinned ? l10n.unpinFromHome : l10n.pinToHome),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'copy',
          enabled: prayer != null,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.copy_outlined),
            title: Text(l10n.menuCopyPrayer),
          ),
        ),
        PopupMenuItem(
          value: 'report',
          enabled: prayer != null,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.report_gmailerrorred_outlined),
            title: Text(l10n.menuReportError),
          ),
        ),
        const PopupMenuDivider(),
        // Someone meeting a mark they do not recognise is looking at the
        // prayer, not at the About page, so the guide is one tap from here.
        PopupMenuItem(
          value: 'script',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.abc),
            title: Text(l10n.aboutSectionScript),
          ),
        ),
      ],
    );
  }
}
