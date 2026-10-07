import 'package:flutter/material.dart';

import '../../../shared/widgets/app_back_button.dart';
import '../../../theme/app_theme.dart';

/// The reader's AppBar, painted in the page colour so the screen reads as one
/// sheet rather than a panel inside the app.
class ReadingAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ReadingAppBar({
    super.key,
    required this.page,
    required this.title,
    required this.actions,
  });

  final ReadingBackground page;

  /// Section or playlist name; null while the prayer is still loading.
  final String? title;

  /// Usually a `ReadingActions`, wrapped by whatever rebuilds it.
  final Widget actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: page.color,
      foregroundColor: defaultReadingText(page.brightness),
      // The app's own back button, faced in the page colour: this
      // bar is paper, and a theme-coloured disc on the night page
      // would be a lit spot above the prayer.
      leading: AppBackButton(
        fill: page.color,
        foreground: defaultReadingText(page.brightness),
      ),
      leadingWidth: appBackButtonLeadingWidth,
      // AppBar shows the section/playlist; the prayer title is in content.
      // The whole reading screen stays in the Thai serif, chrome
      // included; every other screen is set in Sarabun.
      titleTextStyle: AppTheme.serif(
        Theme.of(context).appBarTheme.titleTextStyle,
      ),
      title: title == null ? null : Text(title!),
      // Continuous-mode progress lives in `ContinuousContent`.
      actions: [actions],
    );
  }
}
