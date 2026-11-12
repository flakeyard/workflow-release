#!/usr/bin/env bash
# Pauses before the retry of the pull request pass of release-please.
set -euo pipefail
: "${SHELL_LIB:?}"
# The tools of the runner, LC_ALL=C and inherit_errexit.
# shellcheck source=/dev/null
source "$SHELL_LIB/env.sh"
step_environment

readonly RETRY_PAUSE_SECONDS=30

sleep "$RETRY_PAUSE_SECONDS"
