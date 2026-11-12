#!/usr/bin/env bash
# Relabels merged release pull requests into BASE that are still pending once
# their release exists.
# shellcheck source-path=SCRIPTDIR
set -euo pipefail
: "${SHELL_LIB:?}"
: "${REPO:?}" "${BASE:?}" "${MANIFEST:?}"
# The tools of the runner, LC_ALL=C and inherit_errexit.
# shellcheck source=/dev/null
source "$SHELL_LIB/env.sh"
step_environment
# From $0, which no variable of the job can set (ADR-0001).
lib=${0%/*}/../../../lib
# shellcheck source=../../../lib/github/optional.sh
source "$lib/github/optional.sh"
# shellcheck source=../../../lib/github/pulls.sh
source "$lib/github/pulls.sh"
# shellcheck source=../../../lib/github/releases.sh
source "$lib/github/releases.sh"
# shellcheck source=../../../lib/manifest.sh
source "$lib/manifest.sh"
# shellcheck source=/dev/null
source "$SHELL_LIB/report.sh"

RELEASE_HEAD=$(release_head "$BASE")
readonly RELEASE_HEAD

# is_release_pr PR: PR comes from release-please's branch for BASE. The plan
# warns about other pull requests labelled pending.
is_release_pr() {
  local pr=$1
  [[ $(jq -r .head.ref <<<"$pr") == "$RELEASE_HEAD" ]]
}

# reconcile PR: relabel PR as tagged once its release exists. The released
# version is the manifest's at the merge commit; without a root version X.Y.Z
# there, PR is left for the plan to warn about.
reconcile() {
  local pr=$1 number merge_commit version tag release
  is_release_pr "$pr" || return 0
  number=$(jq -r .number <<<"$pr")
  merge_commit=$(jq -r .merge_commit_sha <<<"$pr")
  version=$(find_release_version "$merge_commit")
  [[ -n $version ]] || return 0
  tag=v$version
  release=$(published_release "$tag")
  [[ -n $release ]] || return 0
  mark_tagged "$number" "$tag"
}

# mark_tagged NUMBER TAG: relabel pull request NUMBER from pending to tagged.
# The new label is added first: a failure in between leaves the pull request
# pending, so the next run retries.
mark_tagged() {
  local number=$1 tag=$2
  gh api --silent -X POST "repos/$REPO/issues/$number/labels" -f "labels[]=autorelease: tagged"
  api_delete_if_exists "repos/$REPO/issues/$number/labels/$PENDING_LABEL_URL"
  summary "marked #$number as tagged: $tag exists"
}

prs=$(pending_release_prs "$BASE")
while IFS= read -r pr; do
  [[ -n $pr ]] || continue
  reconcile "$pr"
done <<<"$prs"
