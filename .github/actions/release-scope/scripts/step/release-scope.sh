#!/usr/bin/env bash
# Fails unless every merged pull request into BASE that is still labelled
# pending was merged at SHA or before it, and, when one is pending, CONFIG and
# MANIFEST at the head of BASE are those at SHA, which the preflight checked.
# release-please, which runs next, reads all of them at the head of BASE, so
# an approval of this run would also release what was merged after SHA. A
# push in the seconds between this step and release-please is not caught;
# only release-please itself could close that gap.
# shellcheck source-path=SCRIPTDIR
set -euo pipefail
: "${SHELL_LIB:?}"
: "${REPO:?}" "${BASE:?}" "${SHA:?}" "${CONFIG:?}" "${MANIFEST:?}"
# The tools of the runner, LC_ALL=C and inherit_errexit.
# shellcheck source=/dev/null
source "${SHELL_LIB}/env.sh"
step_environment
# From $0, which no variable of the job can set (ADR-0001).
lib=${0%/*}/../../../lib
# shellcheck source=../../../lib/github/commits.sh
source "${lib}/github/commits.sh"
# shellcheck source=../../../lib/github/files.sh
source "${lib}/github/files.sh"
# shellcheck source=../../../lib/github/pulls.sh
source "${lib}/github/pulls.sh"
# shellcheck source=/dev/null
source "${SHELL_LIB}/report.sh"

# How SHA relates to a merge commit that it contains, from compare_status.
readonly CONTAINS_COMMIT='^(ahead|identical)$'

# check_merged_by_sha PR: report PR unless SHA is its merge commit or descends
# from it.
check_merged_by_sha() {
  local pr=$1 commit relation=identical number
  commit=$(jq -r .merge_commit_sha <<<"${pr}")
  if [[ ${commit} != "${SHA}" ]]; then relation=$(compare_status "${commit}" "${SHA}"); fi
  [[ ${relation} =~ ${CONTAINS_COMMIT} ]] && return 0
  number=$(jq -r .number <<<"${pr}")
  problem "#${number} is labelled ${PENDING_LABEL} and was merged as ${commit}, which ${SHA} does not contain, so release-please would release it in this run; the run of ${commit} releases it"
}

# branch_head: print the commit at the head of BASE.
branch_head() {
  api_get "repos/${REPO}/git/ref/heads/${BASE}" | jq -r .object.sha
}

# check_same_file FILE HEAD: report FILE unless it is the same at HEAD as at
# SHA.
check_same_file() {
  local file=$1 head=$2 at_sha at_head
  at_sha=$(required_file "${file}" "${SHA}")
  at_head=$(required_file "${file}" "${head}")
  [[ ${at_head} == "${at_sha}" ]] && return 0
  problem "${file} at ${head}, the head of ${BASE}, is not the one at ${SHA}, where it was checked; rerun the run of ${head} to take the release over" "${file}"
}

# check_config_at_head: report CONFIG and MANIFEST unless they are the same at
# the head of BASE as at SHA.
check_config_at_head() {
  local head
  head=$(branch_head)
  [[ ${head} != "${SHA}" ]] || return 0
  check_same_file "${CONFIG}" "${head}"
  check_same_file "${MANIFEST}" "${head}"
}

prs=$(pending_release_prs "${BASE}")
if [[ -z ${prs} ]]; then
  summary "nothing pending: release-please releases nothing"
  exit 0
fi
while IFS= read -r pr; do
  check_merged_by_sha "${pr}"
done <<<"${prs}"
check_config_at_head
flush
if has_problems; then exit 1; fi
summary "every pending release pull request was merged at or before ${SHA}," \
  "and the configuration and the manifest at the head of ${BASE} are those at ${SHA}"
