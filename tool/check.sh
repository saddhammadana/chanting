#!/bin/sh
# Everything that has to pass before a commit, in the order CI runs it, so one
# command covers what used to be four copied out of CONTRIBUTING.md.
#
# Usage: tool/check.sh [--coverage]
# --coverage runs the tests with coverage and holds it to the project minimum;
# plain `flutter test` is faster for a local loop.
set -e

# Coverage floor. Well under what the suite reaches today (see the number the
# summary prints), so an ordinary change cannot trip it, while a sizeable
# untested feature does.
COVERAGE_MIN=85

if command -v ruby >/dev/null 2>&1; then
  ruby tool/check_docs_links.rb
else
  # The Flutter CI image has no Ruby; its own `docs_links` job covers this.
  echo 'check.sh: no ruby, skipping the docs link check'
fi

# Formatting is checked rather than applied, so pull requests carry no
# whitespace-only diffs.
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze

if [ "$1" = '--coverage' ]; then
  flutter test --coverage
  sh tool/coverage_summary.sh coverage/lcov.info "$COVERAGE_MIN"
else
  flutter test
fi
