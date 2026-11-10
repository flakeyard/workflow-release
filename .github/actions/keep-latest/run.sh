#!/usr/bin/env bash
# Marks the newest published, non-prerelease vX.Y.Z of REPO as latest.
# shellcheck source-path=SCRIPTDIR
set -euo pipefail
shopt -s inherit_errexit
: "${SHELL_LIB:?}"
: "${REPO:?}"
lib=$(dirname "$0")/../lib
# shellcheck source=../lib/github/optional.sh
source "$lib/github/optional.sh"
# shellcheck source=../lib/github/releases.sh
source "$lib/github/releases.sh"
# shellcheck source=/dev/null
source "$SHELL_LIB/report.sh"

newest=$(published_releases false | tail -n 1)
[[ -n $newest ]] || exit 0
read -r tag id <<<"$newest"

current=$(api_find "repos/$REPO/releases/latest")
if [[ -z $current || $(jq -r .id <<<"$current") != "$id" ]]; then
  gh api --silent -X PATCH "repos/$REPO/releases/$id" -f make_latest=true
  summary "marked $tag as latest"
fi
