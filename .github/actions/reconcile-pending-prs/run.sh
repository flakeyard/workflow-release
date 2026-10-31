#!/usr/bin/env bash
# Relabels merged release pull requests into BASE that are still pending.
# shellcheck source-path=SCRIPTDIR
set -euo pipefail
shopt -s inherit_errexit
: "${REPO:?}" "${BASE:?}" "${MANIFEST:?}"
lib=$(dirname "$0")/../lib
# shellcheck source=../lib/github/api.sh
source "$lib/github/api.sh"
# shellcheck source=../lib/github/releases.sh
source "$lib/github/releases.sh"
# shellcheck source=../lib/manifest.sh
source "$lib/manifest.sh"
# shellcheck source=../lib/report.sh
source "$lib/report.sh"

# The label is filtered by the API, so only pending pull requests are listed.
numbers=$(gh api --paginate \
  "repos/$REPO/issues?state=closed&labels=autorelease:%20pending&per_page=100" \
  --jq '.[] | select(.pull_request.merged_at != null) | .number')

for number in $numbers; do
  pr=$(api_get "repos/$REPO/pulls/$number")
  [[ $(jq -r .base.ref <<<"$pr") == "$BASE" ]] || continue
  # The released version is the manifest's at the merge commit.
  merge_commit=$(jq -r .merge_commit_sha <<<"$pr")
  version=$(root_version "$merge_commit")
  tag=v$version
  release=$(published_release "$tag")
  [[ -n $release ]] || continue
  # Add the new label first: a failure in between leaves the pull request
  # pending, so the next run retries.
  gh api --silent -X POST "repos/$REPO/issues/$number/labels" -f "labels[]=autorelease: tagged"
  api_delete_if_exists "repos/$REPO/issues/$number/labels/autorelease:%20pending"
  summary "marked #$number as tagged: $tag exists"
done
