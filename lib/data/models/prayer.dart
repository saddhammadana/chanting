import 'prayer_part.dart';
import 'prayer_source.dart';
import 'verification_status.dart';

export 'prayer_part.dart'
    show
        PrayerLine,
        PrayerPart,
        PrayerPartType,
        LocalizedText,
        localizedFor,
        kContentLanguages,
        kDefaultContentLanguage;
export 'prayer_source.dart'
    show PrayerSource, kSourceFields, parseSources, sourceSummary;
export 'verification_status.dart' show VerificationState, VerificationStatus;

/// Allowed values for `Prayer.type`.
const kPrayerTypes = {
  'paritta',
  'sutta',
  'gatha',
  'patha',
  'gatha-patha',
  'chant',
};

/// Separator used by the editor to store string-array fields in one controller.
const kListFieldSeparator = '; ';

/// Split a form field back into an array, trimming and dropping empty members.
List<String> splitListField(String? value) => [
  for (final e in (value ?? '').split(';'))
    if (e.trim().isNotEmpty) e.trim(),
];

/// Read string-array fields, including legacy strings and `{ref: ...}` objects.
List<String> parseStringList(Object? json) => switch (json) {
  final String s when s.trim().isNotEmpty => [s],
  final List<dynamic> l => [
    for (final e in l)
      if (e is String && e.trim().isNotEmpty)
        e
      else if (e is Map && e['ref'] is String)
        e['ref'] as String,
  ],
  _ => const [],
};

/// One prayer. A single class acts as both DTO and entity.
///
/// The model accepts both legacy flat records and structured `sections` records.
/// See `docs/architecture/content-model.md` for the storage rationale.
class Prayer {
  final String id;
  final String title;

  /// Language this instance was read as.
  final String languageCode;

  /// Prayer type slug.
  final String? type;

  /// Structured content; null means this prayer is still legacy flat shape.
  final List<PrayerPart>? parts;

  /// Whether metadata was read from nested `meta`. Used only to preserve write shape.
  final bool metaNested;

  /// Main chant text for rendering, search, copy, preview, and block counting.
  String get text => _flatText ?? _joinParts(_lineText);

  /// Raw legacy flat text; null for structured prayers computed from [parts].
  final String? _flatText;

  /// Romanized Pali, shared across all language editions.
  String? get paliText {
    if (_flatPaliText != null || parts == null) return _flatPaliText;
    final joined = _joinParts((l) => l.roman);
    return joined.trim().isEmpty ? null : joined;
  }

  final String? _flatPaliText;

  /// Human verification status for Pali, translation, and references.
  /// AI tools must not mark content verified; see docs/content/verification.md.
  final VerificationStatus verification;

  /// Whether Pali can be trusted. `needsRecheck` counts as not verified.
  bool get paliVerified => VerificationStatus.isVerified(verification.pali);

  /// Meaning for [languageCode].
  String? get meaning {
    if (_flatMeaning != null || parts == null) return _flatMeaning;
    final joined = _joinParts((l) => localizedFor(l.translation, languageCode));
    return joined.trim().isEmpty ? null : joined;
  }

  final String? _flatMeaning;

  /// Prayer sublabel, metadata only.
  final String? subcategory;

  /// Estimated chanting duration in minutes.
  final int? durationMinutes;

  /// Short occasion tags. Prose explanation belongs in [description].
  final List<String> occasions;

  /// Prose description: summary, origin, or usage notes.
  final String? description;

  /// Author, when known.
  final String? author;

  /// Traceable content sources, one object per source.
  final List<PrayerSource> sources;

  /// Canonical scripture references. Multiple values are allowed.
  final List<String> tipitakaReferences;

  /// Notes attached to scripture references.
  final String? tipitakaNote;

  /// Tradition or lineage label.
  final String? tradition;

  /// Human reviewer. AI must never invent this name.
  final String? reviewedBy;

  /// Whether this prayer uses the structured shape.
  bool get isStructured => parts != null;

  /// Whether Pali exists and differs from [text], so it deserves a separate chip.
  bool get hasDistinctPali => paliText != null && paliText != text;

  const Prayer({
    required this.id,
    required this.title,
    String? text,
    this.parts,
    String? paliText,
    this.verification = VerificationStatus.none,
    String? meaning,
    this.languageCode = kDefaultContentLanguage,
    this.metaNested = false,
    this.type,
    this.subcategory,
    this.durationMinutes,
    this.occasions = const [],
    this.description,
    this.author,
    this.sources = const [],
    this.tipitakaReferences = const [],
    this.tipitakaNote,
    this.tradition,
    this.reviewedBy,
  }) : assert(
         text != null || parts != null,
         'บทต้องมีเนื้อหา: `text` (รูปแบบเดิม) หรือ `parts` (รูปแบบใหม่)',
       ),
       _flatText = text,
       _flatPaliText = paliText,
       _flatMeaning = meaning;

  /// One line for [languageCode].
  String? _lineText(PrayerLine l) =>
      languageCode == kDefaultContentLanguage ? l.text : (l.roman ?? l.text);

  /// Join values returned by [pick] into a legacy flat string.
  String _joinParts(String? Function(PrayerLine) pick) {
    final buf = <String>[];
    for (final part in parts!) {
      final lines = <String>[];
      for (final l in part.lines) {
        final v = pick(l);
        if (v != null && v.trim().isNotEmpty) lines.add(v);
      }
      buf.add(lines.join('\n'));
    }
    return buf.join('\n\n');
  }

  /// Metadata fields moved into `meta` in the structured shape.
  static const metaKeys = {
    'subcategory',
    'durationMinutes',
    'occasions',
    'description',
    'author',
    'sources',
    'tipitakaReferences',
    'tipitakaNote',
    'tradition',
  };

  /// Legacy singular keys for fields that are now arrays. Reading still accepts
  /// them, but writing does not emit them and data tests keep them out of files.
  static const legacyMetaKeys = {
    'occasion',
    'source',
    'tipitakaReference',
    'prayerType',
    'chantDurationMinutes',
  };

  factory Prayer.fromJson(
    Map<String, dynamic> json, {
    String languageCode = kDefaultContentLanguage,
  }) {
    // Accept both `meta: {...}` and flat fields; `meta` wins.
    final meta = (json['meta'] as Map?)?.cast<String, dynamic>();
    Object? metaField(String key) => meta?[key] ?? json[key];

    final rawParts = json['sections'] as List<dynamic>?;
    return Prayer(
      id: json['id'] as String,
      title: json['title'] as String,
      type: json['type'] as String?,
      languageCode: languageCode,
      metaNested: meta != null,
      text: json['text'] as String?,
      parts: rawParts == null
          ? null
          : [
              for (final e in rawParts)
                PrayerPart.fromJson((e as Map).cast<String, dynamic>()),
            ],
      paliText: json['paliText'] as String?,
      // Missing key means unverified; legacy `paliVerified` is still accepted.
      verification: VerificationStatus.fromJson(
        json['verificationStatus'],
        legacyPaliVerified: json['paliVerified'],
      ),
      meaning: json['meaning'] as String?,
      subcategory: metaField('subcategory') as String?,
      durationMinutes:
          (metaField('durationMinutes') ?? metaField('chantDurationMinutes'))
              as int?,
      occasions: parseStringList(
        metaField('occasions') ?? metaField('occasion'),
      ),
      description: metaField('description') as String?,
      author: metaField('author') as String?,
      sources: parseSources(metaField('sources') ?? metaField('source')),
      tipitakaReferences: parseStringList(
        metaField('tipitakaReferences') ?? metaField('tipitakaReference'),
      ),
      tipitakaNote: metaField('tipitakaNote') as String?,
      tradition: metaField('tradition') as String?,
      reviewedBy: json['reviewedBy'] as String?,
    );
  }

  /// Write back in the same shape that was read; see [metaNested]/[isStructured].
  Map<String, dynamic> toJson() {
    final meta = <String, dynamic>{
      'subcategory': subcategory,
      'durationMinutes': durationMinutes,
      'occasions': occasions.isEmpty ? null : List<String>.from(occasions),
      'description': description,
      'author': author,
      'sources': sources.isEmpty ? null : [for (final s in sources) s.toJson()],
      'tipitakaReferences': tipitakaReferences.isEmpty
          ? null
          : List<String>.from(tipitakaReferences),
      'tipitakaNote': tipitakaNote,
      'tradition': tradition,
    };
    // Key order follows the spec, not the alphabet.
    return {
      'id': id,
      'title': title,
      if (type != null) 'type': type,
      // Structured content derives text/paliText/meaning from sections.
      if (parts != null)
        'sections': [for (final p in parts!) p.toJson()]
      else ...{
        'text': _flatText,
        'paliText': _flatPaliText,
        'meaning': _flatMeaning,
      },
      'verificationStatus': verification.toJson(),
      if (metaNested) 'meta': meta else ...meta,
      'reviewedBy': reviewedBy,
    };
  }

  /// Keys that belong only in the source file and cannot be overridden by overlays.
  static const sourceOnlyKeys = {
    'id',
    'type',
    'paliText',
    'paliVerified',
    'verificationStatus',
    'reviewedBy',
    'sections',
  };

  /// Keys structured prayers must not store in source files.
  static const derivedContentKeys = {'text', 'paliText', 'meaning'};

  /// This prayer as seen by one language edition, with [overlay] applied.
  Prayer withOverlay(Map<String, dynamic>? overlay) {
    if (overlay == null || overlay.isEmpty) return this;
    final merged = toJson();
    for (final e in overlay.entries) {
      if (sourceOnlyKeys.contains(e.key)) continue;
      // Preserve nested metadata shape when merging translated values.
      if (metaNested && metaKeys.contains(e.key)) {
        (merged['meta'] as Map<String, dynamic>)[e.key] = e.value;
        continue;
      }
      merged[e.key] = e.value;
    }
    return Prayer.fromJson(merged, languageCode: languageCode);
  }

  /// This prayer as seen by edition [lang].
  Prayer forLanguage(String lang) =>
      lang == languageCode ? this : copyWith(languageCode: lang);

  Prayer copyWith({
    String? id,
    String? title,
    String? text,
    List<PrayerPart>? parts,
    String? paliText,
    VerificationStatus? verification,
    String? meaning,
    String? languageCode,
    bool? metaNested,
    String? type,
    String? subcategory,
    int? durationMinutes,
    List<String>? occasions,
    String? description,
    String? author,
    List<PrayerSource>? sources,
    List<String>? tipitakaReferences,
    String? tipitakaNote,
    String? tradition,
    String? reviewedBy,
  }) {
    // Flat strings can hold current-edition overlay values for structured records.
    final nextParts = parts ?? this.parts;
    return Prayer(
      id: id ?? this.id,
      title: title ?? this.title,
      text: text ?? _flatText,
      parts: nextParts,
      paliText: paliText ?? _flatPaliText,
      verification: verification ?? this.verification,
      meaning: meaning ?? _flatMeaning,
      languageCode: languageCode ?? this.languageCode,
      metaNested: metaNested ?? this.metaNested,
      type: type ?? this.type,
      subcategory: subcategory ?? this.subcategory,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      occasions: occasions ?? this.occasions,
      description: description ?? this.description,
      author: author ?? this.author,
      sources: sources ?? this.sources,
      tipitakaReferences: tipitakaReferences ?? this.tipitakaReferences,
      tipitakaNote: tipitakaNote ?? this.tipitakaNote,
      tradition: tradition ?? this.tradition,
      reviewedBy: reviewedBy ?? this.reviewedBy,
    );
  }
}
