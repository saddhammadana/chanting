/// Checks a fetched prayer book before the app starts reading from it.
///
/// A bundled book is read by the data tests before it ships. A fetched one is
/// read by nothing but this, so it refuses what would leave a reader with an
/// empty or half-reachable book. See docs/architecture/content-updates.md.
library;

import 'edition_drift.dart';
import 'repositories/prayer_repository.dart';

/// The files one release must carry, by name, for every content language.
List<String> get contentFileNames => [
  for (final lang in kContentLanguages) ...['prayers-$lang', 'sections-$lang'],
];

/// What is wrong with [files] (name → raw JSON). Empty means usable.
List<String> contentProblems(Map<String, String> files) {
  final problems = <String>[];
  final ids = <String, Set<String>>{};
  final sectionIds = <String, Set<String>>{};

  for (final lang in kContentLanguages) {
    try {
      final prayers = PrayerRepository.decodePrayers(
        files['prayers-$lang']!,
        languageCode: lang,
      );
      final sections = PrayerRepository.decodeSections(
        files['sections-$lang']!,
      );
      if (prayers.isEmpty) problems.add('prayers-$lang is empty');
      if (sections.isEmpty) problems.add('sections-$lang is empty');

      ids[lang] = {for (final p in prayers) p.id};
      sectionIds[lang] = {for (final s in sections) s.id};
      if (ids[lang]!.length != prayers.length) {
        problems.add('prayers-$lang repeats an id');
      }
      // A prayer in no section is reachable only through search.
      final listed = {for (final s in sections) ...s.prayerIds};
      final orphans = ids[lang]!.difference(listed);
      if (orphans.isNotEmpty) {
        problems.add('prayers-$lang has prayers in no section: $orphans');
      }
    } catch (error) {
      problems.add('$lang edition cannot be read: $error');
    }
  }
  if (problems.isNotEmpty) return problems;

  for (final lang in kContentLanguages) {
    if (lang == kDefaultContentLanguage) continue;
    problems.addAll(
      editionDrift(
        otherLang: lang,
        sourceIds: ids[kDefaultContentLanguage]!,
        overlayIds: ids[lang]!,
        sourceSectionIds: sectionIds[kDefaultContentLanguage],
        overlaySectionIds: sectionIds[lang],
      ),
    );
  }
  return problems;
}
