#!/usr/bin/env bash
# Relabels merged release pull requests into BASE that are still pending.
set -euo pipefail
: "${REPO:?}" "${BASE:?}" "${MANIFEST:?}"
# shellcheck source-path=SCRIPTDIR source=../lib/github.sh
source "$(dirname "$0")/../lib/github.sh"

# The label is filtered by the API, so only pending pull requests are listed.
numbers=$(gh api --paginate \
  "repos/$REPO/issues?state=closed&labels=autorelease:%20pending&per_page=100" \
  --jq '.[] | select(.pull_request.merged_at != null) | .number')

for number in $numbers; do
  pr=$(api_get "repos/$REPO/pulls/$number")
  [[ $(jq -r .base.ref <<<"$pr") == "$BASE" ]] || continue
  # The released version is the manifest's at the merge commit.
  version=$(manifest_version "$MANIFEST" "$(jq -r .merge_commit_sha <<<"$pr")")
  tag=v$version
  status=0
  release=$(api_get "repos/$REPO/releases/tags/$tag") || status=$?
  ((status == 3)) && continue
  ((status == 0)) || exit 1
  [[ $(jq -r .draft <<<"$release") == false ]] || continue
  # Add the new label first: a failure in between leaves the pull request
  # pending, so the next run retries.
  gh api --silent -X POST "repos/$REPO/issues/$number/labels" -f "labels[]=autorelease: tagged"
  status=0
  api_delete "repos/$REPO/issues/$number/labels/autorelease:%20pending" || status=$?
  ((status == 0 || status == 3)) || exit 1
  summary "marked #$number as tagged: $tag exists"
done
