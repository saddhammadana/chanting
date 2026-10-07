import 'package:flutter/material.dart';

import '../../prayer_list/prayer_list_controller.dart';

/// [text] split so each occurrence of [query] is bold on [fill], matched
/// through [foldForSearch] exactly as the choose tab filters. Folding maps
/// every character to one character, so indices carry over to [text].
List<TextSpan> markedSpans(
  String text,
  String query,
  TextStyle? base,
  Color fill,
) {
  if (query.isEmpty) return [TextSpan(text: text, style: base)];
  final haystack = foldForSearch(text);
  final needle = foldForSearch(query);
  if (haystack.length != text.length) {
    return [TextSpan(text: text, style: base)];
  }
  final marked = base?.copyWith(
    backgroundColor: fill,
    fontWeight: FontWeight.w800,
  );
  final spans = <TextSpan>[];
  var start = 0;
  while (true) {
    final index = haystack.indexOf(needle, start);
    if (index < 0) break;
    if (index > start) {
      spans.add(TextSpan(text: text.substring(start, index), style: base));
    }
    spans.add(
      TextSpan(
        text: text.substring(index, index + needle.length),
        style: marked,
      ),
    );
    start = index + needle.length;
  }
  if (start < text.length) {
    spans.add(TextSpan(text: text.substring(start), style: base));
  }
  return spans;
}
