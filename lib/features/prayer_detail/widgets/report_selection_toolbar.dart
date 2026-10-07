import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// Selection toolbar with the report action first.
///
/// First, because the Material toolbar only shows what fits and pushes the
/// rest behind an overflow button; reporting must never fall to page two.
class ReportSelectionToolbar extends StatelessWidget {
  const ReportSelectionToolbar({
    super.key,
    required this.state,
    required this.onReport,
  });

  final SelectableRegionState state;

  /// Opens the report sheet; null when there is no prayer to report on.
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    final report = onReport;
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: state.contextMenuAnchors,
      buttonItems: [
        if (report != null)
          ContextMenuButtonItem(
            label: AppLocalizations.of(context).menuReportError,
            onPressed: () {
              state.hideToolbar();
              report();
            },
          ),
        ...state.contextMenuButtonItems,
      ],
    );
  }
}
