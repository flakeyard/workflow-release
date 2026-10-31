#!/usr/bin/env bash
# Unit tests of the scripts in .github/actions, with a stub of gh.
# Usage: tests/run.sh
set -uo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source-path=SCRIPTDIR source=lib.sh
source "$root/tests/lib.sh"

for suite in "$root"/tests/unit/*.sh; do
  # shellcheck source=/dev/null
  source "$suite"
done

echo "passed: $passed, failed: $failed"
((failed == 0))
