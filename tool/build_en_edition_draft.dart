// Builds a full draft content edition for one language from prayers-th.json.
//
// Usage: dart run tool/build_en_edition_draft.dart [lang]   (default: en)
// Output: build/prayers-<lang>.json.draft + build/sections-<lang>.json.draft
//
// Drafts go to `build/`, not `assets/data/`. pubspec.yaml declares the whole
// assets/data folder, so placing drafts there would bundle dead data into the
// app. build/ is not shipped, can be regenerated, and stays out of git.
//
// Format note, August 2026: every content language is a full source-shaped
// edition. Drafts therefore keep the complete record/category structure instead
// of depending on Thai as a base file.
//
// Why a new language cannot be enabled immediately: a non-Thai edition makes
// Romanized Pali the primary chant text, but most Pali is still unverified. Do
// not ship a foreign-language edition until a human has verified what users will
// chant.
//
// Real enablement steps, done by the owner/human reviewer:
//   1. Verify Pali against the accepted book/source edition.
//   2. Add real translated meaning text and required attribution.
//   3. Move the draft to assets/data/prayers-<lang>.json and add the language to
//      kContentLanguages. prayer_editions_test then enforces matching ids/order.
library;

import 'dart:convert';
import 'dart:io';

/// English section titles. These are labels, not canonical chant text.
/// Keys are source section ids.
const _sectionTitleEn = {
  'tham-wat-chao': 'Morning Chanting',
  'tham-wat-yen': 'Evening Chanting',
  'bot-thuapai': 'General',
  'bot-suat-phiset': 'Special Chants',
  'bot-anumothana': 'Anumodanā',
  'charoen-phra-phuttha-mon': 'Blessings (Paritta)',
  'bot-phicharana-phikkhu-samanen': 'Reflections for Monks & Novices',
  'bot-tham-lang-patimokkha': 'After the Pāṭimokkha',
  'bot-tham-khamson': 'Dhamma Teachings',
};

/// Whether this record's Pali has been verified. Accepts the old
/// `paliVerified: true` shape for migration-era files.
bool _paliVerified(Map<String, dynamic> e) =>
    (e['verificationStatus'] as Map?)?['pali'] == 'verified' ||
    e['paliVerified'] == true;

void main(List<String> args) {
  final lang = args.isEmpty ? 'en' : args.first;

  final source =
      (jsonDecode(File('assets/data/prayers-th.json').readAsStringSync())
              as List<dynamic>)
          .cast<Map<String, dynamic>>();

  final sections =
      (jsonDecode(File('assets/data/sections-th.json').readAsStringSync())
              as List<dynamic>)
          .cast<Map<String, dynamic>>();

  final sectionEdition = <Map<String, dynamic>>[];
  for (final sec in sections) {
    final title = _sectionTitleEn[sec['id']];
    if (title == null) {
      stderr.writeln(
        'Missing section translation for "${sec['id']}". Add it to _sectionTitleEn.',
      );
      exit(1);
    }
    sectionEdition.add({...sec, 'title': title});
  }

  final edition = <Map<String, dynamic>>[];
  for (final p in source) {
    final copy = jsonDecode(jsonEncode(p)) as Map<String, dynamic>;
    copy['title'] = '[${lang.toUpperCase()}] ${p['title']}';
    for (final section in (copy['sections'] as List<dynamic>? ?? const [])) {
      for (final line
          in ((section as Map)['lines'] as List<dynamic>? ?? const [])) {
        final lineMap = line as Map<String, dynamic>;
        final roman = lineMap['roman'];
        if (roman is String && roman.trim().isNotEmpty) {
          lineMap['text'] = roman;
        }
      }
    }
    edition.add(copy);
  }

  const encoder = JsonEncoder.withIndent('  ');
  Directory('build').createSync(recursive: true);
  File(
    'build/prayers-$lang.json.draft',
  ).writeAsStringSync('${encoder.convert(edition)}\n');
  File(
    'build/sections-$lang.json.draft',
  ).writeAsStringSync('${encoder.convert(sectionEdition)}\n');

  final verified = source.where(_paliVerified).length;
  stdout
    ..writeln(
      'Wrote: build/prayers-$lang.json.draft (${edition.length} prayers)',
    )
    ..writeln(
      'Wrote: build/sections-$lang.json.draft '
      '(${sectionEdition.length} sections)',
    )
    ..writeln(
      'Status: draft only. Not loaded, shipped, or committed from build/.',
    )
    ..writeln('Pali verified: $verified/${source.length}')
    ..writeln(
      'Before enabling: verify Pali, add real translations, move to assets/data/, '
      'and update kContentLanguages.',
    );
}
