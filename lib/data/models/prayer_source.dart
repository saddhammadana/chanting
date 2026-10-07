/// One source entry for prayer content — `meta.sources[]` in `prayers-th.json`.
///
/// Credit and provenance only. A source's licence and permission state are not
/// part of the export: they are kept with the master copy of the prayers, which
/// is where a rights question is answered.
class PrayerSource {
  const PrayerSource({
    this.forFields = const [],
    this.title,
    this.urls = const [],
    this.note,
  });

  /// Fields supported by this source. Values come from [kSourceFields].
  final List<String> forFields;

  /// Book or website title.
  final String? title;

  /// Openable source URLs; multiple URLs are allowed for multi-page sources.
  final List<String> urls;

  /// Notes about omissions, pronunciation adjustments, or source caveats.
  final String? note;

  bool get isEmpty =>
      forFields.isEmpty &&
      (title ?? '').trim().isEmpty &&
      urls.isEmpty &&
      (note ?? '').trim().isEmpty;

  /// Accept both structured objects and legacy strings.
  ///
  /// Legacy strings become [note] so unresolved prose is not promoted to a title.
  factory PrayerSource.fromJson(Object? json) => switch (json) {
    final String s => PrayerSource(note: s),
    final Map<String, dynamic> m => PrayerSource(
      forFields: [
        for (final e in (m['for'] as List<dynamic>? ?? const []))
          if (e is String && e.trim().isNotEmpty) e,
      ],
      title: _str(m['title']),
      urls: _strings(m['urls'] ?? m['url']),
      note: _str(m['note']),
    ),
    _ => const PrayerSource(),
  };

  static String? _str(Object? v) =>
      (v is String && v.trim().isNotEmpty) ? v : null;

  static List<String> _strings(Object? json) => switch (json) {
    final String s when s.trim().isNotEmpty => [s],
    final List<dynamic> l => [
      for (final e in l)
        if (e is String && e.trim().isNotEmpty) e.trim(),
    ],
    _ => const [],
  };

  /// Key order follows docs/content/prayer-schema.md. Empty values are omitted.
  Map<String, dynamic> toJson() => {
    if (forFields.isNotEmpty) 'for': List<String>.from(forFields),
    if (title != null) 'title': title,
    if (urls.isNotEmpty) 'urls': List<String>.from(urls),
    if (note != null) 'note': note,
  };

  PrayerSource copyWith({
    List<String>? forFields,
    String? title,
    List<String>? urls,
    String? note,
  }) => PrayerSource(
    forFields: forFields ?? this.forFields,
    title: title ?? this.title,
    urls: urls ?? this.urls,
    note: note ?? this.note,
  );
}

/// Human-readable one-line summary for compare views and compact UI.
///
/// This is not the JSON storage shape; see [PrayerSource.toJson].
String sourceSummary(PrayerSource s) => [
  if (s.forFields.isNotEmpty) '[${s.forFields.join('/')}]',
  ?s.title,
  ...s.urls,
  ?s.note,
].join(' ');

/// Allowed `for` values. These are line field names, not display labels.
const kSourceFields = {'text', 'roman', 'translation'};

/// Parse `meta.sources` from the file.
///
/// Accepts structured sources and legacy `meta.source` strings.
List<PrayerSource> parseSources(Object? json) {
  final list = switch (json) {
    final String s when s.trim().isNotEmpty => [PrayerSource(note: s)],
    final List<dynamic> l => [
      for (final e in l)
        PrayerSource.fromJson(e is Map ? e.cast<String, dynamic>() : e),
    ],
    final Map<String, dynamic> m => [PrayerSource.fromJson(m)],
    _ => const <PrayerSource>[],
  };
  return [
    for (final s in list)
      if (!s.isEmpty) s,
  ];
}
