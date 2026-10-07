import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/prayer.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_toast.dart';

/// Destination for prayer error reports: the app maintainer's email address.
///
/// Reports are sent through `mailto:`. If no mail app can be opened, the report
/// is copied to the clipboard and the user is told where to send it. There is
/// no backend.
const kReportEmail = 'saddhammadana@gmail.com';

/// Open the prayer error report sheet: field selection plus free-form details.
///
/// [contentLanguage] is the **prayer edition** being read (th/en), not the UI
/// language. It tells the maintainer which `prayers-<lang>.json` file to edit.
///
/// [selectedText] is text selected in the reader before reporting. It points to
/// the exact faulty passage instead of making the maintainer count lines.
Future<void> showPrayerReportSheet(
  BuildContext context, {
  required Prayer prayer,
  required String contentLanguage,
  String? selectedText,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      // Keep the sheet above the keyboard while the user types details.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: _ReportSheet(
        prayer: prayer,
        contentLanguage: contentLanguage,
        selectedText: selectedText,
      ),
    ),
  );
}

/// Prayer field being reported. Stored values are stable English keys for the
/// report; visible labels are localized for the UI.
enum _ReportField {
  text('text'),
  meaning('meaning'),
  pali('paliText'),
  title('title'),
  other('other');

  const _ReportField(this.key);
  final String key;

  String label(AppLocalizations l10n) => switch (this) {
    _ReportField.text => l10n.reportFieldText,
    _ReportField.meaning => l10n.reportFieldMeaning,
    _ReportField.pali => l10n.reportFieldPali,
    _ReportField.title => l10n.reportFieldTitle,
    _ReportField.other => l10n.reportFieldOther,
  };
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({
    required this.prayer,
    required this.contentLanguage,
    this.selectedText,
  });

  final Prayer prayer;
  final String contentLanguage;

  /// Text selected from the reader (null when opened normally from the menu).
  final String? selectedText;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  late _ReportField _field = _fieldOfSelection() ?? _ReportField.text;
  final _detailController = TextEditingController();
  bool _showError = false;

  /// Infer which prayer field the selected text belongs to from the data, not
  /// screen position. Pali/meaning may be inline or at the end.
  ///
  /// Return null when ambiguous or blank, then keep the default field. The user
  /// can still choose a different dropdown value.
  _ReportField? _fieldOfSelection() {
    final needle = widget.selectedText?.trim();
    if (needle == null || needle.isEmpty) return null;
    final p = widget.prayer;
    for (final (field, value) in <(_ReportField, String?)>[
      (_ReportField.text, p.text),
      (_ReportField.pali, p.paliText),
      (_ReportField.meaning, p.meaning),
      (_ReportField.title, p.title),
    ]) {
      if (value != null && value.contains(needle)) return field;
    }
    return null;
  }

  /// App version loaded asynchronously for report triage. Null means not loaded
  /// or unavailable; it is simply omitted and never blocks sending.
  String? _appVersion;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _appVersion = '${info.version}+${info.buildNumber}');
      }
    } catch (_) {
      // Version is only supplemental report context; skip it if unavailable.
    }
  }

  @override
  void dispose() {
    _detailController.dispose();
    super.dispose();
  }

  /// Platform label for the report so maintainers know where the issue appeared.
  String get _platformLabel => kIsWeb ? 'web' : defaultTargetPlatform.name;

  /// Current value of the reported field. Include it so maintainers can compare
  /// the stored content with the user's report without opening data files. Null
  /// means the field has no value or "other" was selected.
  String? _currentValue() {
    final p = widget.prayer;
    return switch (_field) {
      _ReportField.text => p.text,
      _ReportField.meaning => p.meaning,
      _ReportField.pali => p.paliText,
      _ReportField.title => p.title,
      _ReportField.other => null,
    };
  }

  /// Report body that is sent or copied, with a stable maintainer-friendly shape.
  String _buildBody() {
    final p = widget.prayer;
    final current = _currentValue();
    final selected = widget.selectedText?.trim();
    return [
      'id: ${p.id}',
      'lang: ${widget.contentLanguage}',
      'title: ${p.title}',
      'field: ${_field.key}',
      'platform: $_platformLabel',
      if (_appVersion != null) 'app: $_appVersion',
      // Put selected text before `current:` because it is the exact passage the
      // user pointed at. `current:` is full-field context for comparison.
      if (selected != null && selected.isNotEmpty) ...[
        '',
        'selected:',
        selected,
      ],
      if (current != null) ...['', 'current:', current],
      '',
      '---',
      _detailController.text.trim(),
    ].join('\n');
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (_detailController.text.trim().isEmpty) {
      setState(() => _showError = true);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final subject = l10n.reportEmailSubject(widget.prayer.id);
    final body = _buildBody();

    // Always copy to the clipboard as a safety net. Desktop/web can report
    // launchUrl success even when no mail app actually handles the message.
    await Clipboard.setData(ClipboardData(text: '$subject\n\n$body'));

    // Build the query manually. Uri queryParameters encodes spaces as '+', which
    // some mail clients do not decode in mailto bodies.
    final uri = Uri.parse(
      'mailto:$kReportEmail'
      '?subject=${Uri.encodeComponent(subject)}'
      '&body=${Uri.encodeComponent(body)}',
    );

    var opened = false;
    try {
      opened = await launchUrl(uri);
    } catch (_) {
      opened = false;
    }

    if (!opened) {
      // No mail handler was opened; tell the user to send the copied report manually.
      messenger.showSnackBar(
        appToast(l10n.reportCopiedFallback(kReportEmail), kind: ToastKind.info),
      );
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final selected = widget.selectedText?.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.reportSheetTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            l10n.reportSheetIntro(widget.prayer.title),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          // Opened from the menu means no exact passage was selected. Show the
          // selection shortcut here, where it is relevant to the reporting flow.
          if (selected == null || selected.isEmpty) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  size: 16,
                  color: theme.colorScheme.secondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.reportSelectHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (selected != null && selected.isNotEmpty) ...[
            const SizedBox(height: 12),
            // Show the selected text so the user can confirm the exact reported
            // passage before sending; the reader selection toolbar is hidden by
            // the time this sheet is open.
            //
            // Cap it at 120px and scroll inside. Selecting a whole prayer is
            // allowed, but letting this grow would push the send button offscreen.
            Container(
              key: const ValueKey('report_selected_text'),
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 120),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer.withValues(
                  alpha: 0.4,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.reportSelectedLabel,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.secondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(selected, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          DropdownButtonFormField<_ReportField>(
            initialValue: _field,
            borderRadius: BorderRadius.circular(12),
            // The menu is a popup like any other in the app.
            dropdownColor: Theme.of(context).popupMenuTheme.color,
            decoration: InputDecoration(labelText: l10n.reportFieldSection),
            items: [
              for (final f in _ReportField.values)
                DropdownMenuItem(value: f, child: Text(f.label(l10n))),
            ],
            onChanged: (f) => setState(() => _field = f ?? _field),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _detailController,
            minLines: 3,
            maxLines: 6,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              labelText: l10n.reportDetailLabel,
              hintText: l10n.reportDetailHint,
              errorText: _showError ? l10n.reportDetailRequired : null,
            ),
            onChanged: (_) {
              if (_showError) setState(() => _showError = false);
            },
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.send_outlined),
            label: Text(l10n.reportSubmit),
          ),
        ],
      ),
    );
  }
}
