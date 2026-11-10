#!/usr/bin/env bash
# Unit tests of the scripts in .github/actions, with a stub of gh, and static
# tests of the workflows. The suites in tests/unit mirror the actions: one file
# per action, or a directory with one file per script when an action has
# several; tests/unit/workflows has one file per workflow and needs yq.
# Usage: tests/run.sh
# shellcheck source-path=SCRIPTDIR
set -uo pipefail
shopt -s globstar

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=lib/shell-lib.sh
source "$root/tests/lib/shell-lib.sh"
# shellcheck source=lib/case.sh
source "$root/tests/lib/case.sh"
# shellcheck source=lib/checks.sh
source "$root/tests/lib/checks.sh"
# The fixtures of the library; not its public API, used only by tests.
# shellcheck source=/dev/null
source "$library/internal/testing/fixtures.sh"
# shellcheck source=lib/fixtures/late.sh
source "$root/tests/lib/fixtures/late.sh"
# shellcheck source=lib/fixtures/manifest.sh
source "$root/tests/lib/fixtures/manifest.sh"
# shellcheck source=lib/fixtures/tags.sh
source "$root/tests/lib/fixtures/tags.sh"
# shellcheck source=lib/fixtures/releases.sh
source "$root/tests/lib/fixtures/releases.sh"
# shellcheck source=lib/fixtures/pulls.sh
source "$root/tests/lib/fixtures/pulls.sh"
# shellcheck source=lib/fixtures/runs.sh
source "$root/tests/lib/fixtures/runs.sh"
# shellcheck source=lib/workflow.sh
source "$root/tests/lib/workflow.sh"

for suite in "$root"/tests/unit/**/*.sh; do
  # shellcheck source=/dev/null
  source "$suite"
done

echo "passed: $passed, failed: $failed"
((failed == 0))
