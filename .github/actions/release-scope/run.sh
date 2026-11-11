#!/usr/bin/env bash
# Fails unless every merged pull request into BASE that is still labelled
# pending was merged at SHA or before it. release-please, which runs next,
# releases every such pull request at the head of BASE, so an approval of
# this run would also release one merged after SHA. A pull request merged in
# the seconds between this step and release-please is not caught; only
# release-please itself could close that gap.
# shellcheck source-path=SCRIPTDIR
set -euo pipefail
shopt -s inherit_errexit
: "${SHELL_LIB:?}"
: "${REPO:?}" "${BASE:?}" "${SHA:?}"
lib=$(dirname "$0")/../lib
# shellcheck source=../lib/github/commits.sh
source "$lib/github/commits.sh"
# shellcheck source=../lib/github/pulls.sh
source "$lib/github/pulls.sh"
# shellcheck source=/dev/null
source "$SHELL_LIB/report.sh"

# How SHA relates to a merge commit that it contains, from compare_status.
readonly CONTAINS_COMMIT='^(ahead|identical)$'

# check_merged_by_sha PR: report PR unless SHA is its merge commit or descends
# from it.
check_merged_by_sha() {
  local pr=$1 commit relation=identical number
  commit=$(jq -r .merge_commit_sha <<<"$pr")
  if [[ $commit != "$SHA" ]]; then relation=$(compare_status "$commit" "$SHA"); fi
  [[ $relation =~ $CONTAINS_COMMIT ]] && return 0
  number=$(jq -r .number <<<"$pr")
  problem "#$number is labelled $PENDING_LABEL and was merged as $commit, which $SHA does not contain, so release-please would release it in this run; the run of $commit releases it"
}

prs=$(pending_release_prs "$BASE")
while IFS= read -r pr; do
  [[ -n $pr ]] || continue
  check_merged_by_sha "$pr"
done <<<"$prs"
flush
if has_problems; then exit 1; fi
summary "every pending release pull request was merged at or before $SHA"
