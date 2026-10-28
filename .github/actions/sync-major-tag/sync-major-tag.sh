#!/usr/bin/env bash
# Moves vX of the manifest's major version forward to its newest release.
set -euo pipefail
: "${REPO:?}" "${SHA:?}" "${MANIFEST:?}"
# shellcheck source-path=SCRIPTDIR source=../lib/github.sh
source "$(dirname "$0")/../lib/github.sh"

version=$(manifest_version "$MANIFEST" "$SHA")
major=${version%%.*}
if [[ ! $major =~ ^(0|[1-9][0-9]*)$ ]]; then
  echo "::error::unexpected version $version in $MANIFEST"
  exit 1
fi

latest=$(newest_release "$major")
if [[ -z $latest ]]; then
  summary "no release of v$major yet"
  exit 0
fi
status=0
target=$(tag_commit "$latest") || status=$?
if ((status == 3)); then
  echo "::error::release $latest has no tag"
  exit 1
fi
((status == 0)) || exit 1

status=0
current=$(tag_commit "v$major") || status=$?
if ((status == 3)); then
  gh api --silent -X POST "repos/$REPO/git/refs" -f ref="refs/tags/v$major" -f sha="$target"
  summary "created v$major at $latest"
  exit 0
fi
((status == 0)) || exit 1

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
