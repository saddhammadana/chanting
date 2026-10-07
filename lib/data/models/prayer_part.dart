/// Structured prayer content: parts (`PrayerPart`) and lines (`PrayerLine`).
///
/// Data files call these `"sections"`, while Dart uses `PrayerPart` to avoid
/// colliding with category-level `PrayerSection`. See
/// `docs/architecture/content-model.md`.
library;

/// Languages with their own prayer-content translation, separate from UI locale.
/// Adding a language requires matching data and verified Pali; see docs/internationalization.md.
const kContentLanguages = {'th', 'en'};

/// Source edition: owns ids, Pali, order, section structure, and Thai text.
const kDefaultContentLanguage = 'th';

/// Localizable text in the structured shape: `{"th": ..., "en": ...}`.
///
/// Empty map means the text is absent, unlike `{"th": ""}` which means the line
/// exists but is intentionally blank.
typedef LocalizedText = Map<String, String>;

/// Read [lang] from [text], falling back to the source edition.
String? localizedFor(LocalizedText text, String lang) =>
    text[lang] ?? text[kDefaultContentLanguage];

/// Accept both `"text"` and `{"th": "text"}`. A string counts as source language.
LocalizedText localizedFromJson(Object? json) => switch (json) {
  null => const {},
  final String s => {kDefaultContentLanguage: s},
  final Map<String, dynamic> m => {
    for (final e in m.entries)
      if (e.value is String) e.key: e.value as String,
  },
  _ => const {},
};

/// Serialize [text] to JSON. Empty maps return null so callers omit the key.
/// Source-language-only maps write as compact strings.
Object? localizedToJson(LocalizedText text) {
  if (text.isEmpty) return null;
  if (text.length == 1 && text.containsKey(kDefaultContentLanguage)) {
    return text[kDefaultContentLanguage];
  }
  return Map<String, String>.from(text);
}

/// Part type: what the part does in chanting, not how it looks.
/// Unknown values fall back to [main] so hand-edited files still open.
enum PrayerPartType {
  /// Main chant text; the default and common case.
  main,

  /// Leader prompt spoken by one leader before everyone chants.
  lead,

  /// Congregation response following [lead].
  congregation,

  /// Nidana/preamble section, such as the opening of a sutta.
  nidana,

  /// Verse/metre section, distinct from prose.
  verse,

  /// Repeated refrain, such as the ending repeated after each numbered item.
  refrain,

  /// Non-recited rubric or action instruction.
  rubric,

  /// Closing or dedication at the end of a prayer.
  closing;

  /// Parse a file value. Unknown or missing names return [main].
  static PrayerPartType parse(Object? raw) {
    if (raw is! String) return main;
    for (final t in values) {
      if (t.name == raw) return t;
    }
    return main;
  }
}

/// One prayer line pairing Thai, Romanized Pali, and translation in one unit.
class PrayerLine {
  /// Stable line pointer, unique within one prayer. Do not renumber existing ids.
  final String id;

  /// Chant line in Thai script for the Thai source edition.
  final String text;

  /// Romanized Pali for this line; null means the line has no Pali.
  final String? roman;

  /// Translation per language; see [localizedFor] for source-language fallback.
  final LocalizedText translation;

  const PrayerLine({
    required this.id,
    required this.text,
    this.roman,
    this.translation = const {},
  });

  /// [fallbackId] is used when a file omits `id`; tests report missing real ids.
  factory PrayerLine.fromJson(
    Map<String, dynamic> json, {
    String fallbackId = '',
  }) => PrayerLine(
    id: json['id'] as String? ?? fallbackId,
    text: json['text'] as String? ?? '',
    roman: json['roman'] as String?,
    translation: localizedFromJson(json['translation']),
  );

  /// Omit null/empty keys so data files are not full of `"roman": null`.
  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    if (roman != null && roman!.isNotEmpty) 'roman': roman,
    if (translation.isNotEmpty) 'translation': localizedToJson(translation),
  };

  PrayerLine copyWith({
    String? id,
    String? text,
    String? roman,
    LocalizedText? translation,
  }) => PrayerLine(
    id: id ?? this.id,
    text: text ?? this.text,
    roman: roman ?? this.roman,
    translation: translation ?? this.translation,
  );

  /// Fully blank line, usually a legacy block separator that survived migration.
  bool get isBlank =>
      text.trim().isEmpty &&
      (roman?.trim().isEmpty ?? true) &&
      translation.values.every((v) => v.trim().isEmpty);
}

/// One part of a prayer. The file key is `sections`; see the file header.
class PrayerPart {
  /// Unique **within one prayer**, not globally.
  ///
  /// Unlike `Prayer.id` or `PrayerSection.id`, user prefs do not point to this.
  /// It can change; it is used for widget keys and in-prayer jump targets only.
  final String id;

  final PrayerPartType type;

  /// Optional part heading; short single-part prayers often do not need one.
  final LocalizedText title;

  final List<PrayerLine> lines;

  const PrayerPart({
    required this.id,
    this.type = PrayerPartType.main,
    this.title = const {},
    this.lines = const [],
  });

  factory PrayerPart.fromJson(Map<String, dynamic> json) => PrayerPart(
    id: json['id'] as String? ?? '',
    type: PrayerPartType.parse(json['type']),
    title: localizedFromJson(json['title']),
    lines: [
      for (final (i, l)
          in (json['lines'] as List<dynamic>? ?? const []).indexed)
        PrayerLine.fromJson(
          (l as Map).cast<String, dynamic>(),
          fallbackId: '${json['id'] ?? 'part'}-line-${i + 1}',
        ),
    ],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    if (title.isNotEmpty) 'title': localizedToJson(title),
    'lines': [for (final l in lines) l.toJson()],
  };

  PrayerPart copyWith({
    String? id,
    PrayerPartType? type,
    LocalizedText? title,
    List<PrayerLine>? lines,
  }) => PrayerPart(
    id: id ?? this.id,
    type: type ?? this.type,
    title: title ?? this.title,
    lines: lines ?? this.lines,
  );

  /// Heading for this part in [lang]; null means the part has no heading.
  String? titleFor(String lang) {
    final t = localizedFor(title, lang);
    return (t == null || t.trim().isEmpty) ? null : t;
  }
}
