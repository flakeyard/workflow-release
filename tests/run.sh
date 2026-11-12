#!/usr/bin/env bash
# Unit tests of the scripts in .github/actions, with the harness and the stubs
# of action-shell-lib, and static tests of the workflows. The suites in tests/unit mirror the actions: one file
# per action, or a directory with one file per script when an action has
# several; tests/unit/workflows has one file per workflow and needs yq.
# Usage: tests/run.sh
# shellcheck source-path=SCRIPTDIR
set -uo pipefail
shopt -s globstar

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=lib/shell-lib.sh
source "$root/tests/lib/shell-lib.sh"
# The harness of the library; not its public API, used only by tests.
# shellcheck source=/dev/null
source "$SHELL_LIB/internal/testing/case.sh"
# shellcheck source=/dev/null
source "$SHELL_LIB/internal/testing/checks.sh"
# shellcheck source=/dev/null
source "$SHELL_LIB/internal/testing/fixtures.sh"
# shellcheck source=/dev/null
source "$SHELL_LIB/internal/testing/yaml.sh"
# shellcheck source=/dev/null
source "$SHELL_LIB/internal/testing/workflow.sh"
# shellcheck source=/dev/null
source "$SHELL_LIB/internal/testing/consumer/action.sh"
# shellcheck source=/dev/null
source "$SHELL_LIB/internal/testing/consumer/library.sh"
# shellcheck source=/dev/null
source "$SHELL_LIB/internal/testing/consumer/step.sh"
# The scripts and the YAML files are paths in the repository.
# shellcheck disable=SC2034 # read by internal/testing
code_root=$root
# shellcheck source=lib/case.sh
source "$root/tests/lib/case.sh"
# shellcheck source=lib/checks.sh
source "$root/tests/lib/checks.sh"
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

for suite in "$root"/tests/unit/**/*.sh; do
  # shellcheck source=/dev/null
  source "$suite"
done

conclude
