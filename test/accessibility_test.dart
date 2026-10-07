import 'dart:io' show Platform;

import 'package:chanting/router/app_router.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_screens.dart';

/// Flutter's accessibility guidelines, run against every screen that can be
/// opened on its own (`appScreens()`, which is also where a new page is
/// added). Each one is opened on a phone-sized view and checked for tap
/// targets that are large enough and controls that carry a label.
///
/// [_knownGaps] lists the nodes that do not pass today, matched against the
/// failure text so everything else on the same screen is still checked — an
/// entry used to turn a whole guideline off for a screen, which hid anything
/// else that screen got wrong. An entry that stops matching fails the test
/// until it is removed.
///
/// Text contrast is checked too, and almost every gap listed below is one: the
/// artwork writes a white label on the gold face and sets its secondary text in
/// a soft brown on cream, and both land under WCAG AA. Those are the palette's,
/// not a layout mistake, so they are recorded here rather than quietly fixed —
/// moving either colour is the owner's call. What this does catch is a *new*
/// piece of text joining them.
enum _Check {
  androidTapSize,
  iosTapSize,
  labelled,
  contrast;

  AccessibilityGuideline get guideline => switch (this) {
    _Check.androidTapSize => androidTapTargetGuideline,
    _Check.iosTapSize => iOSTapTargetGuideline,
    _Check.labelled => labeledTapTargetGuideline,
    _Check.contrast => textContrastGuideline,
  };
}

const _knownGaps = <String, List<String>>{
  // Tap targets and labels: both are Flutter's `SearchBar`, not this app's
  // layout. The guidelines measure the editable text line (24 high) rather
  // than the 56-high box the finger lands on, and the box's own ink node
  // carries no label while the field inside it does. The field in the settings
  // app bar is 40 high, the height of the back button beside it, which the
  // measurement cannot see either way.
  //
  // Contrast: the artwork's two palettes sit under WCAG AA, and changing
  // either is a design decision rather than a fix (see the note above). They
  // are listed by the font size of the text that fails, because a ratio moves
  // with the way a platform rasterises a glyph while the size does not, and
  // the measured ratio today is in the comment beside each one.
  //
  //   white on the gold face  — 2.07 to 2.58, needs 4.5
  //   muted text on the cream — 3.29 to 4.33, needs 4.5
  'home': ['for a font size of 16.0'], // 2.07, the gold start pill
  'all prayers': [
    'ค้นหาบทสวด',
    'expected tappable node to have semantic label',
    'for a font size of 14.0', // 2.24, the chosen category chip
  ],
  'reading': ['for a font size of 12.0'], // 4.33, the part counter
  'favorites': ['for a font size of 14.0'], // 3.77, the empty-state line
  'prayer sets': ['for a font size of 11.0'], // 3.62, the page's caption
  'new prayer set': ['for a font size of 14.0'], // 2.35, the chosen filter
  'edit prayer set': ['for a font size of 14.0'], // 2.35, the chosen filter
  'preview a received set': ['for a font size of 16.0'], // 2.58, the confirm
  'meditation': ['for a font size of 14.0'], // 2.41, the chosen duration
  'settings hub': ['for a font size of 11.0'], // 3.62, the page's caption
  'settings search': [
    'ค้นหาการตั้งค่า',
    'expected tappable node to have semantic label',
  ],
  'reading settings': ['for a font size of 12.0'], // 3.31, the lead line
  'goal and reminders': ['for a font size of 12.0'], // 3.29, the lead line
  'sound': ['for a font size of 12.0'], // 3.29, the lead line
  'language': ['for a font size of 12.0'], // 3.29, the lead line
  'theme': ['for a font size of 12.0'], // 3.29, the lead line
};

/// Marks a contrast entry in [_knownGaps].
const _contrastGap = 'for a font size of';

/// Whether text contrast is checked on this machine.
///
/// The guideline samples rendered pixels, so what it measures depends on the
/// platform's text rasteriser: on the Linux CI image it reported ratios as low
/// as 1.20 for text macOS measures above 4.5, on nodes that pass here. The
/// known gaps were measured on macOS, so that is where the check runs. Tap
/// targets and labels are geometry and are checked everywhere.
final _checksContrast = Platform.isMacOS;

/// One failure per node, split out of a guideline's combined reason.
List<String> _nodeFailures(Evaluation result) => (result.reason ?? '')
    .split('See also:')
    .map((failure) => failure.trim())
    .where((failure) => failure.startsWith('SemanticsNode#'))
    .toList();

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    rootBundle.evict('assets/data/prayers-th.json');
    appRouter.go('/');
  });

  for (final entry in appScreens().entries) {
    testWidgets('${entry.key}: tap targets are large enough and labelled', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await openScreen(tester, entry.value);

      // Every guideline is evaluated before anything is asserted, so one run
      // reports all of a screen's shortfalls instead of only the first.
      final gaps = _knownGaps[entry.key] ?? const <String>[];
      final unmatched = {
        for (final gap in gaps)
          if (_checksContrast || !gap.contains(_contrastGap)) gap,
      };
      final failures = <String>[];
      for (final check in _Check.values) {
        if (check == _Check.contrast && !_checksContrast) continue;
        final result = await check.guideline.evaluate(tester);
        for (final failure in _nodeFailures(result)) {
          final known = gaps.where(failure.contains);
          if (known.isEmpty) {
            failures.add('${check.name}: $failure');
          } else {
            unmatched.removeAll(known);
          }
        }
      }
      handle.dispose();

      expect(failures, isEmpty, reason: failures.join('\n\n'));
      expect(
        unmatched,
        isEmpty,
        reason:
            '${unmatched.join(', ')}: nothing fails on this screen any more; '
            'remove it from _knownGaps',
      );
    });
  }
}
