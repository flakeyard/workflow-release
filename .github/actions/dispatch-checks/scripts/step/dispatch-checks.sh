#!/usr/bin/env bash
# Starts WORKFLOW on the open release pull request into BASE, if there is one.
# shellcheck source-path=SCRIPTDIR
set -euo pipefail
: "${SHELL_LIB:?}"
: "${REPO:?}" "${OWNER:?}" "${BASE:?}" "${WORKFLOW:?}"
# The tools of the runner, LC_ALL=C and inherit_errexit.
# shellcheck source=/dev/null
source "${SHELL_LIB}/env.sh"
step_environment
# From $0, which no variable of the job can set (ADR-0001).
lib=${0%/*}/../../../lib
# shellcheck source=../../../lib/github/pulls.sh
source "${lib}/github/pulls.sh"
# shellcheck source=/dev/null
source "${SHELL_LIB}/report.sh"

head=$(release_head "${BASE}")
number=$(api_get "repos/${REPO}/pulls?state=open&base=${BASE}&head=${OWNER}:${head}" \
  | jq -r '.[0].number // empty')
if [[ -z ${number} ]]; then
  summary "no open release pull request"
  exit 0
fi
gh workflow run "${WORKFLOW}" --repo "${REPO}" --ref "${head}"
summary "started ${WORKFLOW} on #${number} (${head})"
