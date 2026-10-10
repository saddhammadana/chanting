/// What a fetched prayer book changed, prayer by prayer and line by line.
///
/// A release arrives with no changelog, and the people it reaches chant these
/// texts from memory — a corrected word is exactly the thing they need
/// pointed at. So when a release is stored, it is compared with the book the
/// app was reading until then, and the result travels with it.
///
/// Lines are paired by their `id`, which the data keeps stable for this kind
/// of reference (docs/content/prayer-schema.md §4), so a line inserted in the
/// middle is reported as one new line rather than as every line after it
/// having changed. See docs/architecture/content-updates.md.
library;

import 'dart:convert';

enum PrayerChangeKind { added, changed, removed }

/// One line as it was and as it is. [before] is null for a new line, [after]
/// for one that was taken out.
typedef LineChange = ({String? before, String? after});

class PrayerChange {
  const PrayerChange({
    required this.id,
    required this.title,
    required this.kind,
    this.lines = const [],
  });

  final String id;
  final String title;
  final PrayerChangeKind kind;

  /// The chant text that differs. Empty for an added or removed prayer, and
  /// for one whose only change is outside the chant text — a romanisation, a
  /// translation, a source note.
  final List<LineChange> lines;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'kind': kind.name,
    'lines': [
      for (final line in lines) {'before': line.before, 'after': line.after},
    ],
  };

  factory PrayerChange.fromJson(Map<String, dynamic> json) => PrayerChange(
    id: json['id'] as String,
    title: json['title'] as String,
    kind: PrayerChangeKind.values.byName(json['kind'] as String),
    lines: [
      for (final line in json['lines'] as List<dynamic>)
        (
          before: (line as Map<String, dynamic>)['before'] as String?,
          after: line['after'] as String?,
        ),
    ],
  );
}

/// The prayers that differ between two `prayers-<lang>.json` files, in the
/// order of [after], with removed ones last.
///
/// Works on the raw records rather than on `Prayer`, because "did anything
/// about this record change" is a question about the file, and the model
/// derives and drops fields on the way in.
List<PrayerChange> contentChanges({
  required String before,
  required String after,
}) {
  final old = {
    for (final prayer in _records(before)) prayer['id'] as String: prayer,
  };
  final changes = <PrayerChange>[];

  for (final prayer in _records(after)) {
    final id = prayer['id'] as String;
    final title = prayer['title'] as String? ?? id;
    final was = old.remove(id);
    if (was == null) {
      changes.add(
        PrayerChange(id: id, title: title, kind: PrayerChangeKind.added),
      );
    } else if (jsonEncode(was) != jsonEncode(prayer)) {
      changes.add(
        PrayerChange(
          id: id,
          title: title,
          kind: PrayerChangeKind.changed,
          lines: _lineChanges(was, prayer),
        ),
      );
    }
  }
  for (final gone in old.values) {
    changes.add(
      PrayerChange(
        id: gone['id'] as String,
        title: gone['title'] as String? ?? gone['id'] as String,
        kind: PrayerChangeKind.removed,
      ),
    );
  }
  return changes;
}

List<Map<String, dynamic>> _records(String raw) =>
    (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();

/// Every line's chant text by id, in reading order.
Map<String, String> _texts(Map<String, dynamic> prayer) => {
  for (final part in prayer['sections'] as List<dynamic>? ?? const [])
    for (final line
        in (part as Map<String, dynamic>)['lines'] as List<dynamic>? ??
            const [])
      (line as Map<String, dynamic>)['id'] as String? ?? '':
          line['text'] as String? ?? '',
};

List<LineChange> _lineChanges(
  Map<String, dynamic> was,
  Map<String, dynamic> now,
) {
  final before = _texts(was);
  final after = _texts(now);
  return [
    if (was['title'] != now['title'])
      (before: was['title'] as String?, after: now['title'] as String?),
    for (final entry in after.entries)
      if (before[entry.key] != entry.value)
        (before: before[entry.key], after: entry.value),
    for (final entry in before.entries)
      if (!after.containsKey(entry.key)) (before: entry.value, after: null),
  ];
}

/// The changes a release carries, per content language, as stored with it.
String encodeChanges(Map<String, List<PrayerChange>> changes) => jsonEncode({
  for (final entry in changes.entries)
    entry.key: [for (final change in entry.value) change.toJson()],
});

/// The stored changes for [language]; empty when there are none or the stored
/// value cannot be read, since this is a courtesy and never worth an error.
List<PrayerChange> decodeChanges(String? raw, String language) {
  if (raw == null) return const [];
  try {
    final all = jsonDecode(raw) as Map<String, dynamic>;
    return [
      for (final change in all[language] as List<dynamic>? ?? const [])
        PrayerChange.fromJson(change as Map<String, dynamic>),
    ];
  } catch (_) {
    return const [];
  }
}
