/// Checks language editions for ids that no longer exist in source files.
///
/// See docs/architecture/content-model.md for the full-edition model.
library;

/// Compares the [otherLang] edition against ids that exist in the source files.
///
/// Returns an empty list when the edition is valid.
List<String> editionDrift({
  required String otherLang,
  required Set<String> sourceIds,
  required Set<String> overlayIds,
  Set<String>? sourceSectionIds,
  Set<String>? overlaySectionIds,
}) {
  final problems = <String>[];

  final unknown = overlayIds.difference(sourceIds);
  if (unknown.isNotEmpty) {
    problems.add(
      'prayers-$otherLang.json contains ids that do not exist in the source: '
      '$unknown. Those records will never be used; the id may be mistyped '
      'or the prayer may have been removed from prayers-th.json.',
    );
  }

  if (sourceSectionIds != null && overlaySectionIds != null) {
    final unknownSections = overlaySectionIds.difference(sourceSectionIds);
    if (unknownSections.isNotEmpty) {
      problems.add(
        'sections-$otherLang.json names sections that do not exist in the '
        'source: $unknownSections. Those sections will never be used.',
      );
    }
  }

  return problems;
}
