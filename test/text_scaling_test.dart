import 'package:chanting/router/app_router.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_screens.dart';

/// Every screen rendered at the largest text the platform settings offer, which
/// is what an older reader — much of this app's audience — actually has turned
/// on. A row that cannot grow throws `A RenderFlex overflowed by …`, which is
/// invisible in a release build: the content is simply cut off.
///
/// 2.0 is where Android's "Largest" font size lands; iOS reaches a similar
/// place with the accessibility sizes.
const _scale = 2.0;

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    rootBundle.evict('assets/data/prayers-th.json');
    appRouter.go('/');
  });

  for (final entry in appScreens().entries) {
    testWidgets('${entry.key}: lays out at ${_scale}x text', (tester) async {
      await openScreen(tester, entry.value, textScale: _scale);

      expect(
        tester.takeException(),
        isNull,
        reason:
            '${entry.key} does not fit at ${_scale}x text. Let the row wrap or '
            'scroll rather than capping its height.',
      );
    });
  }
}
