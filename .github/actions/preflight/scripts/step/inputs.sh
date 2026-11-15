#!/usr/bin/env bash
# Fails unless the run is a push to a release branch and, when KEY_VISIBLE is
# true, the App inputs are complete. A push to release/v0 is skipped: releases
# 0.y.z are made only on the default branch. Writes skip=true to GITHUB_OUTPUT
# then.
# shellcheck source-path=SCRIPTDIR
set -euo pipefail
: "${SHELL_LIB:?}"
: "${CLIENT_ID?}" "${HAS_KEY:?}" "${KEY_VISIBLE:?}" "${EVENT:?}" "${REF:?}"
# The tools of the runner, LC_ALL=C and inherit_errexit.
# shellcheck source=/dev/null
source "${SHELL_LIB}/env.sh"
step_environment
# From $0, which no variable of the job can set (ADR-0001).
lib=${0%/*}/../../../lib
# shellcheck source=../../../lib/app-key.sh
source "${lib}/app-key.sh"
# shellcheck source=/dev/null
source "${SHELL_LIB}/report.sh"

readonly MAINTENANCE_BRANCH='^refs/heads/release/v[1-9][0-9]*$'
readonly ZERO_BRANCH=refs/heads/release/v0

# is_zero_branch: REF is release/v0, which has no releases of its own.
is_zero_branch() {
  [[ ${REF} == "${ZERO_BRANCH}" && ${REF} != "refs/heads/${DEFAULT_BRANCH}" ]]
}

# is_release_branch: REF is the default branch or release/vN with N >= 1.
is_release_branch() {
  [[ ${REF} == "refs/heads/${DEFAULT_BRANCH}" || ${REF} =~ ${MAINTENANCE_BRANCH} ]]
}

if [[ ${EVENT} != push ]]; then
  fail "the release workflow runs only on push events, not ${EVENT}"
fi
: "${DEFAULT_BRANCH:?}"
if is_zero_branch; then
  notice "releases 0.y.z are made only on ${DEFAULT_BRANCH}; nothing to do on release/v0"
  echo "skip=true" >>"${GITHUB_OUTPUT}"
  exit 0
fi
# An environment secret is visible only in jobs of that environment; the
# token action checks the key there.
if [[ ${KEY_VISIBLE} == true ]]; then check_app_key "${CLIENT_ID}" "${HAS_KEY}"; fi
if ! is_release_branch; then
  fail "releases run only on ${DEFAULT_BRANCH} and release/vN with N >= 1, not ${REF}"
fi
