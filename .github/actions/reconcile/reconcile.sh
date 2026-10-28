#!/usr/bin/env bash
# Relabels merged release pull requests into BASE that are still pending.
set -euo pipefail
: "${REPO:?}" "${BASE:?}"
# shellcheck source-path=SCRIPTDIR source=../lib/github.sh
source "$(dirname "$0")/../lib/github.sh"

pending=$(gh api --paginate \
  "repos/$REPO/pulls?state=closed&base=$BASE&sort=updated&direction=desc&per_page=50" \
  --jq '.[] | select(.merged_at != null)
    | select(any(.labels[]; .name == "autorelease: pending"))
    | "\(.number) \(.title)"')

while read -r number title; do
  [[ -n ${number:-} ]] || continue
  if [[ ! $title =~ release\ ([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
    echo "::warning::#$number is pending but its title has no version"
    continue
  fi
  tag=v${BASH_REMATCH[1]}
  status=0
  release=$(api_get "repos/$REPO/releases/tags/$tag") || status=$?
  ((status == 3)) && continue
  ((status == 0)) || exit 1
  [[ $(jq -r .draft <<<"$release") == false ]] || continue
  gh api --silent -X DELETE "repos/$REPO/issues/$number/labels/autorelease:%20pending"
  gh api --silent -X POST "repos/$REPO/issues/$number/labels" -f "labels[]=autorelease: tagged"
  summary "marked #$number as tagged: $tag exists"
done <<<"$pending"
