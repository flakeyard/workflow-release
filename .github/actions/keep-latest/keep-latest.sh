#!/usr/bin/env bash
# Marks the newest published, non-prerelease vX.Y.Z of REPO as latest.
set -euo pipefail
: "${REPO:?}"
# shellcheck source-path=SCRIPTDIR source=../lib/github.sh
source "$(dirname "$0")/../lib/github.sh"

newest=$(published_releases false | tail -n 1)
[[ -n $newest ]] || exit 0
read -r tag id <<<"$newest"

current=$(api_find "repos/$REPO/releases/latest")
if [[ -z $current || $(jq -r .id <<<"$current") != "$id" ]]; then
  gh api --silent -X PATCH "repos/$REPO/releases/$id" -f make_latest=true
  summary "marked $tag as latest"
fi
