import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_back_button.dart';
import '../../shared/widgets/content_width.dart';
import 'widgets/settings_tile.dart';

/// Reference page for the two scripts a prayer is shown in.
///
/// Its own route rather than a card inside About: this is something a reader
/// reaches for **while reading**, when they hit a mark they do not recognise,
/// so the reading screen's menu links straight here. Landing on About and
/// scrolling past the app icon, version and licences to find it would be the
/// wrong shape for that moment.
class ScriptScreen extends StatelessWidget {
  const ScriptScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        leadingWidth: appBackButtonLeadingWidth,
        title: Text(l10n.aboutSectionScript),
      ),
      body: ContentWidth(
        maxWidth: ContentWidth.gridWidth,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: const [_ScriptBody()],
        ),
      ),
    );
  }
}

/// Explains the two scripts a prayer is shown in, and the diacritics used.
///
/// The app puts Pali in Thai script next to Pali in Roman script, and the two
/// do **not** correspond letter for letter — that difference has already caused
/// real transcription errors (docs/roadmap/todo.md), so it is worth saying out loud rather
/// than leaving readers to infer it.
///
/// This describes what this app does and why. It is deliberately not a guide to
/// pronouncing Pali: that would be scholarly content, and content in this app
/// comes from cited sources, never from the developer's memory.
class _ScriptBody extends StatelessWidget {
  const _ScriptBody();

  /// Every diacritic that actually occurs in `roman` across the whole data file,
  /// grouped by what the mark means. Examples are real words from the file, with
  /// the Thai-script reading of the same word beside them, so the correspondence
  /// can be checked rather than taken on trust.
  static const _rows = <(String, String Function(AppLocalizations), String)>[
    ('ā ī ū', _longVowel, 'bhagavā · ภะคะวา'),
    ('ṭ ḍ ṇ ḷ', _retroflex, 'supaṭipanno · สุปะฏิปันโน'),
    ('ṅ', _velarNasal, 'saṅgho · สังโฆ'),
    ('ñ', _palatalNasal, 'viññū · วิญญู'),
    ('ṃ', _niggahita, 'arahaṃ · อะระหัง'),
  ];

  static String _longVowel(AppLocalizations l) => l.aboutScriptLongVowel;
  static String _retroflex(AppLocalizations l) => l.aboutScriptRetroflex;
  static String _velarNasal(AppLocalizations l) => l.aboutScriptVelarNasal;
  static String _palatalNasal(AppLocalizations l) => l.aboutScriptPalatalNasal;
  static String _niggahita(AppLocalizations l) => l.aboutScriptNiggahita;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    Widget heading(String text) => Text(
      text,
      style: theme.textTheme.titleSmall?.copyWith(
        color: theme.colorScheme.secondary,
        fontWeight: FontWeight.w700,
      ),
    );
    Widget body(String text) =>
        Text(text, style: theme.textTheme.bodyMedium?.copyWith(height: 1.6));

    return RaisedCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            heading(l10n.aboutSectionScript),
            const SizedBox(height: 12),
            Text(
              l10n.aboutScriptThaiTitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            body(l10n.aboutScriptThaiBody),
            const SizedBox(height: 16),
            Text(
              l10n.aboutScriptRomanTitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            body(l10n.aboutScriptRomanBody),
            const SizedBox(height: 12),
            for (final (chars, label, example) in _rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Fixed-width first column so the marks line up as a table;
                    // they are the thing being looked up.
                    SizedBox(
                      width: 68,
                      child: Text(
                        chars,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label(l10n), style: theme.textTheme.bodyMedium),
                          Text(
                            example,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer.withValues(
                  alpha: 0.4,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                l10n.aboutScriptNiggahitaNote,
                style: theme.textTheme.bodySmall?.copyWith(height: 1.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
