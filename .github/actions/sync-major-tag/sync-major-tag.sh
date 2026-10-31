#!/usr/bin/env bash
# Moves vX of the manifest's major version forward to its newest release.
set -euo pipefail
: "${REPO:?}" "${SHA:?}" "${MANIFEST:?}"
# shellcheck source-path=SCRIPTDIR source=../lib/github.sh
source "$(dirname "$0")/../lib/github.sh"

readonly MAJOR_VERSION='^(0|[1-9][0-9]*)$'

version=$(root_version "$SHA")
major=${version%%.*}
[[ $major =~ $MAJOR_VERSION ]] || fail "unexpected version $version in $MANIFEST"

latest=$(newest_release "$major")
if [[ -z $latest ]]; then
  summary "no release of v$major yet"
  exit 0
fi
target=$(find_tag_commit "$latest")
[[ -n $target ]] || fail "release $latest has no tag"

current=$(find_tag_commit "v$major")
if [[ -z $current ]]; then
  gh api --silent -X POST "repos/$REPO/git/refs" -f ref="refs/tags/v$major" -f sha="$target"
  summary "created v$major at $latest"
  exit 0
fi

if [[ $current == "$target" ]]; then
  summary "v$major already at $latest"
  exit 0
fi
relation=$(gh api "repos/$REPO/compare/$current...$target" --jq .status)
if [[ $relation != ahead ]]; then
  echo "::warning::v$major not moved: $latest is $relation of v$major"
  exit 0
fi
gh api --silent -X PATCH "repos/$REPO/git/refs/tags/v$major" -f sha="$target" -F force=true
summary "moved v$major to $latest"
