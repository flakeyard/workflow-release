#!/usr/bin/env bash
# Fails unless CONFIG and MANIFEST at SHA describe one root package tagged
# vX.Y.Z with default labels, and on release/vN its major version is N.
# shellcheck source-path=SCRIPTDIR
set -euo pipefail
shopt -s inherit_errexit
: "${REPO:?}" "${SHA:?}" "${REF:?}" "${CONFIG:?}" "${MANIFEST:?}"
lib=$(dirname "$0")/../lib
# shellcheck source=../lib/github/contents.sh
source "$lib/github/contents.sh"
# shellcheck source=../lib/manifest.sh
source "$lib/manifest.sh"
# shellcheck source=../lib/report.sh
source "$lib/report.sh"

readonly RELEASE_BRANCH='^refs/heads/release/v([0-9]+)$'

config=$(file_at "$CONFIG" "$SHA")
problems=$(jq -r -f "$(dirname "$0")/config.jq" <<<"$config")
if [[ -n $problems ]]; then
  while IFS= read -r line; do echo "::error file=$CONFIG::$line"; done <<<"$problems"
  exit 1
fi
version=$(root_version "$SHA")
check_release_version "$version"
if [[ $REF =~ $RELEASE_BRANCH && ${version%%.*} != "${BASH_REMATCH[1]}" ]]; then
  fail "version $version does not belong on ${REF#refs/heads/}" "$MANIFEST"
fi
