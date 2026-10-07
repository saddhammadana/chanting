#!/bin/sh
# Prints total line coverage from coverage/lcov.info, leaving out the
# generated localization files. CI adds the printed line to the job summary.
#
# Usage: coverage_summary.sh [lcov file] [minimum percentage]
# With a minimum, the script exits non-zero when coverage falls under it, so a
# pull request that drops coverage fails instead of only reporting a number.
set -e
awk -F: -v min="${2:-0}" '
  /^SF:/ { skip = ($2 ~ /lib\/l10n\/app_localizations/) }
  /^LF:/ { if (!skip) found += $2 }
  /^LH:/ { if (!skip) hit += $2 }
  END {
    if (found == 0) { print "No coverage data"; exit 1 }
    pct = hit * 100 / found
    printf "Line coverage: %.1f%% (%d of %d lines)\n", pct, hit, found
    if (min > 0 && pct + 0.05 < min) {
      printf "Below the %.1f%% minimum this project keeps.\n", min
      exit 1
    }
  }
' "${1:-coverage/lcov.info}"
